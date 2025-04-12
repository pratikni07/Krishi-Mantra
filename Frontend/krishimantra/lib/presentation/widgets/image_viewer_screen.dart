import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import '../../core/constants/colors.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;
  
  const ImageViewerScreen({
    Key? key,
    required this.imageUrl,
    this.heroTag,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: () {
              // Share functionality can be added here
            },
          ),
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () {
              // Download functionality can be added here
            },
          ),
        ],
      ),
      body: Center(
        child: PhotoView(
          imageProvider: NetworkImage(imageUrl),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
          initialScale: PhotoViewComputedScale.contained,
          heroAttributes: heroTag != null 
              ? PhotoViewHeroAttributes(tag: heroTag!) 
              : null,
          loadingBuilder: (context, event) => Center(
            child: CircularProgressIndicator(
              value: event?.expectedTotalBytes != null
                  ? (event!.cumulativeBytesLoaded / event.expectedTotalBytes!)
                  : null,
              color: AppColors.green,
            ),
          ),
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.black12,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.white70, size: 48),
                    SizedBox(height: 16),
                    Text(
                      "Couldn't load image",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            );
          },
          backgroundDecoration: const BoxDecoration(color: Colors.black),
        ),
      ),
    );
  }
} 