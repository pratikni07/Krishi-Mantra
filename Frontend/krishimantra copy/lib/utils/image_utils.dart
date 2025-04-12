import 'package:flutter/material.dart';

class ImageUtils {
  static Widget getNetworkImageWithFallback({
    required String? imageUrl,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
  }) {
    // Default placeholder if none provided
    placeholder ??= Container(
      width: width,
      height: height,
      color: Colors.grey.withOpacity(0.2),
      child: const Center(
        child: Icon(
          Icons.broken_image,
          color: Colors.grey,
          size: 48,
        ),
      ),
    );

    // Check for invalid URLs
    if (imageUrl == null ||
        imageUrl.isEmpty ||
        imageUrl == "file:///" ||
        !_isValidUrl(imageUrl)) {
      return placeholder;
    }

    // Use network image with error handling
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => placeholder!,
    );
  }

  // For profile images that need to be circular
  static ImageProvider getProfileImageProvider(String? imageUrl) {
    if (imageUrl == null ||
        imageUrl.isEmpty ||
        imageUrl == "file:///" ||
        !_isValidUrl(imageUrl)) {
      // Return a default asset image
      return const AssetImage('assets/images/default_avatar.png');
    }

    try {
      return NetworkImage(imageUrl);
    } catch (e) {
      return const AssetImage('assets/images/default_avatar.png');
    }
  }

  // Helper method to validate URLs
  static bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
