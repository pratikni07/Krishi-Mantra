import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../weather/WeatherScreen.dart';
import 'weather_item.dart';
import 'package:get/get.dart';


class WeatherSection extends StatelessWidget {
  final double statusBarHeight;
  final double screenWidth;
  final double temperature;
  final int humidity;
  final int cloudiness;

  const WeatherSection({
    Key? key,
    required this.statusBarHeight,
    required this.screenWidth,
    required this.temperature,
    required this.humidity,
    required this.cloudiness,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: statusBarHeight + 60),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildWeatherItem(
            context,
            Icons.thermostat,
            '$temperature°C',
            'Temperature',
          ),
          _buildWeatherItem(
            context,
            Icons.water_drop,
            '$humidity%',
            'Humidity',
          ),
          _buildWeatherItem(
            context,
            Icons.cloud,
            '$cloudiness%',
            'Clouds',
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
    if (label == 'Temperature') {
      double temp = double.tryParse(value.replaceAll('°C', '')) ?? 0;
      displayValue = '${temp.round()}°C';
    }

    return GestureDetector(
      onTap: () => Get.to(() => const WeatherScreen()),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
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
