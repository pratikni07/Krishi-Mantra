import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/services/language_service.dart';

/// Full pump control screen with on/off, timer, and usage graph
class PumpControlScreen extends StatefulWidget {
  final String? selectedPumpId;

  const PumpControlScreen({Key? key, this.selectedPumpId}) : super(key: key);

  @override
  State<PumpControlScreen> createState() => _PumpControlScreenState();
}

class _PumpControlScreenState extends State<PumpControlScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late LanguageService _languageService;
  
  // Static demo data - will be replaced with API data later
  late List<Map<String, dynamic>> pumps;
  int _selectedPumpIndex = 0;

  // Translations
  String myPumpsText = 'My Pumps';
  String controlText = 'Control';
  String scheduleText = 'Schedule';
  String usageText = 'Usage';
  String turnOnText = 'Turn On';
  String turnOffText = 'Turn Off';
  String addScheduleText = 'Add Schedule';
  String todayUsageText = "Today's Usage";
  String weeklyUsageText = 'Weekly Usage';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializePumps();
    _initializeLanguage();
  }

  void _initializePumps() {
    pumps = [
      {
        'id': 'pump_1',
        'name': 'Main Farm Pump',
        'location': 'Field A',
        'isOn': true,
        'lastActivity': DateTime.now().subtract(const Duration(minutes: 30)),
        'waterFlow': 45.5,
        'todayUsage': 1250.0, // liters
        'schedules': [
          {'startTime': '06:00', 'endTime': '08:00', 'enabled': true},
          {'startTime': '18:00', 'endTime': '19:30', 'enabled': true},
        ],
        'weeklyData': [320.0, 450.0, 380.0, 520.0, 480.0, 410.0, 350.0], // last 7 days in liters
      },
      {
        'id': 'pump_2',
        'name': 'Garden Pump',
        'location': 'Backyard',
        'isOn': false,
        'lastActivity': DateTime.now().subtract(const Duration(hours: 2)),
        'waterFlow': 0.0,
        'todayUsage': 280.0,
        'schedules': [
          {'startTime': '07:00', 'endTime': '07:30', 'enabled': false},
        ],
        'weeklyData': [150.0, 180.0, 200.0, 170.0, 160.0, 190.0, 140.0],
      },
    ];

    // Find selected pump if provided
    if (widget.selectedPumpId != null) {
      final index = pumps.indexWhere((p) => p['id'] == widget.selectedPumpId);
      if (index >= 0) {
        _selectedPumpIndex = index;
      }
    }
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('My Pumps'),
      _languageService.translate('Control'),
      _languageService.translate('Schedule'),
      _languageService.translate('Usage'),
      _languageService.translate('Turn On'),
      _languageService.translate('Turn Off'),
      _languageService.translate('Add Schedule'),
      _languageService.translate("Today's Usage"),
      _languageService.translate('Weekly Usage'),
    ]);

    if (mounted) {
      setState(() {
        myPumpsText = translations[0];
        controlText = translations[1];
        scheduleText = translations[2];
        usageText = translations[3];
        turnOnText = translations[4];
        turnOffText = translations[5];
        addScheduleText = translations[6];
        todayUsageText = translations[7];
        weeklyUsageText = translations[8];
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
    final currentPump = pumps[_selectedPumpIndex];
    final bool isOn = currentPump['isOn'] ?? false;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(
          myPumpsText,
          style: TextStyle(
            color: Colors.white,
            fontSize: AppSizes.fontXL,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(pumps.length > 1 ? 120 : 60),
          child: Column(
            children: [
              // Pump selector if multiple pumps
              if (pumps.length > 1)
                Container(
                  height: 60,
                  padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: pumps.length,
                    itemBuilder: (context, index) {
                      final pump = pumps[index];
                      final isSelected = index == _selectedPumpIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPumpIndex = index;
                          });
                        },
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
                              Icon(
                                Icons.water_drop,
                                color: isSelected ? AppColors.green : Colors.white,
                                size: AppSizes.iconS,
                              ),
                              SizedBox(width: AppSizes.paddingXS),
                              Text(
                                pump['name'],
                                style: TextStyle(
                                  color: isSelected ? AppColors.green : Colors.white,
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
                  Tab(text: controlText),
                  Tab(text: scheduleText),
                  Tab(text: usageText),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildControlTab(currentPump, isOn),
          _buildScheduleTab(currentPump),
          _buildUsageTab(currentPump),
        ],
      ),
    );
  }

  Widget _buildControlTab(Map<String, dynamic> pump, bool isOn) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        children: [
          SizedBox(height: AppSizes.paddingXL),
          
          // Big power button
          GestureDetector(
            onTap: () {
              setState(() {
                pumps[_selectedPumpIndex]['isOn'] = !isOn;
              });
              // TODO: Call API to toggle pump
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: ResponsiveUtils.wp(50),
              height: ResponsiveUtils.wp(50),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: isOn
                      ? [AppColors.green.withOpacity(0.3), AppColors.green]
                      : [Colors.grey.shade300, Colors.grey.shade500],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isOn ? AppColors.green : Colors.grey).withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.power_settings_new,
                    size: ResponsiveUtils.wp(15),
                    color: Colors.white,
                  ),
                  SizedBox(height: AppSizes.paddingS),
                  Text(
                    isOn ? 'ON' : 'OFF',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppSizes.fontXL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: AppSizes.paddingXXL),
          
          // Status info cards
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.location_on,
                  label: 'Location',
                  value: pump['location'] ?? 'N/A',
                ),
              ),
              SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.water,
                  label: 'Flow Rate',
                  value: isOn ? '${pump['waterFlow']}L/min' : '0L/min',
                ),
              ),
            ],
          ),
          
          SizedBox(height: AppSizes.paddingM),
          
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.water_drop_outlined,
                  label: todayUsageText,
                  value: '${pump['todayUsage']}L',
                ),
              ),
              SizedBox(width: AppSizes.paddingM),
              Expanded(
                child: _buildInfoCard(
                  icon: Icons.access_time,
                  label: 'Last Activity',
                  value: _formatLastActivity(pump['lastActivity']),
                ),
              ),
            ],
          ),
          
          SizedBox(height: AppSizes.paddingXL),
          
          // Quick toggle button
          SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  pumps[_selectedPumpIndex]['isOn'] = !isOn;
                });
              },
              icon: Icon(isOn ? Icons.stop : Icons.play_arrow),
              label: Text(isOn ? turnOffText : turnOnText),
              style: ElevatedButton.styleFrom(
                backgroundColor: isOn ? Colors.red : AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: AppColors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.green, size: AppSizes.iconS),
              SizedBox(width: AppSizes.paddingXS),
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: AppSizes.fontS,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.paddingS),
          Text(
            value,
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: AppSizes.fontL,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTab(Map<String, dynamic> pump) {
    final schedules = pump['schedules'] as List;

    return Column(
      children: [
        Expanded(
          child: schedules.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 80,
                        color: AppColors.textGrey.withOpacity(0.3),
                      ),
                      SizedBox(height: AppSizes.paddingM),
                      Text(
                        'No schedules set',
                        style: TextStyle(
                          color: AppColors.textGrey,
                          fontSize: AppSizes.fontL,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(AppSizes.paddingL),
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    return _buildScheduleCard(schedule, index);
                  },
                ),
        ),
        
        // Add schedule button
        Container(
          padding: EdgeInsets.all(AppSizes.paddingL),
          child: SizedBox(
            width: double.infinity,
            height: AppSizes.buttonHeight,
            child: ElevatedButton.icon(
              onPressed: () => _showAddScheduleDialog(),
              icon: const Icon(Icons.add),
              label: Text(addScheduleText),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule, int index) {
    final bool enabled = schedule['enabled'] ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: AppSizes.paddingM),
      padding: EdgeInsets.all(AppSizes.paddingL),
      decoration: BoxDecoration(
        color: enabled ? AppColors.green.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(
          color: enabled ? AppColors.green : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          // Time display
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${schedule['startTime']} - ${schedule['endTime']}',
                  style: TextStyle(
                    fontSize: AppSizes.fontXL,
                    fontWeight: FontWeight.bold,
                    color: enabled ? AppColors.textDark : AppColors.textGrey,
                  ),
                ),
                SizedBox(height: AppSizes.paddingXS),
                Text(
                  'Daily',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontSize: AppSizes.fontS,
                  ),
                ),
              ],
            ),
          ),
          
          // Toggle switch
          Switch(
            value: enabled,
            onChanged: (value) {
              setState(() {
                pumps[_selectedPumpIndex]['schedules'][index]['enabled'] = value;
              });
            },
            activeColor: AppColors.green,
          ),
          
          // Delete button
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red.shade300),
            onPressed: () {
              setState(() {
                (pumps[_selectedPumpIndex]['schedules'] as List).removeAt(index);
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUsageTab(Map<String, dynamic> pump) {
    final weeklyData = pump['weeklyData'] as List<double>;
    final maxValue = weeklyData.reduce((a, b) => a > b ? a : b);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today's usage card
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSizes.paddingXL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.green, AppColors.green.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(AppSizes.radiusXL),
            ),
            child: Column(
              children: [
                Text(
                  todayUsageText,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: AppSizes.fontL,
                  ),
                ),
                SizedBox(height: AppSizes.paddingS),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${pump['todayUsage']}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: AppSizes.fontTitle * 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        ' Liters',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: AppSizes.fontL,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          SizedBox(height: AppSizes.paddingXL),
          
          // Weekly usage chart
          Text(
            weeklyUsageText,
            style: TextStyle(
              fontSize: AppSizes.fontXL,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          
          SizedBox(height: AppSizes.paddingL),
          
          // Simple bar chart
          Container(
            height: 200,
            padding: EdgeInsets.all(AppSizes.paddingM),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                final value = weeklyData[index];
                final heightPercent = maxValue > 0 ? value / maxValue : 0.0;
                
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${value.toInt()}L',
                      style: TextStyle(
                        fontSize: AppSizes.fontXS,
                        color: AppColors.textGrey,
                      ),
                    ),
                    SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      width: 30,
                      height: 120 * heightPercent,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppColors.green,
                            AppColors.green.withOpacity(0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppSizes.radiusS),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      days[index],
                      style: TextStyle(
                        fontSize: AppSizes.fontS,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
          
          SizedBox(height: AppSizes.paddingXL),
          
          // Weekly total
          Container(
            padding: EdgeInsets.all(AppSizes.paddingL),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Weekly Total',
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    color: AppColors.textDark,
                  ),
                ),
                Text(
                  '${weeklyData.reduce((a, b) => a + b).toInt()} Liters',
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.bold,
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddScheduleDialog() {
    TimeOfDay startTime = const TimeOfDay(hour: 6, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 8, minute: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(addScheduleText),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Start Time'),
                trailing: Text(startTime.format(context)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: startTime,
                  );
                  if (picked != null) {
                    setDialogState(() {
                      startTime = picked;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time_filled),
                title: const Text('End Time'),
                trailing: Text(endTime.format(context)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: endTime,
                  );
                  if (picked != null) {
                    setDialogState(() {
                      endTime = picked;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  (pumps[_selectedPumpIndex]['schedules'] as List).add({
                    'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
                    'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
                    'enabled': true,
                  });
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastActivity(DateTime? lastActivity) {
    if (lastActivity == null) return 'N/A';
    final diff = DateTime.now().difference(lastActivity);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }
}
