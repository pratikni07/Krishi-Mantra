import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/constants/colors.dart';
import '../../controllers/video_tutorial_controller.dart';

class CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final String? parentUserName;
  final VoidCallback onReply;
  final VoidCallback onLike;
  final VoidCallback? onDelete;

  const CommentTile({
    Key? key,
    required this.comment,
    this.parentUserName,
    required this.onReply,
    required this.onLike,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Safely access values with null checking
    final userName = comment['userName'] as String? ?? 'Unknown User';
    final content = comment['content'] as String? ?? '';
    final profilePhoto = comment['profilePhoto'] as String?;
    final createdAt = comment['createdAt'] != null
        ? DateTime.parse(comment['createdAt'] as String)
        : DateTime.now();

    // Safely access nested values
    final likesMap = comment['likes'] is Map
        ? comment['likes'] as Map
        : {'count': 0, 'users': []};
    final likesCount = likesMap['count'] as int? ?? 0;
    final likedUsers =
        likesMap['users'] is List ? likesMap['users'] as List : [];

    final currentUserId = Get.find<VideoTutorialController>().currentUserId;
    final hasLiked =
        currentUserId != null && likedUsers.contains(currentUserId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundImage: profilePhoto != null
                ? CachedNetworkImageProvider(profilePhoto)
                : null,
            child: profilePhoto == null
                ? Text(
                    userName.isNotEmpty
                        ? userName.substring(0, 1).toUpperCase()
                        : '?',
                    style: const TextStyle(color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      userName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (parentUserName != null)
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '@$parentUserName ',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextSpan(
                          text: content,
                          style: DefaultTextStyle.of(context).style,
                        ),
                      ],
                    ),
                  )
                else
                  Text(content),
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: onLike,
                      child: Row(
                        children: [
                          Icon(
                            hasLiked ? Icons.favorite : Icons.favorite_border,
                            size: 16,
                            color: hasLiked ? Colors.red : Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            likesCount.toString(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: onReply,
                      child: Text(
                        'Reply',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (onDelete != null) ...[
                      const SizedBox(width: 16),
                      GestureDetector(
                        onTap: onDelete,
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: Colors.red[400],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
