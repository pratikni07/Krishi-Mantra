import 'package:flutter/material.dart';
import 'dart:io';

import 'package:krishi_doctor/Pages/models/MessageModel.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final Function(String)? onReact;
  final Widget Function(MessageModel)? pollWidgetBuilder;

  const MessageBubble({
    Key? key, 
    required this.message,
    this.onReact,
    this.pollWidgetBuilder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showReactionBottomSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
        alignment: message.isSentByMe 
          ? Alignment.centerRight 
          : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: message.isSentByMe 
            ? CrossAxisAlignment.end 
            : CrossAxisAlignment.start,
          children: [
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              decoration: BoxDecoration(
                color: message.isSentByMe 
                  ? Colors.green.shade100 
                  : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text message
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: const TextStyle(fontSize: 16),
                    ),
                  
                  // Image message
                  if (message.imageUrl != null)
                    _buildImageWidget(message.imageUrl!),
                  
                  // File message
                  if (message.fileUrl != null)
                    _buildFileWidget(message.fileUrl!),
                  
                  // Video message (placeholder)
                  if (message.videoUrl != null)
                    _buildVideoWidget(message.videoUrl!),
                  
                  // Poll message
                  if (message.isPoll && pollWidgetBuilder != null)
                    pollWidgetBuilder!(message),
                ],
              ),
            ),
            
            // Timestamp
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Text(
                _formatTimestamp(message.timestamp),
                style: TextStyle(
                  fontSize: 12, 
                  color: Colors.grey.shade600
                ),
              ),
            ),

            // Reactions (if any)
            if (message.reactions != null && message.reactions!.isNotEmpty)
              _buildReactions(),
          ],
        ),
      ),
    );
  }

  // Format timestamp to readable string
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    if (now.day == timestamp.day) {
      // Today: show time
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      // Other days: show date
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  // Build image widget
  Widget _buildImageWidget(String imageUrl) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageUrl.startsWith('http') 
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
            )
          : Image.file(
              File(imageUrl),
              width: 200,
              height: 200,
              fit: BoxFit.cover,
            ),
      ),
    );
  }

  // Build file widget
  Widget _buildFileWidget(String fileUrl) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file),
          const SizedBox(width: 8),
          Text(
            fileUrl.split('/').last,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // Build video widget (placeholder)
  Widget _buildVideoWidget(String videoUrl) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      width: 250,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline, 
          color: Colors.white, 
          size: 50,
        ),
      ),
    );
  }

  // Show reaction bottom sheet
  void _showReactionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'React to Message', 
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.bold
                )
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildReactionButton('👍', context),
                  _buildReactionButton('❤️', context),
                  _buildReactionButton('😂', context),
                  _buildReactionButton('😮', context),
                  _buildReactionButton('😢', context),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Build individual reaction button
  Widget _buildReactionButton(String emoji, BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Call onReact callback if provided
        onReact?.call(emoji);
        Navigator.pop(context);
      },
      child: Text(
        emoji, 
        style: const TextStyle(fontSize: 32),
      ),
    );
  }

  // Build reactions display
  Widget _buildReactions() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: message.reactions!.map((reaction) {
          return Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              reaction,
              style: const TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
      ),
    );
  }
}