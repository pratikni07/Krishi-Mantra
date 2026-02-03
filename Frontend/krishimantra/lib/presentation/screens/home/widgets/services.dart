import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/colors.dart';
import '../../../../data/services/language_service.dart';

class Services extends StatefulWidget {
  const Services({super.key});

  @override
  State<Services> createState() => _ServicesState();
}

class _ServicesState extends State<Services> {
  late LanguageService _languageService;

  // Translatable service names
  String consultationText = 'Consultation';
  String cropCalendarText = 'Crop Calendar';
  String companiesText = 'Companies';
  String fertilizersText = 'Fertilizers';
  String krishiAIText = 'Krishi AI';
  String krishiVideosText = 'Krishi Videos';
  String marketplaceText = 'Marketplace';
  String schemesText = 'Schemes';

  List<ServiceItem> get serviceItems => [
        ServiceItem('assets/Images/serviceImg/test1.png', consultationText,
            '/consultation'),
        ServiceItem('assets/Images/serviceImg/test2.png', cropCalendarText,
            '/crop-calendar'),
        ServiceItem(
            'assets/Images/serviceImg/test3.png', companiesText, '/companies'),
        ServiceItem('assets/Images/serviceImg/test4.png', fertilizersText,
            '/fertilizers'),
        ServiceItem(
            'assets/Images/serviceImg/test5.png', krishiAIText, '/krishi-ai'),
        ServiceItem('assets/Images/serviceImg/test6.png', krishiVideosText,
            '/krishi-videos'),
        ServiceItem('assets/Images/serviceImg/tractor.jpg', marketplaceText,
            '/marketplace'),
        ServiceItem(
            'assets/Images/serviceImg/test8.png', schemesText, '/schemes'),
      ];

  @override
  void initState() {
    super.initState();
    _initializeLanguage();
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('Consultation'),
      _languageService.translate('Crop Calendar'),
      _languageService.translate('Companies'),
      _languageService.translate('Fertilizers'),
      _languageService.translate('Krishi AI'),
      _languageService.translate('Krishi Videos'),
      _languageService.translate('Marketplace'),
      _languageService.translate('Schemes'),
    ]);

    setState(() {
      consultationText = translations[0];
      cropCalendarText = translations[1];
      companiesText = translations[2];
      fertilizersText = translations[3];
      krishiAIText = translations[4];
      krishiVideosText = translations[5];
      marketplaceText = translations[6];
      schemesText = translations[7];
    });
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
                  .sublist(0, 4)
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
                  .sublist(4)
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
              child: Image.asset(
                item.imagePath,
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
}

class ServiceItem {
  final String imagePath;
  final String label;
  final String route;

  ServiceItem(this.imagePath, this.label, this.route);
}
