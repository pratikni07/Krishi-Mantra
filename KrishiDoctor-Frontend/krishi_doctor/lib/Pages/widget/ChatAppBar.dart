import 'package:flutter/material.dart';

class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userName;
  final String userProfilePic;
  final VoidCallback onMoreOptionsPressed;

  const ChatAppBar({
    Key? key,
    required this.userName,
    required this.userProfilePic,
    required this.onMoreOptionsPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(userProfilePic),
            radius: 20,
          ),
          const SizedBox(width: 10),
          Text(
            userName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: onMoreOptionsPressed,
        ),
      ],
      backgroundColor: Colors.green.shade500,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}