import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../core/constants/colors.dart';
import '../../data/services/language_service.dart';

/// A reusable loading-state widget that shows the tractor Lottie animation
/// with a translatable loading message.
class LoadingStateWidget extends StatefulWidget {
  final String message;
  final double animationSize;

  const LoadingStateWidget({
    Key? key,
    this.message = 'Loading...',
    this.animationSize = 180,
  }) : super(key: key);

  @override
  State<LoadingStateWidget> createState() => _LoadingStateWidgetState();
}

class _LoadingStateWidgetState extends State<LoadingStateWidget> {
  String _translatedMessage = '';

  @override
  void initState() {
    super.initState();
    _translatedMessage = widget.message;
    _translateText();
  }

  @override
  void didUpdateWidget(covariant LoadingStateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) {
      _translateText();
    }
  }

  Future<void> _translateText() async {
    try {
      final languageService = await LanguageService.getInstance();
      final translated = await languageService.translate(widget.message);
      if (mounted) {
        setState(() {
          _translatedMessage = translated;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
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
            const SizedBox(height: 20),
            Text(
              _translatedMessage,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey.withOpacity(0.85),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
