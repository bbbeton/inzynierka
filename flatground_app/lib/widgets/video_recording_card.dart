import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import '../screens/fullscreen_camera_screen.dart';

typedef VideoSelectionCallback = void Function(
  String videoPath,
  int? trimStartMs,
  int? trimEndMs,
);

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
  final VideoSelectionCallback? onVideoSelected;
  final VideoSelectionCallback? onAnalyzeVideo;

  const VideoRecordingCard({
    super.key,
    this.onVideoSelected,
    this.onAnalyzeVideo,
  });

  @override
  State<VideoRecordingCard> createState() => _VideoRecordingCardState();
}

class _VideoRecordingCardState extends State<VideoRecordingCard> {
  File? _videoFile;
  VideoPlayerController? _videoController;
  final ImagePicker _picker = ImagePicker();
  bool _isVideoPlaying = false;
  bool _isRecordPressed = false;
  bool _isUploadPressed = false;
  bool _isAnalyzePressed = false;
  int? _trimStartMs;
  int? _trimEndMs;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _promptTrimForSelectedVideo() async {
    int totalMs = 0;
    if (_videoController != null && _videoController!.value.isInitialized) {
      totalMs = _videoController!.value.duration.inMilliseconds;
    } else if (_videoFile != null) {
      // Fallback: ensure trim prompt still appears even if preview init lags/fails.
      final tempController = VideoPlayerController.file(_videoFile!);
      try {
        await tempController.initialize();
        totalMs = tempController.value.duration.inMilliseconds;
      } catch (_) {
        totalMs = 0;
      } finally {
        await tempController.dispose();
      }
    }
    if (totalMs <= 0) return;

    RangeValues range = RangeValues(
      (_trimStartMs ?? 0).clamp(0, totalMs).toDouble(),
      (_trimEndMs ?? totalMs).clamp(0, totalMs).toDouble(),
    );
    if (range.end <= range.start) {
      range = RangeValues(0, totalMs.toDouble());
    }
    // Always regenerate for the currently selected video (never reuse previous clip frames).
    Uint8List? startPreview;
    Uint8List? endPreview;
    int previewGeneration = 0;

    Future<Uint8List?> generatePreviewAt(int timeMs) {
      if (_videoFile == null) return Future.value(null);
      return VideoThumbnail.thumbnailData(
        video: _videoFile!.path,
        imageFormat: ImageFormat.JPEG,
        timeMs: timeMs,
        quality: 70,
        maxWidth: 160,
      );
    }

    Future<void> refreshPreviews(void Function(void Function()) setDialogState) async {
      final generation = ++previewGeneration;
      final startMs = range.start.round();
      final endMs = range.end.round();
      final previews = await Future.wait([
        generatePreviewAt(startMs),
        generatePreviewAt(endMs),
      ]);
      if (!mounted || generation != previewGeneration) return;
      setDialogState(() {
        startPreview = previews[0];
        endPreview = previews[1];
      });
    }

    final initialPreviews = await Future.wait([
      generatePreviewAt(range.start.round()),
      generatePreviewAt(range.end.round()),
    ]);
    startPreview = initialPreviews[0];
    endPreview = initialPreviews[1];

    String formatMs(double ms) {
      final totalSeconds = (ms / 1000).round();
      final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    final picked = await showDialog<RangeValues>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          title: Text(
            'Trim trick segment',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pick the part that contains the trick.',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start frame',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFEDEAF8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: startPreview == null
                                ? const Center(child: Icon(Icons.image, color: Color(0xFF2F00FF)))
                                : Image.memory(
                                    startPreview!,
                                    key: ValueKey(
                                      'start-${_videoFile!.path}-${range.start.round()}-${startPreview!.length}',
                                    ),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    gaplessPlayback: true,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End frame',
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.black54),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: const Color(0xFFEDEAF8),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: endPreview == null
                                ? const Center(child: Icon(Icons.image, color: Color(0xFF2F00FF)))
                                : Image.memory(
                                    endPreview!,
                                    key: ValueKey(
                                      'end-${_videoFile!.path}-${range.end.round()}-${endPreview!.length}',
                                    ),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    gaplessPlayback: true,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${formatMs(range.start)} - ${formatMs(range.end)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF2F00FF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                RangeSlider(
                  values: range,
                  min: 0,
                  max: totalMs.toDouble(),
                  divisions: totalMs > 1000 ? 100 : null,
                  labels: RangeLabels(
                    formatMs(range.start),
                    formatMs(range.end),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      range = value;
                    });
                    refreshPreviews(setDialogState);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Use full video'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, range),
              child: const Text('Use trimmed segment'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    setState(() {
      _trimStartMs = picked?.start.round();
      _trimEndMs = picked?.end.round();
    });
  }

  Future<void> _recordVideo() async {
    // Open fullscreen camera
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenCameraScreen(
          onVideoRecorded: (videoPath) async {
            setState(() {
              _videoFile = File(videoPath);
              _trimStartMs = null;
              _trimEndMs = null;
            });
            await _loadVideoPreview();
            await _promptTrimForSelectedVideo();
            if (widget.onVideoSelected != null) {
              widget.onVideoSelected!(videoPath, _trimStartMs, _trimEndMs);
            }
            // Don't auto-analyze - user will click analyze button
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
          _trimStartMs = null;
          _trimEndMs = null;
        });
        await _loadVideoPreview();
        await _promptTrimForSelectedVideo();
        if (widget.onVideoSelected != null) {
          widget.onVideoSelected!(_videoFile!.path, _trimStartMs, _trimEndMs);
        }
        // Don't auto-analyze - user will click analyze button
      }
    } catch (e) {
      print('Error picking video: $e');
    }
  }

  Future<void> _loadVideoPreview() async {
    if (_videoFile != null) {
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(_videoFile!);
      try {
        await _videoController!.initialize();
        if (mounted) {
          setState(() {
            _isVideoPlaying = false;
          });
          _videoController!.addListener(() {
            if (mounted) {
              setState(() {
                _isVideoPlaying = _videoController!.value.isPlaying;
              });
            }
          });
        }
      } catch (error) {
        print('Error loading video: $error');
      }
    }
  }

  void _toggleVideoPlayback() {
    if (_videoController != null && _videoController!.value.isInitialized) {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
      setState(() {
        _isVideoPlaying = _videoController!.value.isPlaying;
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
    final hasTrimChip = _trimStartMs != null && _trimEndMs != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 26),
      constraints: const BoxConstraints(maxWidth: 360),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(
          color: const Color(0xFFC7C1E4),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 22),
          // Video Preview Area
          Container(
            width: 308,
            height: hasTrimChip ? 210 : 246,
            decoration: BoxDecoration(
              color: const Color(0xFFC7C1E4).withOpacity(0.1),
              borderRadius: BorderRadius.circular(27),
            ),
            child: Stack(
              children: [
                // Video preview
                if (_videoController != null &&
                    _videoController!.value.isInitialized)
                  GestureDetector(
                    onTap: _toggleVideoPlayback,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(27),
                      child: Stack(
                        children: [
                          SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _videoController!.value.size.width,
                                height: _videoController!.value.size.height,
                                child: VideoPlayer(_videoController!),
                              ),
                            ),
                          ),
                          // Play/Pause overlay button
                          Center(
                            child: Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ],
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
          const SizedBox(height: 16),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // RECORD Button
                    Flexible(
                      child: GestureDetector(
                        onTapDown: (_) => setState(() => _isRecordPressed = true),
                        onTapUp: (_) {
                          setState(() => _isRecordPressed = false);
                          _recordVideo();
                        },
                        onTapCancel: () => setState(() => _isRecordPressed = false),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 120),
                          width: double.infinity,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _isRecordPressed
                                ? const Color(0xFF1A00CC)
                                : const Color(0xFF2F00FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF2F00FF),
                              width: 1,
                            ),
                            boxShadow: _isRecordPressed
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF2F00FF).withOpacity(0.5),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF2F00FF).withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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
                        onTapDown: (_) => setState(() => _isUploadPressed = true),
                        onTapUp: (_) {
                          setState(() => _isUploadPressed = false);
                          _uploadVideo();
                        },
                        onTapCancel: () => setState(() => _isUploadPressed = false),
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 120),
                          width: double.infinity,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _isUploadPressed
                                ? const Color(0xFFE8E5F5)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF2F00FF),
                              width: 1,
                            ),
                            boxShadow: _isUploadPressed
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF2F00FF).withOpacity(0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: const Color(0xFF2F00FF).withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
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
                // Analyze Button (shown when video is loaded)
                if (_videoFile != null) ...[
                  const SizedBox(height: 10),
                  if (hasTrimChip)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: TextButton.icon(
                        onPressed: _promptTrimForSelectedVideo,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.content_cut, size: 16),
                        label: Text(
                          'Trim: ${(_trimStartMs! / 1000).toStringAsFixed(1)}s - ${(_trimEndMs! / 1000).toStringAsFixed(1)}s',
                          style: GoogleFonts.poppins(fontSize: 11),
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTapDown: (_) => setState(() => _isAnalyzePressed = true),
                    onTapUp: (_) {
                      setState(() => _isAnalyzePressed = false);
                      if (_videoFile != null && widget.onAnalyzeVideo != null) {
                        widget.onAnalyzeVideo!(_videoFile!.path, _trimStartMs, _trimEndMs);
                      }
                    },
                    onTapCancel: () => setState(() => _isAnalyzePressed = false),
                    child: Container(
                      width: double.infinity,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _isAnalyzePressed
                            ? const Color(0xFFB5A9D9)
                            : const Color(0xFFC7C1E4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF2F00FF),
                          width: 1,
                        ),
                        boxShadow: _isAnalyzePressed
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2F00FF).withOpacity(0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: const Color(0xFF2F00FF).withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.analytics,
                            color: Color(0xFF2F00FF),
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ANALYZE TRICK',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF2F00FF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
