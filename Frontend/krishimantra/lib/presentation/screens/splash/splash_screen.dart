import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/core/utils/responsive_utils.dart';
import 'package:krishimantra/data/services/UserService.dart';
import 'package:krishimantra/data/services/engagement_service.dart';
import 'package:krishimantra/presentation/controllers/auth_controller.dart';
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
    await Future.delayed(const Duration(seconds: 2));

    final userData = await _userService.getUser();

    if (userData != null) {
      // Initialize engagement tracking for logged in user
      await EngagementService().init(userData.id);
      EngagementService().trackLogin();
      await AuthController.navigateAfterAuth();
    } else {
      Get.offAllNamed(AppRoutes.LANGUAGE_SELECTION);
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    final logoSize = ResponsiveUtils.responsive(
      mobile: ResponsiveUtils.wp(45),
      tablet: ResponsiveUtils.wp(35),
    );

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/Images/Logo.png',
              height: logoSize,
              width: logoSize,
            ),
            SizedBox(height: AppSizes.paddingXXL),
            Text(
              'KrishiMantra',
              style: TextStyle(
                fontSize: AppSizes.fontHeading,
                fontWeight: FontWeight.bold,
                color: AppColors.green,
              ),
            ),
            SizedBox(height: ResponsiveUtils.hp(6)),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
            ),
          ],
        ),
      ),
    );
  }
}
