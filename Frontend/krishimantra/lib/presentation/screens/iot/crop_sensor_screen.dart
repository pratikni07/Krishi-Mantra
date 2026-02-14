import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/services/language_service.dart';

/// Full crop sensor dashboard with sensor data, graphs, pie charts, and recommendations
class CropSensorScreen extends StatefulWidget {
  final String? selectedSensorId;

  const CropSensorScreen({Key? key, this.selectedSensorId}) : super(key: key);

  @override
  State<CropSensorScreen> createState() => _CropSensorScreenState();
}

class _CropSensorScreenState extends State<CropSensorScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late LanguageService _languageService;
  
  // Earthy teal color palette
  static const Color _primaryColor = Color(0xFF2E7D6C); // Deep teal
  static const Color _secondaryColor = Color(0xFF4DB6A3); // Light teal
  
  late List<Map<String, dynamic>> sensors;
  int _selectedSensorIndex = 0;

  // Translations
  String cropSensorsText = 'Crop Sensors';
  String dashboardText = 'Dashboard';
  String suggestionsText = 'Suggestions';
  String alertsText = 'Alerts';
  String analyticsText = 'Analytics';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeSensors();
    _initializeLanguage();
  }

  void _initializeSensors() {
    sensors = [
      {
        'id': 'sensor_1',
        'name': 'Wheat Field Sensors',
        'cropName': 'Wheat',
        'cropIcon': '🌾',
        'location': 'Field A - 2 Acres',
        'soilMoisture': 65.0,
        'soilPH': 6.8,
        'nitrogen': 45.0,
        'phosphorus': 32.0,
        'potassium': 28.0,
        'temperature': 28.5,
        'humidity': 72.0,
        'lightIntensity': 85.0,
        'alertsCount': 2,
        'lastSync': DateTime.now().subtract(const Duration(minutes: 15)),
        'soilMoistureHistory': [60.0, 62.0, 58.0, 65.0, 70.0, 68.0, 65.0],
        'temperatureHistory': [26.0, 27.5, 28.0, 29.5, 30.0, 28.5, 28.5],
        'humidityHistory': [70.0, 72.0, 75.0, 73.0, 71.0, 70.0, 72.0],
        'alerts': [
          {
            'type': 'warning',
            'title': 'Low Nitrogen Level',
            'message': 'Nitrogen level is below optimal. Consider adding urea fertilizer.',
            'time': DateTime.now().subtract(const Duration(hours: 2)),
          },
          {
            'type': 'info',
            'title': 'Irrigation Recommended',
            'message': 'Soil moisture dropping. Schedule irrigation in next 24 hours.',
            'time': DateTime.now().subtract(const Duration(hours: 6)),
          },
        ],
        'suggestions': [
          {
            'title': 'Fertilizer Application',
            'description': 'Apply 25kg/acre of urea to boost nitrogen levels. Best time: early morning.',
            'priority': 'high',
            'icon': Icons.science,
          },
          {
            'title': 'Pest Prevention',
            'description': 'Monitor for aphids. Current weather conditions favor pest development.',
            'priority': 'medium',
            'icon': Icons.bug_report,
          },
          {
            'title': 'Next Irrigation',
            'description': 'Based on current soil moisture, irrigate in 2 days for optimal growth.',
            'priority': 'low',
            'icon': Icons.water_drop,
          },
        ],
      },
      {
        'id': 'sensor_2',
        'name': 'Rice Paddy Monitor',
        'cropName': 'Rice',
        'cropIcon': '🌿',
        'location': 'Field B - 1.5 Acres',
        'soilMoisture': 85.0,
        'soilPH': 6.2,
        'nitrogen': 52.0,
        'phosphorus': 38.0,
        'potassium': 35.0,
        'temperature': 30.2,
        'humidity': 80.0,
        'lightIntensity': 78.0,
        'alertsCount': 0,
        'lastSync': DateTime.now().subtract(const Duration(minutes: 5)),
        'soilMoistureHistory': [82.0, 84.0, 86.0, 88.0, 85.0, 83.0, 85.0],
        'temperatureHistory': [28.0, 29.0, 30.5, 31.0, 30.0, 29.5, 30.2],
        'humidityHistory': [78.0, 80.0, 82.0, 81.0, 79.0, 78.0, 80.0],
        'alerts': [],
        'suggestions': [
          {
            'title': 'Water Level Optimal',
            'description': 'Maintain current water level. Rice paddy conditions are ideal.',
            'priority': 'low',
            'icon': Icons.check_circle,
          },
          {
            'title': 'Harvest Preparation',
            'description': 'Crop is approaching maturity. Prepare for harvest in 2-3 weeks.',
            'priority': 'medium',
            'icon': Icons.agriculture,
          },
        ],
      },
      {
        'id': 'sensor_3',
        'name': 'Vegetable Garden',
        'cropName': 'Tomatoes',
        'cropIcon': '🍅',
        'location': 'Backyard - 0.5 Acres',
        'soilMoisture': 45.0,
        'soilPH': 6.5,
        'nitrogen': 38.0,
        'phosphorus': 42.0,
        'potassium': 40.0,
        'temperature': 26.8,
        'humidity': 65.0,
        'lightIntensity': 90.0,
        'alertsCount': 1,
        'lastSync': DateTime.now().subtract(const Duration(hours: 1)),
        'soilMoistureHistory': [55.0, 50.0, 48.0, 45.0, 42.0, 40.0, 45.0],
        'temperatureHistory': [25.0, 26.0, 27.0, 27.5, 27.0, 26.5, 26.8],
        'humidityHistory': [68.0, 66.0, 65.0, 64.0, 63.0, 64.0, 65.0],
        'alerts': [
          {
            'type': 'critical',
            'title': 'Low Soil Moisture',
            'message': 'Urgent irrigation needed. Soil moisture is critically low for tomatoes.',
            'time': DateTime.now().subtract(const Duration(minutes: 30)),
          },
        ],
        'suggestions': [
          {
            'title': 'Immediate Irrigation',
            'description': 'Water immediately. Tomatoes require 60-70% soil moisture for optimal growth.',
            'priority': 'high',
            'icon': Icons.water_drop,
          },
          {
            'title': 'Mulching Recommended',
            'description': 'Add organic mulch to retain soil moisture and reduce evaporation.',
            'priority': 'medium',
            'icon': Icons.eco,
          },
          {
            'title': 'Staking Support',
            'description': 'Plants are growing well. Add stakes for better fruit support.',
            'priority': 'low',
            'icon': Icons.straighten,
          },
        ],
      },
    ];

    if (widget.selectedSensorId != null) {
      final index = sensors.indexWhere((s) => s['id'] == widget.selectedSensorId);
      if (index >= 0) _selectedSensorIndex = index;
    }
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('Crop Sensors'),
      _languageService.translate('Dashboard'),
      _languageService.translate('Suggestions'),
      _languageService.translate('Alerts'),
      _languageService.translate('Analytics'),
    ]);

    if (mounted) {
      setState(() {
        cropSensorsText = translations[0];
        dashboardText = translations[1];
        suggestionsText = translations[2];
        alertsText = translations[3];
        analyticsText = translations[4];
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final currentSensor = sensors[_selectedSensorIndex];
    final alertsCount = currentSensor['alertsCount'] ?? 0;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: _primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          cropSensorsText,
          style: TextStyle(
            color: Colors.white,
            fontSize: AppSizes.fontXL,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Sync button
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: () {
              Get.snackbar(
                'Syncing',
                'Fetching latest sensor data...',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: _primaryColor,
                colorText: Colors.white,
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(sensors.length > 1 ? 120 : 60),
          child: Column(
            children: [
              // Sensor selector
              if (sensors.length > 1)
                Container(
                  height: 60,
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: sensors.length,
                    itemBuilder: (context, index) {
                      final sensor = sensors[index];
                      final isSelected = index == _selectedSensorIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSensorIndex = index),
                        child: Container(
                          margin: EdgeInsets.only(right: AppSizes.paddingS),
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSizes.paddingL,
                            vertical: AppSizes.paddingS,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : Colors.white24,
                            borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
                          ),
                          child: Row(
                            children: [
                              Text(sensor['cropIcon'] ?? '🌱', style: TextStyle(fontSize: 18)),
                              SizedBox(width: AppSizes.paddingXS),
                              Text(
                                sensor['cropName'],
                                style: TextStyle(
                                  color: isSelected ? _primaryColor : Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppSizes.fontM,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // Tabs
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                tabs: [
                  Tab(text: dashboardText),
                  Tab(text: suggestionsText),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(alertsText),
                        if (alertsCount > 0) ...[
                          SizedBox(width: 6),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$alertsCount',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Tab(text: analyticsText),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDashboardTab(currentSensor),
          _buildSuggestionsTab(currentSensor),
          _buildAlertsTab(currentSensor),
          _buildAnalyticsTab(currentSensor),
        ],
      ),
    );
  }

  // ========== DASHBOARD TAB ==========
  Widget _buildDashboardTab(Map<String, dynamic> sensor) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Crop header card
          Container(
            padding: EdgeInsets.all(AppSizes.paddingL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            ),
            child: Row(
              children: [
                Text(sensor['cropIcon'] ?? '🌱', style: TextStyle(fontSize: 50)),
                SizedBox(width: AppSizes.paddingL),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sensor['name'] ?? 'Sensor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: AppSizes.fontXL,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text(
                            sensor['location'] ?? '',
                            style: TextStyle(color: Colors.white70, fontSize: AppSizes.fontS),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Last sync: ${_formatLastSync(sensor['lastSync'])}',
                        style: TextStyle(color: Colors.white70, fontSize: AppSizes.fontXS),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: AppSizes.paddingXL),
          
          // Environmental conditions
          Text(
            'Environmental Conditions',
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: AppSizes.paddingM),
          
          Row(
            children: [
              Expanded(
                child: _buildEnvCard(
                  icon: Icons.thermostat,
                  label: 'Temperature',
                  value: '${sensor['temperature']}°C',
                  color: Colors.red.shade400,
                  progress: (sensor['temperature'] as double) / 50,
                ),
              ),
              SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildEnvCard(
                  icon: Icons.water_drop,
                  label: 'Humidity',
                  value: '${sensor['humidity']?.toInt()}%',
                  color: Colors.blue.shade400,
                  progress: (sensor['humidity'] as double) / 100,
                ),
              ),
            ],
          ),
          
          SizedBox(height: AppSizes.paddingM),
          
          Row(
            children: [
              Expanded(
                child: _buildEnvCard(
                  icon: Icons.wb_sunny,
                  label: 'Light',
                  value: '${sensor['lightIntensity']?.toInt()}%',
                  color: Colors.amber.shade600,
                  progress: (sensor['lightIntensity'] as double) / 100,
                ),
              ),
              SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildEnvCard(
                  icon: Icons.grass,
                  label: 'Soil Moisture',
                  value: '${sensor['soilMoisture']?.toInt()}%',
                  color: AppColors.green,
                  progress: (sensor['soilMoisture'] as double) / 100,
                ),
              ),
            ],
          ),
          
          SizedBox(height: AppSizes.paddingXL),
          
          // Soil Nutrients
          Text(
            'Soil Nutrients (NPK)',
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: AppSizes.paddingM),
          
          Container(
            padding: EdgeInsets.all(AppSizes.paddingL),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildNutrientBar('Nitrogen (N)', sensor['nitrogen'] ?? 0, Colors.green),
                SizedBox(height: AppSizes.paddingM),
                _buildNutrientBar('Phosphorus (P)', sensor['phosphorus'] ?? 0, Colors.orange),
                SizedBox(height: AppSizes.paddingM),
                _buildNutrientBar('Potassium (K)', sensor['potassium'] ?? 0, Colors.purple),
              ],
            ),
          ),
          
          SizedBox(height: AppSizes.paddingM),
          
          // Soil pH
          _buildSoilPHCard(sensor['soilPH'] ?? 7.0),
        ],
      ),
    );
  }

  Widget _buildEnvCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required double progress,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: AppSizes.iconL),
          SizedBox(height: AppSizes.paddingS),
          Text(
            value,
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: AppSizes.paddingXS),
          Text(
            label,
            style: TextStyle(
              fontSize: AppSizes.fontS,
              color: AppColors.textGrey,
            ),
          ),
          SizedBox(height: AppSizes.paddingS),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(fontSize: AppSizes.fontS, color: AppColors.textDark),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value / 100,
              backgroundColor: color.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 12,
            ),
          ),
        ),
        SizedBox(width: AppSizes.paddingS),
        Text(
          '${value.toInt()}%',
          style: TextStyle(
            fontSize: AppSizes.fontM,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSoilPHCard(double ph) {
    final Color phColor = ph < 6.0 ? Colors.orange : (ph > 7.5 ? Colors.blue : AppColors.green);
    final String phStatus = ph < 6.0 ? 'Acidic' : (ph > 7.5 ? 'Alkaline' : 'Optimal');
    
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: phColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: phColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: phColor,
            ),
            child: Center(
              child: Text(
                ph.toStringAsFixed(1),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppSizes.fontXL,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: AppSizes.paddingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Soil pH Level',
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  phStatus,
                  style: TextStyle(
                    fontSize: AppSizes.fontM,
                    color: phColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== SUGGESTIONS TAB ==========
  Widget _buildSuggestionsTab(Map<String, dynamic> sensor) {
    final suggestions = sensor['suggestions'] as List;

    return suggestions.isEmpty
        ? _buildEmptyState(Icons.lightbulb_outline, 'No suggestions', 'All parameters are optimal!')
        : ListView.builder(
            padding: EdgeInsets.all(AppSizes.paddingL),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return _buildSuggestionCard(suggestion);
            },
          );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> suggestion) {
    final priority = suggestion['priority'] ?? 'low';
    final Color priorityColor = priority == 'high'
        ? Colors.red
        : (priority == 'medium' ? Colors.orange : AppColors.green);

    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.paddingM),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: priorityColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: priorityColor.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority badge header
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL, vertical: AppSizes.paddingS),
            decoration: BoxDecoration(
              color: priorityColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSizes.radiusL),
                topRight: Radius.circular(AppSizes.radiusL),
              ),
            ),
            child: Row(
              children: [
                Icon(suggestion['icon'] ?? Icons.info, color: priorityColor, size: 20),
                SizedBox(width: AppSizes.paddingS),
                Expanded(
                  child: Text(
                    suggestion['title'] ?? '',
                    style: TextStyle(
                      fontSize: AppSizes.fontL,
                      fontWeight: FontWeight.bold,
                      color: priorityColor,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priority.toString().toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSizes.paddingL),
            child: Text(
              suggestion['description'] ?? '',
              style: TextStyle(
                fontSize: AppSizes.fontM,
                color: AppColors.textDark,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========== ALERTS TAB ==========
  Widget _buildAlertsTab(Map<String, dynamic> sensor) {
    final alerts = sensor['alerts'] as List;

    return alerts.isEmpty
        ? _buildEmptyState(Icons.notifications_off, 'No alerts', 'Everything looks good!')
        : ListView.builder(
            padding: EdgeInsets.all(AppSizes.paddingL),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return _buildAlertCard(alert);
            },
          );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final type = alert['type'] ?? 'info';
    final Color alertColor = type == 'critical'
        ? Colors.red
        : (type == 'warning' ? Colors.orange : Colors.blue);
    final IconData alertIcon = type == 'critical'
        ? Icons.error
        : (type == 'warning' ? Icons.warning : Icons.info);

    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.paddingM),
      padding: EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: alertColor.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: alertColor,
              shape: BoxShape.circle,
            ),
            child: Icon(alertIcon, color: Colors.white, size: 20),
          ),
          SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'] ?? '',
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.bold,
                    color: alertColor,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  alert['message'] ?? '',
                  style: TextStyle(
                    fontSize: AppSizes.fontM,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  _formatAlertTime(alert['time']),
                  style: TextStyle(
                    fontSize: AppSizes.fontS,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== ANALYTICS TAB ==========
  Widget _buildAnalyticsTab(Map<String, dynamic> sensor) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line Charts
          Text(
            '7-Day Trends',
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: AppSizes.paddingM),
          
          _buildLineChart(
            'Soil Moisture (%)',
            sensor['soilMoistureHistory'] as List<double>,
            AppColors.green,
          ),
          SizedBox(height: AppSizes.paddingL),
          
          _buildLineChart(
            'Temperature (°C)',
            sensor['temperatureHistory'] as List<double>,
            Colors.red.shade400,
          ),
          SizedBox(height: AppSizes.paddingL),
          
          _buildLineChart(
            'Humidity (%)',
            sensor['humidityHistory'] as List<double>,
            Colors.blue.shade400,
          ),
          
          SizedBox(height: AppSizes.paddingXL),
          
          // Pie Chart - Nutrient Distribution
          Text(
            'Nutrient Distribution',
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: AppSizes.paddingM),
          
          _buildPieChart(sensor),
          
          SizedBox(height: AppSizes.paddingXL),
          
          // Health Score Gauge
          Text(
            'Crop Health Score',
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          SizedBox(height: AppSizes.paddingM),
          
          _buildHealthGauge(sensor),
        ],
      ),
    );
  }

  Widget _buildLineChart(String title, List<double> data, Color color) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    return Container(
      padding: EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          SizedBox(height: AppSizes.paddingM),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size(double.infinity, 120),
              painter: LineChartPainter(
                data: data,
                color: color,
                minValue: minValue,
                maxValue: maxValue,
              ),
            ),
          ),
          SizedBox(height: AppSizes.paddingS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((day) => Text(
              day,
              style: TextStyle(fontSize: 10, color: AppColors.textGrey),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(Map<String, dynamic> sensor) {
    final nitrogen = sensor['nitrogen'] as double;
    final phosphorus = sensor['phosphorus'] as double;
    final potassium = sensor['potassium'] as double;
    final total = nitrogen + phosphorus + potassium;

    return Container(
      padding: EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Pie chart
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: PieChartPainter(
                values: [nitrogen / total, phosphorus / total, potassium / total],
                colors: [Colors.green, Colors.orange, Colors.purple],
              ),
            ),
          ),
          SizedBox(width: AppSizes.paddingXL),
          // Legend
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendItem('Nitrogen', nitrogen, Colors.green),
                SizedBox(height: AppSizes.paddingM),
                _buildLegendItem('Phosphorus', phosphorus, Colors.orange),
                SizedBox(height: AppSizes.paddingM),
                _buildLegendItem('Potassium', potassium, Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, double value, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: 8),
        Text(
          '$label: ${value.toInt()}%',
          style: TextStyle(
            fontSize: AppSizes.fontM,
            color: AppColors.textDark,
          ),
        ),
      ],
    );
  }

  Widget _buildHealthGauge(Map<String, dynamic> sensor) {
    // Calculate health score based on various factors
    final soilMoisture = sensor['soilMoisture'] as double;
    final ph = sensor['soilPH'] as double;
    final nitrogen = sensor['nitrogen'] as double;
    
    // Simple health calculation
    double healthScore = 0;
    healthScore += (soilMoisture >= 50 && soilMoisture <= 80) ? 35 : 15;
    healthScore += (ph >= 6.0 && ph <= 7.5) ? 35 : 15;
    healthScore += (nitrogen >= 40) ? 30 : 15;

    final Color scoreColor = healthScore >= 80
        ? AppColors.green
        : (healthScore >= 60 ? Colors.orange : Colors.red);
    final String scoreLabel = healthScore >= 80
        ? 'Excellent'
        : (healthScore >= 60 ? 'Good' : 'Needs Attention');

    return Container(
      padding: EdgeInsets.all(AppSizes.paddingXL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scoreColor.withOpacity(0.1), scoreColor.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: 150,
            child: CustomPaint(
              painter: GaugePainter(
                score: healthScore / 100,
                color: scoreColor,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${healthScore.toInt()}',
                      style: TextStyle(
                        fontSize: AppSizes.fontTitle,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    Text(
                      scoreLabel,
                      style: TextStyle(
                        fontSize: AppSizes.fontS,
                        color: scoreColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppColors.textGrey.withOpacity(0.3)),
          SizedBox(height: AppSizes.paddingM),
          Text(
            title,
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
              color: AppColors.textGrey,
            ),
          ),
          SizedBox(height: AppSizes.paddingS),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: AppSizes.fontM,
              color: AppColors.textGrey.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime? time) {
    if (time == null) return 'Never';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatAlertTime(DateTime? time) {
    if (time == null) return '';
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes} minutes ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}

// ========== CUSTOM PAINTERS ==========

class LineChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double minValue;
  final double maxValue;

  LineChartPainter({
    required this.data,
    required this.color,
    required this.minValue,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.05)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    final range = maxValue - minValue;
    final xStep = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final y = size.height - ((data[i] - minValue) / range * size.height);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final y = size.height - ((data[i] - minValue) / range * size.height);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PieChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;

  PieChartPainter({required this.values, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    double startAngle = -math.pi / 2;

    for (int i = 0; i < values.length; i++) {
      final sweepAngle = values[i] * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Draw separator line
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      startAngle += sweepAngle;
    }

    // Draw center circle
    canvas.drawCircle(center, radius * 0.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GaugePainter extends CustomPainter {
  final double score;
  final Color color;

  GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    // Background arc
    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      bgPaint,
    );

    // Score arc
    final scorePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 15
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      math.pi * 0.75,
      math.pi * 1.5 * score,
      false,
      scorePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
