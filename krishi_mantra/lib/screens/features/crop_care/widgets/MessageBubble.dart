import 'package:flutter/material.dart';
import 'package:krishi_mantra/screens/features/crop_care/models/MessageModel.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final Function(String)? onReact;

  const MessageBubble({
    super.key,
    required this.message,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          message.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isSentByMe ? Colors.blue : Colors.grey[300],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageUrl != null)
              message.mediaType == 'image'
                  ? Image.network(
                      message.imageUrl!,
                      width: 200,
                      fit: BoxFit.cover,
                    )
                  : Icon(
                      message.mediaType == 'video'
                          ? Icons.video_library
                          : Icons.insert_drive_file,
                      size: 40,
                    ),
            // if (message.text.isNotEmpty)
            //   Text(
            //     message.text,
            //     style: TextStyle(
            //       color: message.isSentByMe ? Colors.white : Colors.black,
            //     ),
            //   ),
            Text(
              message.timestamp.toString(),
              style: TextStyle(
                fontSize: 12,
                color: message.isSentByMe ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
