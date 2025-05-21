import 'package:flutter/material.dart';

class MediaContent extends StatelessWidget {
  final String mediaUrl;

  const MediaContent({
    Key? key,
    required this.mediaUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
      ),
    );
  }
}
