// ignore_for_file: constant_identifier_names

import 'package:get/get.dart';
import 'package:krishimantra/presentation/screens/auth/LoginScreen.dart';
import 'package:krishimantra/presentation/screens/feed/create_post_screen.dart';
import 'package:krishimantra/presentation/screens/home/home_screen.dart';
import 'package:krishimantra/presentation/screens/main_screen.dart';
import 'package:krishimantra/presentation/screens/splash/splash_screen.dart';

class AppRoutes {
  static const String SPLASH = '/splash';
  static const String LOGIN = '/login';
  static const String HOME = '/home';
  static const String MAIN = '/main';
  static const String CREATE_POST = '/create-post';

  static final routes = [
    GetPage(name: SPLASH, page: () => SplashScreen()),
    GetPage(name: LOGIN, page: () => LoginScreen()),
    GetPage(name: MAIN, page: () => MainScreen()),
    GetPage(name: HOME, page: () => const HomeScreen()),
    GetPage(name: CREATE_POST, page: () => const CreatePostScreen()),
  ];
}
