import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/data/services/UserService.dart';
import 'package:krishimantra/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final UserService _userService = Get.find<UserService>();

  @override
  void initState() {
    super.initState();

    _checkInitialConfig();
  }

  Future<void> _checkInitialConfig() async {
    // Wait for animations/initial loading (2 seconds)
    await Future.delayed(const Duration(seconds: 2));

    // Check user authentication status
    final userData = await _userService.getUser();

    if (userData != null) {
      // User is already logged in, go to main screen
      Get.offAllNamed(AppRoutes.MAIN);
    } else {
      // User needs to login, first select language
      Get.offAllNamed(AppRoutes.LANGUAGE_SELECTION);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo
            Image.asset(
              'assets/Images/Logo.png',
              height: 200,
              width: 200,
            ),
            const SizedBox(height: 30),
            // App name
            Text(
              'KrishiMantra',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.green,
              ),
            ),
            const SizedBox(height: 50),
            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ],
        ),
      ),
    );
  }
}
