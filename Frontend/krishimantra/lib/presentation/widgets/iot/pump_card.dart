import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../screens/iot/pump_control_screen.dart';

/// Widget to display IoT pump status cards on home screen
class IoTPumpSection extends StatelessWidget {
  const IoTPumpSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    
    // Static demo data - will be replaced with API data later
    final List<Map<String, dynamic>> pumps = [
      {
        'id': 'pump_1',
        'name': 'Main Farm Pump',
        'location': 'Field A',
        'isOn': true,
        'lastActivity': DateTime.now().subtract(const Duration(minutes: 30)),
        'waterFlow': 45.5, // liters per minute
      },
      {
        'id': 'pump_2',
        'name': 'Garden Pump',
        'location': 'Backyard',
        'isOn': false,
        'lastActivity': DateTime.now().subtract(const Duration(hours: 2)),
        'waterFlow': 0.0,
      },
    ];

    // Check if user has pumps - for now always show (will integrate API later)
    final hasPumps = pumps.isNotEmpty;

    if (!hasPumps) {
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
                        color: AppColors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppSizes.radiusM),
                      ),
                      child: Icon(
                        Icons.water_drop,
                        color: AppColors.green,
                        size: AppSizes.iconM,
                      ),
                    ),
                    SizedBox(width: AppSizes.paddingS),
                    Text(
                      'My Pumps',
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
                    Get.to(() => const PumpControlScreen());
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
          
          // Horizontal list of pump cards
          SizedBox(
            height: ResponsiveUtils.responsive(mobile: 110.0, tablet: 130.0),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
              itemCount: pumps.length,
              itemBuilder: (context, index) {
                return _buildPumpCard(context, pumps[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPumpCard(BuildContext context, Map<String, dynamic> pump) {
    final bool isOn = pump['isOn'] ?? false;
    final double cardWidth = ResponsiveUtils.responsive(mobile: 200.0, tablet: 240.0);

    return GestureDetector(
      onTap: () {
        Get.to(() => PumpControlScreen(selectedPumpId: pump['id']));
      },
      child: Container(
        width: cardWidth,
        margin: EdgeInsets.only(right: AppSizes.paddingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isOn
                ? [AppColors.green, AppColors.green.withOpacity(0.8)]
                : [Colors.grey.shade600, Colors.grey.shade500],
          ),
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
          boxShadow: [
            BoxShadow(
              color: (isOn ? AppColors.green : Colors.grey).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background water wave pattern
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                Icons.waves,
                size: 100,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            
            // Content
            Padding(
              padding: EdgeInsets.all(AppSizes.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pump name and status indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          pump['name'] ?? 'Pump',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppSizes.fontL,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOn ? Colors.greenAccent : Colors.red.shade300,
                          boxShadow: isOn
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: AppSizes.paddingXS),
                  
                  // Location
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: AppSizes.iconXS,
                      ),
                      SizedBox(width: 4),
                      Text(
                        pump['location'] ?? '',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: AppSizes.fontS,
                        ),
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  
                  // Status and flow rate
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingS,
                          vertical: AppSizes.paddingXS,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        ),
                        child: Text(
                          isOn ? '🟢 Running' : '⚪ Stopped',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppSizes.fontS,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isOn)
                        Text(
                          '${pump['waterFlow']}L/min',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: AppSizes.fontS,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
}
