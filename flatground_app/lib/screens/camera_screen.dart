import 'package:flutter/material.dart';
import '../widgets/video_recording_card.dart';
import '../widgets/trick_detection_card.dart';
import '../widgets/trick_history_card.dart';
import '../services/trick_detector.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final TrickDetector _trickDetector = TrickDetector();
  Map<String, dynamic>? _detectionResult;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _trickHistory = [];

  @override
  void initState() {
    super.initState();
    _initializeDetector();
  }

  Future<void> _initializeDetector() async {
    try {
      await _trickDetector.initialize();
    } catch (e) {
      print('Error initializing detector: $e');
    }
  }

  Future<void> _onVideoSelected(String videoPath) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _detectionResult = null;
    });

    try {
      print('Starting analysis for video: $videoPath');
      await Future<void>.delayed(const Duration(milliseconds: 16));
      // Process video with trick detector
      final result = await _trickDetector.detectTrickFromVideo(videoPath);
      
      print('Analysis completed: ${result['trick']}');
      
      setState(() {
        _detectionResult = result;
        _isProcessing = false;
        
        // Add to history
        _trickHistory.insert(0, {
          'name': result['trick'],
          'percentage': '${result['confidence']}%',
          'time': 'Just now',
        });
      });
    } catch (e, stackTrace) {
      print('Error processing video: $e');
      print('Stack trace: $stackTrace');
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error analyzing video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      setState(() {
        _isProcessing = false;
        _detectionResult = {
          'trick': 'Unknown',
          'confidence': 0,
          'statistics': {
            'confidence': 0,
          },
        };
      });
    }
  }

  @override
  void dispose() {
    _trickDetector.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // Background image/pattern
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  // You can add a pattern or image here
                ),
              ),
            ),

            // Main scrollable content
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 130),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  // Video Recording Card
                  VideoRecordingCard(
                    onVideoSelected: (videoPath) {
                      // Just load the video, don't analyze yet
                      setState(() {
                        _detectionResult = null;
                      });
                    },
                    onAnalyzeVideo: _onVideoSelected,
                  ),
                  const SizedBox(height: 27),
                  
                  // Trick Detection Card
                  if (_isProcessing)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 26),
                      constraints: const BoxConstraints(maxWidth: 360),
                      width: double.infinity,
                      height: 540,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(
                          color: const Color(0xFFC7C1E4),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2F00FF),
                        ),
                      ),
                    )
                  else if (_detectionResult != null)
                    TrickDetectionCard(
                      trickName: _detectionResult!['trick'],
                      accuracy: _detectionResult!['confidence'],
                      statistics: Map<String, int>.from(
                        _detectionResult!['statistics'] as Map,
                      ),
                    )
                  else
                    const TrickDetectionCard(),
                  
                  const SizedBox(height: 30),
                  
                  // Trick History Card (with updated history)
                  TrickHistoryCard(
                    trickHistory: _trickHistory.map((item) => {
                      'name': item['name'] as String,
                      'percentage': item['percentage'] as String,
                      'time': item['time'] as String,
                    }).toList(),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
