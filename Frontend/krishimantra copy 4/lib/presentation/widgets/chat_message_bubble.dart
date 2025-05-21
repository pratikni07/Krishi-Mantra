// lib/presentation/widgets/chat_message_bubble.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:get/get.dart';
import '../../core/constants/colors.dart';
import 'image_viewer_screen.dart';

class ChatMessageBubble extends StatelessWidget {
  final String? message;
  final bool isUser;
  final DateTime timestamp;
  final String? mediaUrl;
  final String mediaType;
  final Map<String, dynamic>? mediaMetadata;

  const ChatMessageBubble({
    Key? key,
    this.message,
    required this.isUser,
    required this.timestamp,
    this.mediaUrl,
    this.mediaType = 'text',
    this.mediaMetadata,
  }) : super(key: key);

  Widget _buildMediaContent() {
    if (mediaUrl == null) return const SizedBox.shrink();

    switch (mediaType) {
      case 'image':
        final heroTag = 'image-${mediaUrl!.hashCode}';
        return GestureDetector(
          onTap: () {
            Get.to(() => ImageViewerScreen(
                  imageUrl: mediaUrl!,
                  heroTag: heroTag,
                ));
          },
          child: Hero(
            tag: heroTag,
            child: Container(
              constraints: const BoxConstraints(
                maxHeight: 200,
                maxWidth: 280, // Slightly reduced for better appearance
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  mediaUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 200,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                          color: AppColors.green,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading image: $error');
                    return Container(
                      width: 200,
                      height: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Failed to load image',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(timestamp);

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
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
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
                    if (mediaType != 'text')
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                        child: _buildMediaContent(),
                      ),
                    if (message != null && message!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(
                          left: 12,
                          right: 12,
                          top: mediaType != 'text' ? 8 : 12,
                          bottom: 12,
                        ),
                        child: Text(
                          message!,
                          style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
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
