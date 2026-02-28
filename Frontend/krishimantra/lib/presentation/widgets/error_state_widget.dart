import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/colors.dart';
import '../../data/services/language_service.dart';

/// A reusable error-state widget that shows the tractor Lottie animation
/// with a translatable error message and subtitle.
class ErrorStateWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final double animationSize;

  const ErrorStateWidget({
    Key? key,
    this.title = 'Oops! Something went wrong',
    this.subtitle =
        'The tractor hit a bump on the road. Please try again later!',
    this.animationSize = 180,
  }) : super(key: key);

  @override
  State<ErrorStateWidget> createState() => _ErrorStateWidgetState();
}

class _ErrorStateWidgetState extends State<ErrorStateWidget> {
  String _translatedTitle = '';
  String _translatedSubtitle = '';

  @override
  void initState() {
    super.initState();
    _translatedTitle = widget.title;
    _translatedSubtitle = widget.subtitle;
    _translateTexts();
  }

  @override
  void didUpdateWidget(covariant ErrorStateWidget oldWidget) {
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
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/Images/icons/Trator verde.json',
              height: widget.animationSize,
              width: widget.animationSize,
              fit: BoxFit.contain,
              repeat: true,
            ),
            const SizedBox(height: 24),
            Text(
              _translatedTitle,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _translatedSubtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textGrey.withOpacity(0.85),
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
