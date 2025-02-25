import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/colors.dart';
import '../../../../data/models/feed_model.dart';
import '../FeedDetailsScreen.dart';

class FeedCard extends StatefulWidget {
  final FeedModel feed;
  final VoidCallback onLike;
  final VoidCallback? onSave;

  const FeedCard({
    Key? key,
    required this.feed,
    required this.onLike,
    this.onSave,
  }) : super(key: key);

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> {
  bool _isExpanded = false;

  Widget _buildHashtagText(String content) {
    final words = content.split(' ');
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.black,
          fontSize: 15,
          height: 1.4,
        ),
        children: words.map((word) {
          if (word.startsWith('#')) {
            return TextSpan(
              text: '$word ',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            );
          }
          return TextSpan(text: '$word ');
        }).toList(),
      ),
    );
  }

  Widget _buildContent(String content) {
    const int maxWords = 100;
    final words = content.split(' ');

    if (words.length <= maxWords || _isExpanded) {
      return _buildHashtagText(content);
    }

    final truncatedContent = words.take(maxWords).join(' ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHashtagText('$truncatedContent...'),
        GestureDetector(
          onTap: () => setState(() => _isExpanded = true),
          child: const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: Text(
              'Show more',
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showShareBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share via',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  context,
                  'Copy Link',
                  Icons.link,
                  Colors.grey,
                  () => Navigator.pop(context),
                ),
                _buildShareOption(
                  context,
                  'WhatsApp',
                  Icons.facebook,
                  Colors.green,
                  () {
                    Share.share(widget.feed.content);
                    Navigator.pop(context);
                  },
                ),
                _buildShareOption(
                  context,
                  'Facebook',
                  Icons.facebook,
                  Colors.blue,
                  () {
                    Share.share(widget.feed.content);
                    Navigator.pop(context);
                  },
                ),
                _buildShareOption(
                  context,
                  'Twitter',
                  Icons.flutter_dash,
                  Colors.lightBlue,
                  () {
                    Share.share(widget.feed.content);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User Info Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 2,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundImage: NetworkImage(widget.feed.profilePhoto),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.feed.userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Uploaded ${timeago.format(widget.feed.date)}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      // if (widget.feed.location != null)
                      //   Row(
                      //     children: [
                      //       const Icon(
                      //         Icons.location_on,
                      //         size: 14,
                      //         color: AppColors.textGrey,
                      //       ),
                      //       const SizedBox(width: 4),
                      //       Text(
                      //         widget.feed.location?['name'] ?? '',
                      //         style: const TextStyle(
                      //           color: AppColors.textGrey,
                      //           fontSize: 12,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Media Content
          if (widget.feed.mediaUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              child: Image.network(
                widget.feed.mediaUrl!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

          // Text Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildContent(widget.feed.content),
          ),

          // Actions Section with equal spacing
          // Find this section in the Padding widget with Row children inside your FeedCard
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: widget.feed.isLiked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: widget.feed.isLiked ? Colors.red : Colors.grey,
                  count: widget.feed.like['count'],
                  onTap: widget.onLike,
                ),
                _buildActionButton(
                  icon: Icons.comment_outlined,
                  color: Colors.grey,
                  count: widget.feed.comment['count'],
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FeedDetailsScreen(feed: widget.feed.toJson()),
                      ),
                    );
                  },
                ),
                _buildActionButton(
                  icon: Icons.share_outlined,
                  color: Colors.grey,
                  onTap: () => _showShareBottomSheet(context),
                ),
                _buildActionButton(
                  icon: Icons.bookmark_border,
                  color: Colors.grey,
                  onTap: widget.onSave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    int? count,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            if (count != null) ...[
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
