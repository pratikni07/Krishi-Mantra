import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import 'weather_item.dart';

class WeatherSection extends StatelessWidget {
  final double statusBarHeight;
  final double screenWidth;
  final double temperature;
  final int humidity;
  final int cloudiness;

  const WeatherSection({
    super.key,
    required this.statusBarHeight,
    required this.screenWidth,
    required this.temperature,
    required this.humidity,
    required this.cloudiness,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.green,
      padding: EdgeInsets.only(
        top: statusBarHeight + 80,
        bottom: 16,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          WeatherItem(
            icon: Icons.thermostat,
            label: 'Temp',
            value: '${temperature.toStringAsFixed(1)}°C',
            width: screenWidth * 0.3,
          ),
          WeatherItem(
            icon: Icons.water_drop,
            label: 'Humidity',
            value: '$humidity%',
            width: screenWidth * 0.3,
          ),
          WeatherItem(
            icon: Icons.cloud,
            label: 'Cloud',
            value: '$cloudiness%',
            width: screenWidth * 0.3,
          ),
        ],
      ),
    );
  }
}
