import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:video_thumbnail/video_thumbnail.dart';

class MoveNetService {
  Interpreter? _interpreter;
  bool _isInitialized = false;
  String _activeModel = 'assets/movenet_thunder.tflite';
  static const int _defaultFrameBudget = 30;

  // MoveNet Thunder input size
  static const int inputSize = 256;

  // MoveNet outputs 17 keypoints
  static const int numKeypoints = 17;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final options = InterpreterOptions()..threads = 4; // Zwiększona liczba wątków dla wydajności

      // Model zgodny z pipeline treningowym.
      _interpreter = await Interpreter.fromAsset(
        'assets/movenet_thunder.tflite',
        options: options,
      );
      _activeModel = 'assets/movenet_thunder.tflite';

      _isInitialized = true;
      print('MoveNet service initialized successfully ($_activeModel)');
    } catch (e) {
      print('Error initializing MoveNet service: $e');
      throw Exception('Failed to load MoveNet model. Make sure movenet_thunder.tflite is in assets.');
    }
  }

  /// Przetwarza pojedynczą klatkę i zwraca spłaszczoną listę 51 punktów (`17 * [y, x, conf]`).
  /// Zwraca `List<double>` o długości 51.
  Future<List<double>> detectPose(String imagePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        print('Frame file missing: $imagePath');
        return List.filled(51, 0.0);
      }

      final imageBytes = await file.readAsBytes();
      return _detectPoseFromBytes(imageBytes);

    } catch (e) {
      print('Error detecting pose: $e');
      // W razie błędu zwróć same zera, żeby nie crashować aplikacji
      return List.filled(51, 0.0);
    }
  }

  Future<List<double>> _detectPoseFromBytes(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        throw Exception('Could not decode image');
      }

      final resizedImage = _resizeAndPad(image, inputSize, inputSize);
      final inputTensor = _interpreter!.getInputTensor(0);
      final isUint8 = inputTensor.type == TensorType.uint8;

      List input;
      if (isUint8) {
        final inputBytes = Uint8List(1 * inputSize * inputSize * 3);
        int pixelIndex = 0;
        for (int y = 0; y < inputSize; y++) {
          for (int x = 0; x < inputSize; x++) {
            final pixel = resizedImage.getPixel(x, y);
            inputBytes[pixelIndex++] = pixel.r.toInt();
            inputBytes[pixelIndex++] = pixel.g.toInt();
            inputBytes[pixelIndex++] = pixel.b.toInt();
          }
        }
        input = inputBytes.reshape([1, inputSize, inputSize, 3]);
      } else {
        final inputList = Float32List(1 * inputSize * inputSize * 3);
        int pixelIndex = 0;
        for (int y = 0; y < inputSize; y++) {
          for (int x = 0; x < inputSize; x++) {
            final pixel = resizedImage.getPixel(x, y);
            inputList[pixelIndex++] = pixel.r / 255.0;
            inputList[pixelIndex++] = pixel.g / 255.0;
            inputList[pixelIndex++] = pixel.b / 255.0;
          }
        }
        input = inputList.reshape([1, inputSize, inputSize, 3]);
      }

      final output = List.filled(1 * 1 * 17 * 3, 0.0).reshape([1, 1, 17, 3]);
      _interpreter!.run(input, output);

      final List<double> flattenedKeypoints = [];
      final rawKeypoints = output[0][0];
      for (final point in rawKeypoints) {
        flattenedKeypoints.add((point[0] as num).toDouble());
        flattenedKeypoints.add((point[1] as num).toDouble());
        flattenedKeypoints.add((point[2] as num).toDouble());
      }
      return flattenedKeypoints;
    } catch (e) {
      print('Error detecting pose from bytes: $e');
      return List.filled(51, 0.0);
    }
  }

  /// Przetwarza wideo i zwraca listę klatek, gdzie każda klatka to lista 51 liczb
  Future<List<List<double>>> detectPoseFromVideo(
      String videoPath, {
        int maxFrames = _defaultFrameBudget,
        int? durationMs,
      }) async {
    if (!_isInitialized) await initialize();

    try {
      final int processedFrames = maxFrames.clamp(30, 30);

      // 1. Ekstrakcja klatek do pamięci (bez kosztownego IO na plikach tymczasowych)
      final frameBytes = await _extractFrames(
        videoPath,
        maxFrames: processedFrames,
        durationMs: durationMs,
      );

      print("Extracted ${frameBytes.length} frames for analysis");

      List<List<double>> allKeypoints = [];

      for (final bytes in frameBytes) {
        final keypoints = await _detectPoseFromBytes(bytes);
        allKeypoints.add(keypoints);
        await Future<void>.delayed(Duration.zero);
      }

      // 2. Dopasowanie do stałego wejścia klasyfikatora [30, 51]
      if (allKeypoints.isEmpty) {
        // Jeśli nic nie wykryto, wypełnij zerami
        return List.generate(30, (_) => List.filled(51, 0.0));
      }
      return _resampleKeypointSequence(allKeypoints, 30);
    } catch (e) {
      print('Error processing video: $e');
      rethrow;
    }
  }

  Future<List<Uint8List>> _extractFrames(
    String videoPath, {
    required int maxFrames,
    int? durationMs,
  }) async {
    final List<Uint8List> frameBytes = [];

    // Dla krótkich klipów bierzemy pełny zakres (trick może być na początku/końcu).
    // Dla dłuższych klipów skupiamy się na środku, żeby ograniczyć "szum" z dojazdu/odjazdu.
    final int safeDurationMs = (durationMs ?? 3000).clamp(1000, 30000);
    final int frameCount = maxFrames.clamp(30, 30);
    final bool shortClip = safeDurationMs <= 2400;
    final int windowStartMs = shortClip ? 0 : (safeDurationMs * 0.20).round();
    final int windowEndMs = shortClip ? safeDurationMs : (safeDurationMs * 0.80).round();
    final int windowDurationMs = (windowEndMs - windowStartMs).clamp(300, safeDurationMs);
    final int intervalMs = (windowDurationMs / frameCount).floor().clamp(1, windowDurationMs);
    final List<int> selectedTimestamps = List.generate(
      frameCount,
      (i) => (windowStartMs + (i * intervalMs)).clamp(0, safeDurationMs - 1),
    );

    print(
      "Starting extraction: Target $frameCount frames across full clip "
      "(window ${windowStartMs}-${windowEndMs}ms of 0-${safeDurationMs}ms), interval ${intervalMs}ms",
    );

    for (int i = 0; i < selectedTimestamps.length; i++) {
      final timeMs = selectedTimestamps[i];
      try {
        // Generowanie miniatury jako bytes (unikamy brakujących plików)
        final bytes = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          timeMs: timeMs,
          quality: 85,
          maxHeight: inputSize,
          maxWidth: inputSize,
        );

        if (bytes != null && bytes.isNotEmpty) {
          frameBytes.add(bytes);
        } else {
          print("Warning: Empty thumbnail at ${timeMs}ms (frame $i)");
        }
      } catch (e) {
        print("Error frame $i at ${timeMs}ms: $e");
      }
    }

    print("Extraction finished. Total frames: ${frameBytes.length}");
    return frameBytes;
  }

  img.Image _resizeAndPad(img.Image image, int targetWidth, int targetHeight) {
    // Szybka kopia resize (nearest neighbor jest najszybszy, ale bilinear lepszy dla AI)
    // Używamy standardowego resize, bo 'image' package w Dart jest wolny
    
    double aspectRatio = image.width / image.height;
    int newWidth, newHeight;

    if (aspectRatio > 1.0) {
      newWidth = targetWidth;
      newHeight = (targetWidth / aspectRatio).round();
    } else {
      newHeight = targetHeight;
      newWidth = (targetHeight * aspectRatio).round();
    }

    final resized = img.copyResize(image, width: newWidth, height: newHeight);
    final padded = img.Image(width: targetWidth, height: targetHeight);
    
    // Wypełnij czarnym (0,0,0)
    img.fill(padded, color: img.ColorRgb8(0, 0, 0));
    
    final offsetX = (targetWidth - newWidth) ~/ 2;
    final offsetY = (targetHeight - newHeight) ~/ 2;

    img.compositeImage(padded, resized, dstX: offsetX, dstY: offsetY);
    return padded;
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }

  List<List<double>> _resampleKeypointSequence(List<List<double>> source, int targetLength) {
    if (source.isEmpty) {
      return List.generate(targetLength, (_) => List.filled(51, 0.0));
    }
    if (source.length == targetLength) return source;
    if (source.length == 1) {
      return List.generate(targetLength, (_) => List<double>.from(source.first));
    }

    final List<List<double>> out = [];
    final double step = (source.length - 1) / (targetLength - 1);
    for (int i = 0; i < targetLength; i++) {
      final pos = i * step;
      final left = pos.floor();
      final right = pos.ceil().clamp(0, source.length - 1);
      if (left == right) {
        out.add(List<double>.from(source[left]));
        continue;
      }

      final t = pos - left;
      final leftFrame = source[left];
      final rightFrame = source[right];
      final blended = List<double>.generate(
        51,
        (j) => leftFrame[j] * (1.0 - t) + rightFrame[j] * t,
      );
      out.add(blended);
    }
    return out;
  }
}