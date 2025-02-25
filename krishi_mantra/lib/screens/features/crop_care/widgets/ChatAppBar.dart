// chat_app_bar.dart
import 'package:flutter/material.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userName;
  final String userProfilePic;
  final VoidCallback onMoreOptionsPressed;

  const ChatAppBar({
    super.key,
    required this.userName,
    required this.userProfilePic,
    required this.onMoreOptionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(userProfilePic),
            radius: 20,
          ),
          const SizedBox(width: 8),
          Text(userName),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onMoreOptionsPressed,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
