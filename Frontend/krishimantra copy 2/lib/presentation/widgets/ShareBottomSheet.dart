import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';

class ShareBottomSheet extends StatelessWidget {
  final String postUrl;

  const ShareBottomSheet({Key? key, required this.postUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Share via',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textGrey,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildShareOption(
                icon: Icons.content_copy,
                label: 'Copy Link',
                color: AppColors.textGrey,
                onTap: () {
                  // Add clipboard functionality
                  Navigator.pop(context);
                },
              ),
              _buildShareOption(
                icon: Icons.facebook,
                label: 'WhatsApp',
                color: Colors.green,
                onTap: () {
                  // Add WhatsApp share
                  Navigator.pop(context);
                },
              ),
              _buildShareOption(
                icon: Icons.facebook,
                label: 'Facebook',
                color: Colors.blue,
                onTap: () {
                  // Add Facebook share
                  Navigator.pop(context);
                },
              ),
              _buildShareOption(
                icon: Icons.chat,
                label: 'Twitter',
                color: Colors.lightBlue,
                onTap: () {
                  // Add Twitter share
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
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
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textGrey,
            ),
          ),
        ],
      ),
    );
  }
}
