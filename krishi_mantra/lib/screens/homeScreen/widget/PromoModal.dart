import 'dart:async';

import 'package:flutter/material.dart';

class PromoModal extends StatelessWidget {
  final VoidCallback onClose;
  final String imageUrl;
  final String targetUrl;

  const PromoModal({
    Key? key,
    required this.onClose,
    required this.imageUrl,
    required this.targetUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                GestureDetector(
                  onTap: () {
                    // Handle navigation to target URL
                    // You'll need to implement your navigation logic here
                    print('Navigate to: $targetUrl');
                  },
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(15),
                    ),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      height: 400,
                      width: double.infinity,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 400,
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: onClose,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
