import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../utils/image_utils.dart';

class PostHeader extends StatelessWidget {
  final Map<String, dynamic> feed;

  const PostHeader({
    Key? key,
    required this.feed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          _buildAvatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feed['userName'] ?? 'Unknown User',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getTimeAgo(),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final profilePhoto = feed['profilePhoto'];

    // Check if URL is valid
    if (profilePhoto != null && profilePhoto.toString().isNotEmpty) {
      final validatedUrl = ImageUtils.validateUrl(profilePhoto);
      if (validatedUrl.isNotEmpty) {
        return CircleAvatar(
          backgroundImage: NetworkImage(validatedUrl),
          radius: 24,
          onBackgroundImageError: (_, __) {
            print('Error loading profile image: $validatedUrl');
          },
        );
      }
    }

    // Fallback for invalid or missing URL
    final userName = feed['userName'] ?? 'U';
    final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';

    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.grey[300],
      child: Text(
        firstLetter,
        style: const TextStyle(
          color: Colors.black54,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  String _getTimeAgo() {
    try {
      return timeago
          .format(DateTime.parse(feed['date'] ?? DateTime.now().toString()));
    } catch (e) {
      return '';
    }
  }
}
