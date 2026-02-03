import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/constants/api_constants.dart';
import '../../utils/image_utils.dart';

/// Optimized cached image widget with placeholder and error handling
/// Supports automatic CDN URL formatting and responsive sizing
class CachedImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Color? placeholderColor;
  final bool showShimmer;
  final String? heroTag;
  final VoidCallback? onTap;

  const CachedImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.placeholderColor,
    this.showShimmer = true,
    this.heroTag,
    this.onTap,
  });

  String _getFormattedUrl() {
    if (imageUrl == null || imageUrl!.isEmpty) return '';

    String url = imageUrl!;

    // If it's a relative URL (starts with /), prepend the base URL
    if (url.startsWith('/') && !url.startsWith('//')) {
      url = '${ApiConstants.IMAGE_BASE_URL}$url';
    }
    // If it doesn't start with http, it might be just a path, prepend base URL
    else if (!url.startsWith('http')) {
      url = '${ApiConstants.IMAGE_BASE_URL}/$url';
    }

    // Validate the final URL
    final validated = ImageUtils.validateUrl(url);
    return validated;
  }

  @override
  Widget build(BuildContext context) {
    final formattedUrl = _getFormattedUrl();

    if (formattedUrl.isEmpty) {
      return _buildError();
    }

    Widget imageWidget = CachedNetworkImage(
      imageUrl: formattedUrl,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildError(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 150),
      memCacheWidth: _calculateCacheWidth(),
      memCacheHeight: _calculateCacheHeight(),
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    if (heroTag != null) {
      imageWidget = Hero(
        tag: heroTag!,
        child: imageWidget,
      );
    }

    if (onTap != null) {
      imageWidget = GestureDetector(
        onTap: onTap,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  int? _calculateCacheWidth() {
    if (width == null || width!.isInfinite || width!.isNaN) return null;
    // Limit cache size to reasonable dimensions
    return (width! * 2).toInt().clamp(0, 1000);
  }

  int? _calculateCacheHeight() {
    if (height == null || height!.isInfinite || height!.isNaN) return null;
    return (height! * 2).toInt().clamp(0, 1000);
  }

  Widget _buildPlaceholder() {
    if (placeholder != null) return placeholder!;

    if (showShimmer) {
      return Shimmer.fromColors(
        baseColor: placeholderColor ?? Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          width: width,
          height: height,
          color: Colors.white,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? Colors.grey[200],
      child: const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
        ),
      ),
    );
  }

  Widget _buildError() {
    if (errorWidget != null) return errorWidget!;

    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            color: Colors.grey[400],
            size: 32,
          ),
          const SizedBox(height: 4),
          Text(
            'Image not available',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular cached avatar image
class CachedAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? name;
  final Color? backgroundColor;

  const CachedAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 24,
    this.name,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final formattedUrl = _getFormattedUrl();

    if (formattedUrl.isEmpty) {
      return _buildFallbackAvatar();
    }

    return CachedNetworkImage(
      imageUrl: formattedUrl,
      imageBuilder: (context, imageProvider) => CircleAvatar(
        radius: radius,
        backgroundImage: imageProvider,
        backgroundColor: backgroundColor ?? Colors.grey[200],
      ),
      placeholder: (context, url) => _buildLoadingAvatar(),
      errorWidget: (context, url, error) => _buildFallbackAvatar(),
    );
  }

  String _getFormattedUrl() {
    if (imageUrl == null || imageUrl!.isEmpty) return '';

    String url = imageUrl!;

    // If it's a relative URL (starts with /), prepend the base URL
    if (url.startsWith('/') && !url.startsWith('//')) {
      url = '${ApiConstants.IMAGE_BASE_URL}$url';
    }
    // If it doesn't start with http, it might be just a path, prepend base URL
    else if (!url.startsWith('http')) {
      url = '${ApiConstants.IMAGE_BASE_URL}/$url';
    }

    // Validate the final URL
    return ImageUtils.validateUrl(url);
  }

  Widget _buildLoadingAvatar() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey[200],
      child: const CircularProgressIndicator(strokeWidth: 2),
    );
  }

  Widget _buildFallbackAvatar() {
    String initials = '';
    if (name != null && name!.isNotEmpty) {
      final parts = name!.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts[0][0].toUpperCase();
        if (parts.length > 1) {
          initials += parts[1][0].toUpperCase();
        }
      }
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? _getColorFromName(),
      child: initials.isNotEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.7,
                fontWeight: FontWeight.w600,
              ),
            )
          : Icon(
              Icons.person,
              color: Colors.white,
              size: radius,
            ),
    );
  }

  Color _getColorFromName() {
    if (name == null || name!.isEmpty) return Colors.grey;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    return colors[name!.hashCode % colors.length];
  }
}

/// Preload images for better performance
class ImagePreloader {
  static Future<void> preloadImages(
    BuildContext context,
    List<String> urls,
  ) async {
    for (final url in urls) {
      if (url.isNotEmpty) {
        try {
          await precacheImage(
            CachedNetworkImageProvider(ImageUtils.validateUrl(url)),
            context,
          );
        } catch (_) {
          // Ignore preload errors
        }
      }
    }
  }
}
