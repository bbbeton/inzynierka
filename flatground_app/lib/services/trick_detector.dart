import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:video_player/video_player.dart';
import 'movenet_service.dart';

class TrickDetector {
  Interpreter? _interpreter;
  List<String> _labels = [];
  bool _isInitialized = false;
  MoveNetService? _moveNetService;

  // Calibration layer for real-world clips (tunable without retraining model).
  static const Map<String, double> _baseClassCalibration = {
    'Backside180': 0.90,
    'Frontside180': 0.88,
    'Frontshuvit': 1.08,
    'Pressureflip': 0.92,
    'Kickflip': 1.25,
    'Heelflip': 1.12,
    'Ollie': 0.90,
    'Shuvit': 1.08,
  };

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Inicjalizacja MoveNet (Oczy)
      _moveNetService = MoveNetService();
      await _moveNetService!.initialize();
      print('MoveNet Thunder initialized successfully');

      // 2. Ładowanie modelu klasyfikatora (Mózg)
      // Używamy nowego modelu CNN, który nie wymaga Select TF Ops
      final modelPath = 'assets/trick_classifier.tflite';
      
      final options = InterpreterOptions()..threads = 2;
      
      try {
        _interpreter = await Interpreter.fromAsset(
          modelPath,
          options: options,
        );
      } catch (e) {
        print('Error loading model: $e');
        // Jeśli nie uda się załadować z opcjami, próbujemy bez
        _interpreter = await Interpreter.fromAsset(modelPath);
      }

      // 3. Ładowanie etykiet
      final labelsString = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsString.split('\n').where((l) => l.isNotEmpty).toList();

      _isInitialized = true;
      print('Trick detector initialized successfully');
    } catch (e, stackTrace) {
      print('Error initializing trick detector: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> detectTrickFromVideo(String videoPath) async {
    if (!_isInitialized) await initialize();

    try {
      print('Starting analysis for: $videoPath');
      
      // 1. Sprawdzenie długości wideo
      final videoController = VideoPlayerController.file(File(videoPath));
      await videoController.initialize();
      final durationMs = videoController.value.duration.inMilliseconds;
      await videoController.dispose();

      // 2. Tryb zgodny z treningiem: zawsze 30 rzeczywistych klatek
      const targetFrames = 30;
      print('Extracting and processing frames (training parity: $targetFrames)...');
      final keypoints = await _moveNetService!.detectPoseFromVideo(
        videoPath,
        maxFrames: targetFrames,
        durationMs: durationMs,
      );
      print('Got ${keypoints.length} processed frames from MoveNet (training parity)');

      // 3. Klasyfikacja (Mózg)
      final result = await detectTrickFromKeypoints(keypoints);
      
      return result;

    } catch (e, stackTrace) {
      print('Error detecting trick from video: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Przetwarza sekwencję punktów (30 klatek x 51 cech)
  Future<Map<String, dynamic>> detectTrickFromKeypoints(
    List<List<double>> keypointSequence, {
    bool debug = true,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      // Sprawdzenie kształtu wejścia
      final inputTensor = _interpreter!.getInputTensor(0);
      final inputShape = inputTensor.shape; // Powinno być [1, 30, 51]
      
      print('Model input shape: $inputShape');

      // Jeśli sekwencja jest za krótka/długa, naprawiamy ją tutaj dla pewności
      List<List<double>> fixedSequence = keypointSequence
          .where((frame) => frame.isNotEmpty)
          .map((frame) {
            if (frame.length == 51) return frame;
            if (frame.length > 51) return frame.sublist(0, 51);
            return List<double>.from(frame)..addAll(List.filled(51 - frame.length, 0.0));
          })
          .toList();
      
      // Padding (jeśli za mało)
      while (fixedSequence.length < 30) {
        if (fixedSequence.isNotEmpty) {
           fixedSequence.add(List.from(fixedSequence.last));
        } else {
           fixedSequence.add(List.filled(51, 0.0));
        }
      }
      // Truncate (jeśli za dużo)
      if (fixedSequence.length > 30) {
        fixedSequence = fixedSequence.sublist(0, 30);
      }

      // Budowanie tensora wejściowego [1, 30, 51]
      // Używamy reshapeList (extension na dole pliku)
      final input = List.generate(
        1 * 30 * 51,
        (index) => 0.0,
      ).reshapeList([1, 30, 51]);

      // Kopiowanie danych do struktury wejściowej
      for (int i = 0; i < 30; i++) {
        for (int j = 0; j < 51; j++) {
          input[0][i][j] = fixedSequence[i][j];
        }
      }

      // Przygotowanie wyjścia
      final outputTensor = _interpreter!.getOutputTensor(0);
      final outputShape = outputTensor.shape;
      final output = List.generate(
        outputShape.reduce((a, b) => a * b),
        (index) => 0.0,
      ).reshapeList(outputShape);

      // Inferencja
      _interpreter!.run(input, output);

      // Parsowanie wyniku
      // Output może być [1, num_classes] lub [num_classes]
      List<double> predictions;
      if (outputShape.length == 2) {
        predictions = List<double>.from(output[0]);
      } else {
        predictions = List<double>.from(output);
      }

      // Jeśli to logits (brak softmax), przelicz na prawdopodobieństwa
      double sum = 0.0;
      for (final v in predictions) {
        sum += v;
      }
      final bool looksLikeProbabilities = sum > 0.95 && sum < 1.05;
      if (!looksLikeProbabilities) {
        final maxLogit = predictions.reduce((a, b) => a > b ? a : b);
        final expVals = predictions.map((v) => math.exp(v - maxLogit)).toList();
        final expSum = expVals.reduce((a, b) => a + b);
        predictions = expVals.map((v) => v / expSum).toList();
      }

      // Diagnostyka: średnia pewność punktów (co 3 element to score)
      double scoreSum = 0.0;
      int scoreCount = 0;
      for (final frame in fixedSequence) {
        for (int i = 2; i < frame.length; i += 3) {
          scoreSum += frame[i];
          scoreCount++;
        }
      }
      final avgScore = scoreCount > 0 ? (scoreSum / scoreCount) : 0.0;
      if (debug && avgScore < 0.15) {
        print('Warning: Low average keypoint score ($avgScore). Input may be too noisy.');
      }

      final torsoRotation = _estimateTorsoRotation(fixedSequence);
      final signedTorsoRotation = _estimateSignedTorsoRotation(fixedSequence);
      predictions = _applyCalibration(
        predictions: predictions,
        labels: _labels,
        torsoRotation: torsoRotation,
        signedTorsoRotation: signedTorsoRotation,
      );

      // Znalezienie najlepszego wyniku
      double maxConfidence = 0.0;
      int maxIndex = 0;
      for (int i = 0; i < predictions.length; i++) {
        if (predictions[i] > maxConfidence) {
          maxConfidence = predictions[i];
          maxIndex = i;
        }
      }

      String trickName = "Unknown";
      if (maxIndex < _labels.length) {
        trickName = _labels[maxIndex];
      }
      if (debug && predictions.length != _labels.length) {
        print('Warning: Model outputs ${predictions.length} classes but labels file has ${_labels.length}.');
      }

      final indexed = List.generate(predictions.length, (i) => [i, predictions[i]]);
      indexed.sort((a, b) => (b[1] as double).compareTo(a[1] as double));
      final top3 = indexed.take(3).toList();

      // Bez heurystyk nadpisujących klasy: ufamy bezpośredniemu wynikowi modelu.

      final confidence = (maxConfidence * 100).round();

      final statistics = {
        'confidence': confidence,
      };

      final top3Text = top3.map((pair) {
        final idx = pair[0] as int;
        final label = idx < _labels.length ? _labels[idx] : 'idx_$idx';
        return '$label:${(((pair[1] as double) * 100)).toStringAsFixed(1)}%';
      }).toList();

      if (debug) {
        print('Detected: $trickName ($confidence%)');
        print("Top-3: ${top3Text.join(', ')}");
        print("Torso rotation signal: ${torsoRotation.toStringAsFixed(3)}");
        print("Signed torso rotation: ${signedTorsoRotation.toStringAsFixed(3)}");
      }
      return {
        'trick': trickName,
        'confidence': confidence,
        'statistics': statistics,
      };

    } catch (e, stackTrace) {
      print('Error running inference: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  List<double> _applyCalibration({
    required List<double> predictions,
    required List<String> labels,
    required double torsoRotation,
    required double signedTorsoRotation,
  }) {
    if (predictions.isEmpty || labels.isEmpty) return predictions;
    final calibrated = List<double>.from(predictions);

    // 1) Static per-class scaling (dataset -> real-world domain correction).
    for (int i = 0; i < calibrated.length && i < labels.length; i++) {
      final label = labels[i];
      final scale = _baseClassCalibration[label] ?? 1.0;
      calibrated[i] *= scale;
    }

    // 2) Motion-aware scaling.
    final bs180 = labels.indexOf('Backside180');
    final fs180 = labels.indexOf('Frontside180');
    final shuvit = labels.indexOf('Shuvit');
    final frontshuvit = labels.indexOf('Frontshuvit');
    final kickflip = labels.indexOf('Kickflip');
    final heelflip = labels.indexOf('Heelflip');
    final ollie = labels.indexOf('Ollie');

    // Low body-rotation clips: strongly reduce 180-family false positives.
    if (torsoRotation < 0.18) {
      for (final idx in [bs180, fs180]) {
        if (idx >= 0) calibrated[idx] *= 0.45;
      }
      for (final idx in [kickflip, heelflip]) {
        if (idx >= 0) calibrated[idx] *= 1.22;
      }
      for (final idx in [shuvit, frontshuvit]) {
        if (idx >= 0) calibrated[idx] *= 1.18;
      }
      if (ollie >= 0) calibrated[ollie] *= 0.92;
    }

    // High body-rotation clips are usually rotational tricks, not ollies.
    if (torsoRotation > 0.70) {
      for (final idx in [bs180, fs180, shuvit, frontshuvit]) {
        if (idx >= 0) calibrated[idx] *= 1.25;
      }
      for (final idx in [kickflip, heelflip, ollie]) {
        if (idx >= 0) calibrated[idx] *= 0.82;
      }
      if (ollie >= 0) calibrated[ollie] *= 0.55;
    } else if (torsoRotation > 0.45 && ollie >= 0) {
      calibrated[ollie] *= 0.75;
    }

    // Mild BS180 vs FS180 bias from signed torso turn direction.
    if (bs180 >= 0 && fs180 >= 0 && signedTorsoRotation.abs() > 0.10) {
      if (signedTorsoRotation > 0) {
        calibrated[bs180] *= 1.08;
        calibrated[fs180] *= 0.92;
      } else {
        calibrated[fs180] *= 1.08;
        calibrated[bs180] *= 0.92;
      }
    }

    // Renormalize to probabilities.
    final sum = calibrated.fold<double>(0.0, (a, b) => a + b);
    if (sum > 0) {
      for (int i = 0; i < calibrated.length; i++) {
        calibrated[i] = calibrated[i] / sum;
      }
    }
    return calibrated;
  }

  double _estimateTorsoRotation(List<List<double>> sequence) {
    if (sequence.length < 2) return 0.0;

    double? firstAngle;
    double? lastAngle;
    for (final frame in sequence) {
      final angle = _torsoAngle(frame);
      if (angle == null) continue;
      firstAngle ??= angle;
      lastAngle = angle;
    }
    if (firstAngle == null || lastAngle == null) return 0.0;

    var delta = (lastAngle - firstAngle).abs();
    while (delta > math.pi) {
      delta = (2 * math.pi) - delta;
    }
    return (delta / math.pi).clamp(0.0, 1.0);
  }

  double _estimateSignedTorsoRotation(List<List<double>> sequence) {
    if (sequence.length < 2) return 0.0;
    double? firstAngle;
    double? lastAngle;
    for (final frame in sequence) {
      final angle = _torsoAngle(frame);
      if (angle == null) continue;
      firstAngle ??= angle;
      lastAngle = angle;
    }
    if (firstAngle == null || lastAngle == null) return 0.0;

    double delta = lastAngle - firstAngle;
    while (delta > math.pi) delta -= 2 * math.pi;
    while (delta < -math.pi) delta += 2 * math.pi;
    return (delta / math.pi).clamp(-1.0, 1.0);
  }

  double? _torsoAngle(List<double> frame) {
    if (frame.length < 51) return null;

    // MoveNet keypoints: 5 leftShoulder, 6 rightShoulder.
    final leftShoulderY = frame[5 * 3];
    final leftShoulderX = frame[5 * 3 + 1];
    final leftShoulderS = frame[5 * 3 + 2];
    final rightShoulderY = frame[6 * 3];
    final rightShoulderX = frame[6 * 3 + 1];
    final rightShoulderS = frame[6 * 3 + 2];

    if (leftShoulderS < 0.2 || rightShoulderS < 0.2) return null;
    return math.atan2(rightShoulderY - leftShoulderY, rightShoulderX - leftShoulderX);
  }

  void dispose() {
    _interpreter?.close();
    _moveNetService?.dispose();
    _isInitialized = false;
  }
}

// Extension do obsługi kształtów tensora
extension ListReshapeExtension on List {
  List reshapeList(List<int> shape) {
    if (shape.length == 1) return this;
    final size = shape[0];
    final subShape = shape.sublist(1);
    final subSize = subShape.reduce((a, b) => a * b);
    return List.generate(
      size,
      (i) => sublist(i * subSize, (i + 1) * subSize).reshapeList(subShape),
    );
  }
}
