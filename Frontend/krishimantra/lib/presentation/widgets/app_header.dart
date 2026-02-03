import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/colors.dart';
import '../../data/services/UserService.dart';
import '../../data/services/language_service.dart';
import '../controllers/notification_controller.dart';

class AppHeader extends StatefulWidget {
  const AppHeader({Key? key}) : super(key: key);

  @override
  _AppHeaderState createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  String username = "User"; // Default value
  String helloText = "Hello";
  String welcomeText = "Welcome";
  late LanguageService _languageService;

  @override
  void initState() {
    super.initState();
    _loadUsername();
    _initializeLanguage();
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('Hello'),
      _languageService.translate('Welcome'),
    ]);

    setState(() {
      helloText = translations[0];
      welcomeText = translations[1];
    });
  }

  Future<void> _loadUsername() async {
    String? fetchedUsername = await UserService().getFirstName();
    if (fetchedUsername != null) {
      setState(() {
        username = fetchedUsername;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(
              Icons.waving_hand,
              color: Color.fromARGB(255, 254, 229, 3),
              size: 28,
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  helloText,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '$welcomeText, $username',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        Row(
          children: [
            GestureDetector(
              onTap: () => Get.toNamed('/chat'),
              child: Icon(Icons.message_outlined, color: AppColors.white, size: 28),
            ),
            SizedBox(width: 19),
            GestureDetector(
              onTap: () => Get.toNamed('/notifications'),
              child: _buildNotificationIcon(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotificationIcon() {
    return GetBuilder<NotificationController>(
      init: Get.find<NotificationController>(),
      builder: (controller) {
        return Stack(
          children: [
            const Icon(
              Icons.notifications_outlined,
              color: AppColors.white,
              size: 28,
            ),
            if (controller.unreadCount.value > 0)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    controller.unreadCount.value > 99
                        ? '99+'
                        : controller.unreadCount.value.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
