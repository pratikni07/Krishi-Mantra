import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../controllers/auth_controller.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthController _authController = Get.find<AuthController>();

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await Future.delayed(Duration(seconds: 2)); // Splash screen duration
    await _authController.checkAuthStatus();
  }

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate responsive image width (40% of screen width)
    final imageWidth = screenWidth * 0.4;

    return Scaffold(
      backgroundColor: const Color(0xFF379570), // Converting hex to Color
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: screenHeight * 0.1),

            Image.asset(
              'assets/Images/Logo.png',
              width: imageWidth,
              height: imageWidth,
              fit: BoxFit.contain,
            ),

            SizedBox(height: 20),

            // Kissan Kart text
            Text(
              'Krishi Mantra',
              style: TextStyle(
                fontSize: screenWidth * 0.06, // Responsive font size
                fontWeight: FontWeight.bold,
                color: Colors.white, // Adding white color for better contrast
              ),
            ),

            SizedBox(height: 30),

            // Progress indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
