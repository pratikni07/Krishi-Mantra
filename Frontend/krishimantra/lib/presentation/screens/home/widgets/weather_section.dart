import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../weather/WeatherScreen.dart';
import 'weather_item.dart';
import 'package:get/get.dart';
import '../../../../data/services/language_service.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/location_dialog.dart';

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
  // Translatable text
  String temperatureText = "Temperature";
  String humidityText = "Humidity";
  String cloudsText = "Clouds";
  String allowLocationText = "Allow Location";
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTranslations();
  }

  Future<void> _initializeTranslations() async {
    final languageService = await LanguageService.getInstance();
    
    final translations = await Future.wait([
      languageService.translate('Temperature'),
      languageService.translate('Humidity'),
      languageService.translate('Clouds'),
      languageService.translate('Allow Location'),
    ]);
    
    if (mounted) {
      setState(() {
        temperatureText = translations[0];
        humidityText = translations[1];
        cloudsText = translations[2];
        allowLocationText = translations[3];
        _initialized = true;
      });
    }
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
                  'Weather data requires location',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                allowLocationText,
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
            temperatureText,
          ),
          _buildWeatherItem(
            context,
            Icons.water_drop,
            '${widget.humidity}%',
            humidityText,
          ),
          _buildWeatherItem(
            context,
            Icons.cloud,
            '${widget.cloudiness}%',
            cloudsText,
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
    if (label == temperatureText) {
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
}
