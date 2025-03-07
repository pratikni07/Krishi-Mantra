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
  String newsText = 'News';
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
        ServiceItem('assets/Images/serviceImg/test7.png', newsText, '/news'),
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
      _languageService.translate('News'),
      _languageService.translate('Schemes'),
    ]);

    setState(() {
      consultationText = translations[0];
      cropCalendarText = translations[1];
      companiesText = translations[2];
      fertilizersText = translations[3];
      krishiAIText = translations[4];
      krishiVideosText = translations[5];
      newsText = translations[6];
      schemesText = translations[7];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppColors.green,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: serviceItems
                  .sublist(0, 4)
                  .map((item) => SizedBox(
                        width: 85,
                        height: 110,
                        child: _buildServiceItem(context, item),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: serviceItems
                  .sublist(4)
                  .map((item) => SizedBox(
                        width: 85,
                        height: 110,
                        child: _buildServiceItem(context, item),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(BuildContext context, ServiceItem item) {
    return GestureDetector(
      onTap: () {
        Get.toNamed(item.route);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 65,
            height: 65,
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
                      size: 30,
                      color: Colors.grey[600],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 35,
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
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
