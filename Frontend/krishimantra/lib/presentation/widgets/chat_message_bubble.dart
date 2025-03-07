// lib/presentation/widgets/chat_message_bubble.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/constants/colors.dart';

class ChatMessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final String? imageUrl;

  const ChatMessageBubble({
    Key? key,
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(right: 12, top: 4),
            decoration: BoxDecoration(
              color: isUser ? Colors.green[100] : Colors.green[700],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(
                isUser ? Icons.person : Icons.agriculture_outlined,
                color: isUser ? AppColors.green : Colors.white,
                size: 18,
              ),
            ),
          ),

          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sender name and time
                Row(
                  children: [
                    Text(
                      isUser ? 'You' : 'Farmer AI',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Image if present
                if (imageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Icon(Icons.image_not_supported,
                                size: 50, color: Colors.grey),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Message content with markdown rendering
                MarkdownBody(
                  data: message,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                    strong: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    listBullet: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[800],
                    ),
                    h1: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    h2: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    h3: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                    blockquote: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    code: TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                      backgroundColor: Colors.grey[200],
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  softLineBreak: true,
                  selectable: true,
                  onTapLink: (text, href, title) {
                    // Handle link taps if needed
                    print('Link tapped: $href');
                    // You could implement url_launcher here
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
