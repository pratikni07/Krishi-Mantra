import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/colors.dart';

class MediaPreviewDialog extends StatefulWidget {
  final File mediaFile;
  final String mediaType;
  final Function(File file) onSend;
  final TextEditingController? captionController;

  const MediaPreviewDialog({
    Key? key,
    required this.mediaFile,
    required this.mediaType,
    required this.onSend,
    this.captionController,
  }) : super(key: key);

  @override
  State<MediaPreviewDialog> createState() => _MediaPreviewDialogState();
}

class _MediaPreviewDialogState extends State<MediaPreviewDialog> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      _initializeVideoPlayer();
    }
  }

  Future<void> _initializeVideoPlayer() async {
    _videoController = VideoPlayerController.file(widget.mediaFile);
    await _videoController!.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildMediaPreview() {
    if (widget.mediaType == 'image') {
      return GestureDetector(
        onTap: () {
          // Allow pinch zoom on image
        },
        child: Hero(
          tag: 'preview-image',
          child: Image.file(
            widget.mediaFile,
            fit: BoxFit.contain,
          ),
        ),
      );
    } else if (widget.mediaType == 'video') {
      if (_videoController?.value.isInitialized ?? false) {
        return Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
            IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause_circle : Icons.play_circle,
                size: 50,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _isPlaying = !_isPlaying;
                  _isPlaying
                      ? _videoController!.play()
                      : _videoController!.pause();
                });
              },
            ),
          ],
        );
      } else {
        return const Center(child: CircularProgressIndicator(color: AppColors.green));
      }
    } else if (widget.mediaType == 'document') {
      // Show document icon with filename
      final fileName = widget.mediaFile.path.split('/').last;
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, size: 72, color: AppColors.green),
            const SizedBox(height: 16),
            Text(
              fileName,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Preview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Get.back(result: false),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Media Preview
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(0),
                ),
                child: _buildMediaPreview(),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.black12, width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isSending 
                      ? null 
                      : () {
                        setState(() {
                          _isSending = true;
                        });
                        // Close dialog first, but return true to indicate the send operation should proceed
                        Navigator.of(context).pop(true);
                        // Then call the send function
                        widget.onSend(widget.mediaFile);
                      },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: _isSending 
                      ? Container(
                          width: 20, 
                          height: 20, 
                          child: const CircularProgressIndicator(
                            color: Colors.white, 
                            strokeWidth: 2,
                          )
                        )
                      : const Icon(Icons.send),
                    label: Text(_isSending ? 'Sending...' : 'Send'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
