import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/core/utils/responsive_utils.dart';
import 'package:krishimantra/data/repositories/auth_repository.dart';
import 'package:krishimantra/data/services/SocketService.dart';
import 'package:krishimantra/data/services/UserService.dart';
import 'package:krishimantra/data/services/engagement_service.dart';
import 'package:krishimantra/data/services/push_notification_service.dart';
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

    if (userData == null) {
      Get.offAllNamed(AppRoutes.LANGUAGE_SELECTION);
      return;
    }

    // Validate the cached token against the backend. The Dio interceptor
    // transparently refreshes on 401, so a `false` here means the refresh
    // also failed (or the user is genuinely logged out). Forcing them to
    // log in again is better than landing on a screen where every API
    // call 401s silently.
    bool tokenOk = false;
    try {
      final auth = Get.isRegistered<AuthRepository>()
          ? Get.find<AuthRepository>()
          : null;
      if (auth != null) {
        tokenOk = await auth.validateToken();
      }
    } catch (_) {
      tokenOk = false;
    }

    if (!tokenOk) {
      // Stale or invalid session — clear local data and route to login.
      try {
        await _userService.clearAllData();
      } catch (_) {}
      Get.offAllNamed(AppRoutes.PHONE_NUMBER);
      return;
    }

    // Initialize engagement tracking for logged in user
    await EngagementService().init(userData.id);
    EngagementService().trackLogin();

    // Connect the socket *after* token validation. Doing it earlier (or in
    // SocketService's constructor) handshakes with whatever was cached and
    // either fails or burns reconnection attempts on a dead token before
    // login state stabilises.
    try {
      if (Get.isRegistered<SocketService>()) {
        unawaited(Get.find<SocketService>().start());
      }
    } catch (_) {}

    // Request notification permission + register the FCM token. Done here
    // (post-token-validation) because registering before login means we
    // have nowhere to attribute the token to. Permission denial is OK —
    // the user can still get in-app notifications via the websocket; this
    // only turns on OS-level banners.
    try {
      if (Get.isRegistered<PushNotificationService>()) {
        unawaited(Get.find<PushNotificationService>().start());
      }
    } catch (_) {}

    await AuthController.navigateAfterAuth();
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
              'assets/Images/krishimantra-logo.png',
              height: logoSize,
              width: logoSize,
            ),
            SizedBox(height: AppSizes.paddingXXL),
            Text(
              'Krishi Mantra',
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
