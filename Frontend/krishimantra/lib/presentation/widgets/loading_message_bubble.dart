import 'dart:io';

import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';

class LoadingMessageBubble extends StatelessWidget {
  final File mediaFile;
  final String mediaType;
  final String? caption;
  final bool isUser;

  const LoadingMessageBubble({
    Key? key,
    required this.mediaFile,
    required this.mediaType,
    this.caption,
    this.isUser = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Container(
          margin: EdgeInsets.only(
            left: isUser ? 64 : 8,
            right: isUser ? 8 : 64,
            bottom: 4,
            top: 4,
          ),
          decoration: BoxDecoration(
            color: isUser ? AppColors.green : Colors.grey[200],
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isUser
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Stack(
                  children: [
                    if (mediaType == 'image')
                      Image.file(
                        mediaFile,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    if (mediaType == 'document')
                      Container(
                        height: 100,
                        width: double.infinity,
                        color: isUser ? AppColors.green.withOpacity(0.8) : Colors.grey[300],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.insert_drive_file,
                              size: 40,
                              color: isUser ? Colors.white.withOpacity(0.8) : Colors.grey[700],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              mediaFile.path.split('/').last,
                              style: TextStyle(
                                color: isUser ? Colors.white : Colors.black87,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    Container(
                      height: mediaType == 'image' ? 200 : 100,
                      width: double.infinity,
                      color: Colors.black26,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Uploading...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (caption != null && caption!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    caption!,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
