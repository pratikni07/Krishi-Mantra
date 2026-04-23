import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/home_localizations.dart';
import '../../../../core/utils/translation_manager.dart';
import '../../../../data/services/language_service.dart';

class Services extends StatefulWidget {
  const Services({super.key});

  @override
  State<Services> createState() => _ServicesState();
}

class _ServicesState extends State<Services> {
  String _languageCode = '';

  List<ServiceItem> get serviceItems => [
        ServiceItem('assets/Images/serviceImg/test2.png', _t('crop_calendar'),
            '/crop-calendar'),
        ServiceItem('assets/Images/serviceImg/test3.png', _t('companies'),
            '/companies'),
        ServiceItem('assets/Images/serviceImg/test4.png', _t('fertilizers'),
            '/fertilizers'),
        ServiceItem('assets/Images/serviceImg/test5.png', _t('krishi_ai'),
            '/krishi-ai'),
        ServiceItem('assets/Images/serviceImg/test6.png', _t('krishi_videos'),
            '/krishi-videos'),
        ServiceItem('assets/Images/serviceImg/tractor.jpg', _t('marketplace'),
            '/marketplace'),
        ServiceItem('assets/Images/serviceImg/test8.png', _t('schemes'),
            '/schemes'),
        ServiceItem(null, _t('measure_farm'),
            '/farm-measurement', icon: Icons.satellite_alt),
        ServiceItem(null, _t('dd_title'),
            '/disease-detection', icon: Icons.health_and_safety_outlined),
        ServiceItem(null, _t('mandi_title'),
            '/mandi-price', icon: Icons.currency_rupee),
      ];

  @override
  void initState() {
    super.initState();
    _syncLanguageCode();
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
  }

  Future<void> _syncLanguageCode() async {
    final languageService = await LanguageService.getInstance();
    if (!mounted) return;
    setState(() {
      _languageCode = languageService.getLanguageCode();
    });
  }

  Future<void> _onLanguageChanged() async {
    await _syncLanguageCode();
  }

  String _t(String key) {
    if (_languageCode.isEmpty) {
      return '';
    }
    return HomeLocalizations.text(key, _languageCode);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive calculations
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final isLargeScreen = screenWidth >= 400;

    // Dynamic padding based on screen size
    final horizontalPadding = screenWidth * 0.02;
    final verticalPadding = screenHeight * 0.015;

    // Dynamic item height based on screen height
    final itemHeight = screenHeight * 0.13;
    final rowSpacing = screenHeight * 0.01;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.green,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding.clamp(6.0, 12.0),
          vertical: verticalPadding.clamp(10.0, 18.0),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: serviceItems
                  .sublist(0, 5)
                  .map((item) => Expanded(
                        child: SizedBox(
                          height: itemHeight.clamp(90.0, 130.0),
                          child: _buildServiceItem(context, item),
                        ),
                      ))
                  .toList(),
            ),
            SizedBox(height: rowSpacing.clamp(6.0, 14.0)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: serviceItems
                  .sublist(5)
                  .map((item) => Expanded(
                        child: SizedBox(
                          height: itemHeight.clamp(90.0, 130.0),
                          child: _buildServiceItem(context, item),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(BuildContext context, ServiceItem item) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive icon size - scales with screen width
    final iconSize = (screenWidth * 0.15).clamp(50.0, 75.0);

    // Responsive font size
    final fontSize = (screenWidth * 0.03).clamp(10.0, 14.0);

    // Responsive spacing
    final spacing = (screenHeight * 0.008).clamp(4.0, 10.0);

    // Responsive text height
    final textHeight = (screenHeight * 0.045).clamp(30.0, 45.0);

    // Responsive error icon size
    final errorIconSize = (iconSize * 0.45).clamp(20.0, 35.0);

    return GestureDetector(
      onTap: () {
        Get.toNamed(item.route);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[200],
              border: Border.all(
                color: AppColors.green,
                width: 2,
              ),
            ),
            child: ClipOval(
              child: item.imagePath != null
                  ? Image.asset(
                      item.imagePath!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: Icon(
                            Icons.image,
                            size: errorIconSize,
                            color: Colors.grey[600],
                          ),
                        );
                      },
                    )
                  : Container(
                      color: AppColors.green.withOpacity(0.1),
                      child: Icon(
                        item.icon ?? Icons.category_outlined,
                        size: errorIconSize,
                        color: AppColors.green,
                      ),
                    ),
            ),
          ),
          SizedBox(height: spacing),
          SizedBox(
            height: textHeight,
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    TranslationManager.instance
        .removeLanguageChangeListener(_onLanguageChanged);
    super.dispose();
  }
}

class ServiceItem {
  final String? imagePath;
  final String label;
  final String route;
  final IconData? icon;

  ServiceItem(this.imagePath, this.label, this.route, {this.icon});
}
