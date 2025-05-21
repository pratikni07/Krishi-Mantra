import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dependency_injection.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  initDependencies();
  // Add this to suppress the hardware keyboard assertion errors
  FlutterError.onError = (details) {
    final exception = details.exception;
    if (exception is FlutterError &&
        exception.message.contains(
            'A KeyUpEvent is dispatched, but the state shows that the physical key is not pressed')) {
      return;
    }
    FlutterError.presentError(details);
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeService = Get.put(ThemeService());

    return GetMaterialApp(
      title: 'KrishiMantra',
      debugShowCheckedModeBanner: false,
      theme: ThemeService.lightTheme,
      darkTheme: ThemeService.darkTheme,
      themeMode: themeService.theme,
      home: const SplashScreen(),
      getPages: AppRoutes.routes,
    );
  }
}
