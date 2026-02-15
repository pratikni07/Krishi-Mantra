import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../screens/iot/crop_sensor_screen.dart';

/// Widget to display IoT crop sensor cards on home screen
class IoTCropSensorSection extends StatelessWidget {
  const IoTCropSensorSection({Key? key}) : super(key: key);

  // Earthy teal color palette for crop sensors
  static const Color _primaryColor = Color(0xFF2E7D6C); // Deep teal
  static const Color _secondaryColor = Color(0xFF4DB6A3); // Light teal

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    
    // Static demo data - will be replaced with API data later
    final List<Map<String, dynamic>> sensors = [
      {
        'id': 'sensor_1',
        'name': 'Wheat Field Sensors',
        'cropName': 'Wheat',
        'cropIcon': '🌾',
        'location': 'Field A - 2 Acres',
        'soilMoisture': 65.0, // percentage
        'temperature': 28.5, // celsius
        'humidity': 72.0, // percentage
        'alertsCount': 2,
        'lastSync': DateTime.now().subtract(const Duration(minutes: 15)),
      },
      {
        'id': 'sensor_2',
        'name': 'Rice Paddy Monitor',
        'cropName': 'Rice',
        'cropIcon': '🌿',
        'location': 'Field B - 1.5 Acres',
        'soilMoisture': 85.0,
        'temperature': 30.2,
        'humidity': 80.0,
        'alertsCount': 0,
        'lastSync': DateTime.now().subtract(const Duration(minutes: 5)),
      },
      {
        'id': 'sensor_3',
        'name': 'Vegetable Garden',
        'cropName': 'Tomatoes',
        'cropIcon': '🍅',
        'location': 'Backyard - 0.5 Acres',
        'soilMoisture': 45.0,
        'temperature': 26.8,
        'humidity': 65.0,
        'alertsCount': 1,
        'lastSync': DateTime.now().subtract(const Duration(hours: 1)),
      },
    ];

    final hasSensors = sensors.isNotEmpty;

    if (!hasSensors) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(vertical: AppSizes.paddingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppSizes.paddingS),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                      child: Icon(
                        Icons.sensors,
                        color: _primaryColor,
                        size: AppSizes.iconM,
                      ),
                    ),
                    SizedBox(width: AppSizes.paddingS),
                    Text(
                      'Krishi Doctor',
                      style: TextStyle(
                        fontSize: AppSizes.fontXL,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    Get.to(() => const CropSensorScreen());
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: AppSizes.fontM,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSizes.paddingM),
          
          // Horizontal list of sensor cards
          SizedBox(
            height: ResponsiveUtils.responsive(mobile: 110.0, tablet: 130.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
              itemCount: sensors.length,
              itemBuilder: (context, index) {
                return _buildSensorCard(context, sensors[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(BuildContext context, Map<String, dynamic> sensor) {
    final int alertsCount = sensor['alertsCount'] ?? 0;
    final double cardWidth = ResponsiveUtils.responsive(mobile: 200.0, tablet: 240.0);

    return GestureDetector(
      onTap: () {
        Get.to(() => CropSensorScreen(selectedSensorId: sensor['id']));
      },
      child: Container(
        width: cardWidth,
        margin: EdgeInsets.only(right: AppSizes.paddingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryColor, _secondaryColor],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -20,
              bottom: -20,
              child: Text(
                sensor['cropIcon'] ?? '🌱',
                style: TextStyle(
                  fontSize: 80,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            
            // Alert badge
            if (alertsCount > 0)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning, color: Colors.white, size: 10),
                      SizedBox(width: 2),
                      Text(
                        '$alertsCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            
            // Content
            Padding(
              padding: EdgeInsets.all(AppSizes.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Crop name with icon
                  Row(
                    children: [
                      Text(
                        sensor['cropIcon'] ?? '🌱',
                        style: TextStyle(fontSize: 22),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          sensor['cropName'] ?? 'Crop',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppSizes.fontL,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 4),
                  
                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: 12,
                      ),
                      SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          sensor['location'] ?? '',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Quick stats row - using Wrap for overflow protection
                  Row(
                    children: [
                      Expanded(child: _buildMiniStat('💧', '${sensor['soilMoisture']?.toInt()}%')),
                      SizedBox(width: 4),
                      Expanded(child: _buildMiniStat('🌡', '${sensor['temperature']?.toInt()}°')),
                      SizedBox(width: 4),
                      Expanded(child: _buildMiniStat('💨', '${sensor['humidity']?.toInt()}%')),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String icon, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: TextStyle(fontSize: 10)),
          SizedBox(width: 2),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
