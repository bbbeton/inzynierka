import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../screens/fullscreen_camera_screen.dart';

class DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.62)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 5.0;
    double startX = 0;
    double startY = 0;

    // Top border
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + dashWidth, startY),
        paint,
      );
      startX += dashWidth + dashSpace;
    }

    // Right border
    startX = size.width;
    startY = 0;
    while (startY < size.height) {
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }

    // Bottom border
    startX = size.width;
    startY = size.height;
    while (startX > 0) {
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX - dashWidth, startY),
        paint,
      );
      startX -= dashWidth + dashSpace;
    }

    // Left border
    startX = 0;
    startY = size.height;
    while (startY > 0) {
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX, startY - dashWidth),
        paint,
      );
      startY -= dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class VideoRecordingCard extends StatefulWidget {
  final Function(String)? onVideoSelected;

  const VideoRecordingCard({super.key, this.onVideoSelected});

  @override
  State<VideoRecordingCard> createState() => _VideoRecordingCardState();
}

class _VideoRecordingCardState extends State<VideoRecordingCard> {
  File? _videoFile;
  VideoPlayerController? _videoController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _recordVideo() async {
    // Open fullscreen camera
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenCameraScreen(
          onVideoRecorded: (videoPath) {
            setState(() {
              _videoFile = File(videoPath);
            });
            _loadVideoPreview();
            if (widget.onVideoSelected != null) {
              widget.onVideoSelected!(videoPath);
            }
          },
        ),
      ),
    );
  }

  Future<void> _uploadVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (video != null) {
        setState(() {
          _videoFile = File(video.path);
        });
        _loadVideoPreview();
        if (widget.onVideoSelected != null) {
          widget.onVideoSelected!(_videoFile!.path);
        }
      }
    } catch (e) {
      print('Error picking video: $e');
    }
  }

  void _loadVideoPreview() {
    if (_videoFile != null) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(_videoFile!);
      _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.setLooping(true);
          _videoController!.play();
        }
      }).catchError((error) {
        print('Error loading video: $error');
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 26),
      constraints: const BoxConstraints(maxWidth: 360),
      width: double.infinity,
      height: 369,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: const Color(0xFFC7C1E4),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 22),
          // Video Preview Area
          Container(
            width: 308,
            height: 246,
            decoration: BoxDecoration(
              color: const Color(0xFFC7C1E4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(27),
            ),
            child: Stack(
              children: [
                // Video preview
                if (_videoController != null &&
                    _videoController!.value.isInitialized)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(27),
                    child: SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _videoController!.value.size.width,
                          height: _videoController!.value.size.height,
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                    ),
                  )
                else
                  // Dashed border placeholder
                  Center(
                    child: CustomPaint(
                      painter: DashedBorderPainter(),
                      child: Container(
                        width: 259,
                        height: 204,
                        child: Center(
                          child: Icon(
                            Icons.add_circle_outline,
                            size: 48,
                            color: const Color(0xFFC7C1E4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 19),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              // RECORD Button
              Flexible(
                child: GestureDetector(
                  onTap: _recordVideo,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 120),
                    width: double.infinity,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F00FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF2F00FF),
                        width: 1,
                      ),
                    ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.videocam,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'RECORD',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // UPLOAD Button
                Flexible(
                  child: GestureDetector(
                    onTap: _uploadVideo,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      width: double.infinity,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF2F00FF),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.upload,
                            color: Color(0xFF2F00FF),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'UPLOAD',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2F00FF),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
