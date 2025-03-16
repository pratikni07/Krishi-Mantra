import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../data/services/language_service.dart';

class WeatherItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final double width;

  const WeatherItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.width,
  });

  @override
  State<WeatherItem> createState() => _WeatherItemState();
}

class _WeatherItemState extends State<WeatherItem> {
  String _translatedLabel = "";
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _translateLabel();
  }

  Future<void> _translateLabel() async {
    final languageService = await LanguageService.getInstance();
    final translated = await languageService.translate(widget.label);
    
    if (mounted) {
      setState(() {
        _translatedLabel = translated;
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, color: AppColors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            _initialized ? _translatedLabel : widget.label,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.value,
            style: TextStyle(
              color: AppColors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
