import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// A compact tractor Lottie animation used as an inline loading indicator.
/// Use this to replace CircularProgressIndicator in contexts like video loading,
/// overlay loading, etc. where a full LoadingStateWidget is too large.
class TractorLoadingIndicator extends StatelessWidget {
  final double size;

  const TractorLoadingIndicator({
    Key? key,
    this.size = 80,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      'assets/Images/icons/Trator verde.json',
      height: size,
      width: size,
      fit: BoxFit.contain,
      repeat: true,
    );
  }
}
