import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class ShareBottomSheet extends StatelessWidget {
  final String postId;
  final String shareUrl;

  const ShareBottomSheet({
    Key? key,
    required this.postId,
    required this.shareUrl,
  }) : super(key: key);

  void _shareToSocialMedia(String platform) {
    switch (platform) {
      case 'WhatsApp':
        Share.share(
          shareUrl,
          subject: 'Check out this post!',
        );
        break;
      case 'Facebook':
        Share.share(
          shareUrl,
          subject: 'Check out this post!',
        );
        break;
      case 'Twitter':
        Share.share(
          'Check out this post! $shareUrl',
          subject: 'Amazing post',
        );
        break;
      case 'Instagram':
        Share.share(
          shareUrl,
          subject: 'Check out this post!',
        );
        break;
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: shareUrl));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> shareOptions = [
      {
        'platform': 'WhatsApp',
        'icon': Icons.facebook,
        'color': Colors.green,
      },
      {
        'platform': 'Facebook',
        'icon': Icons.facebook,
        'color': Colors.blue,
      },
      {
        'platform': 'Twitter',
        'icon': Icons.flutter_dash,
        'color': Colors.lightBlue,
      },
      {
        'platform': 'Instagram',
        'icon': Icons.camera_alt,
        'color': Colors.purple,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: shareOptions
                .map((option) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => _shareToSocialMedia(option['platform']),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: option['color'].withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              option['icon'],
                              color: option['color'],
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          option['platform'],
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    shareUrl,
                    style: TextStyle(color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyLink(context),
                  color: Colors.grey[600],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
