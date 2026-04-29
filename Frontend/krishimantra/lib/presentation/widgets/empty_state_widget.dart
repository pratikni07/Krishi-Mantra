import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/colors.dart';
import '../../data/services/language_service.dart';

/// A reusable empty-state widget that shows the tractor Lottie animation
/// along with a title and subtitle that are automatically translated to the
/// user's selected language.
class EmptyStateWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final double animationSize;

  const EmptyStateWidget({
    Key? key,
    required this.title,
    required this.subtitle,
    this.animationSize = 200,
  }) : super(key: key);

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget> {
  String _translatedTitle = '';
  String _translatedSubtitle = '';
  bool _isTranslating = true;

  @override
  void initState() {
    super.initState();
    _translatedTitle = widget.title;
    _translatedSubtitle = widget.subtitle;
    _translateTexts();
  }

  @override
  void didUpdateWidget(covariant EmptyStateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.subtitle != widget.subtitle) {
      _translateTexts();
    }
  }

  Future<void> _translateTexts() async {
    try {
      final languageService = await LanguageService.getInstance();
      final translatedTitle = await languageService.translate(widget.title);
      final translatedSubtitle =
          await languageService.translate(widget.subtitle);
      if (mounted) {
        setState(() {
          _translatedTitle = translatedTitle;
          _translatedSubtitle = translatedSubtitle;
          _isTranslating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Tractor Lottie animation
            Lottie.asset(
              'assets/Images/icons/Trator verde.json',
              height: widget.animationSize,
              width: widget.animationSize,
              fit: BoxFit.contain,
              repeat: true,
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              _translatedTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Subtitle
            Text(
              _translatedSubtitle,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textGrey.withValues(alpha: 0.85),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
