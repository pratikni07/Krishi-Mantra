import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/home_localizations.dart';
import '../../../../core/utils/translation_manager.dart';
import '../../weather/WeatherScreen.dart';
import 'weather_item.dart';
import 'package:get/get.dart';
import '../../../../data/services/language_service.dart';

class WeatherSection extends StatefulWidget {
  final double statusBarHeight;
  final double screenWidth;
  final double temperature;
  final int humidity;
  final int cloudiness;
  final bool hasLocationPermission;
  final VoidCallback onRequestLocation;

  const WeatherSection({
    Key? key,
    required this.statusBarHeight,
    required this.screenWidth,
    required this.temperature,
    required this.humidity,
    required this.cloudiness,
    this.hasLocationPermission = true,
    required this.onRequestLocation,
  }) : super(key: key);

  @override
  State<WeatherSection> createState() => _WeatherSectionState();
}

class _WeatherSectionState extends State<WeatherSection> {
  String _languageCode = '';

  @override
  void initState() {
    super.initState();
    _syncLanguageCode();
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
  }

  Future<void> _syncLanguageCode() async {
    final languageService = await LanguageService.getInstance();
    if (mounted) {
      setState(() {
        _languageCode = languageService.getLanguageCode();
      });
    }
  }

  Future<void> _onLanguageChanged() async {
    await _syncLanguageCode();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hasLocationPermission) {
      return Container(
        padding: EdgeInsets.only(top: widget.statusBarHeight + 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/Images/krishimantralocation.png',
                  height: 40,
                  width: 40,
                ),
                const SizedBox(width: 12),
                Text(
                  _t('weather_requires_location'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: widget.onRequestLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                _t('allow_location'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(top: widget.statusBarHeight + 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildWeatherItem(
            context,
            Icons.thermostat,
            '${widget.temperature}°C',
            _t('temperature'),
          ),
          _buildWeatherItem(
            context,
            Icons.water_drop,
            '${widget.humidity}%',
            _t('humidity'),
          ),
          _buildWeatherItem(
            context,
            Icons.cloud,
            '${widget.cloudiness}%',
            _t('clouds'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherItem(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    // Format temperature to show only whole number
    String displayValue = value;
    if (label == _t('temperature')) {
      double temp = double.tryParse(value.replaceAll('°C', '')) ?? 0;
      displayValue = '${temp.round()}°C';
    }

    return GestureDetector(
      onTap: () => Get.to(() => const WeatherScreen()),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              displayValue,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _t(String key) {
    if (_languageCode.isEmpty) {
      return '';
    }
    return HomeLocalizations.text(key, _languageCode);
  }

  @override
  void dispose() {
    TranslationManager.instance
        .removeLanguageChangeListener(_onLanguageChanged);
    super.dispose();
  }
}
