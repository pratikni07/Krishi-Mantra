import 'package:flutter/material.dart';

class PostActions extends StatelessWidget {
  final Map<String, dynamic> feed;

  const PostActions({
    Key? key,
    required this.feed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ActionButton(
            icon: feed['isLiked'] ? Icons.favorite : Icons.favorite_border,
            label: feed['like']['count'].toString(),
            color: feed['isLiked'] ? Colors.red : Colors.grey,
            onTap: () {
              // Implement like functionality
            },
          ),
          _ActionButton(
            icon: Icons.comment_outlined,
            label: feed['comment']['count'].toString(),
            color: Colors.grey,
            onTap: () {
              FocusScope.of(context).requestFocus(FocusNode());
            },
          ),
          _ActionButton(
            icon: Icons.share_outlined,
            color: Colors.grey,
            onTap: () {
              // Implement share functionality
            },
          ),
          _ActionButton(
            icon: Icons.bookmark_border,
            color: Colors.grey,
            onTap: () {
              // Implement bookmark functionality
            },
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    Key? key,
    required this.icon,
    this.label,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(icon, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label!,
                style: TextStyle(color: color),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
