// ignore_for_file: constant_identifier_names

import 'package:get/get.dart';
import 'package:krishimantra/presentation/screens/ai_chat/ai_chat_screen.dart';
import 'package:krishimantra/presentation/screens/auth/LoginScreen.dart';
import 'package:krishimantra/presentation/screens/company/allcompanyscreen.dart';
import 'package:krishimantra/presentation/screens/cropcalendar/Crops.dart';
import 'package:krishimantra/presentation/screens/cropcare/ChatListScreen.dart';
import 'package:krishimantra/presentation/screens/feed/create_post_screen.dart';
import 'package:krishimantra/presentation/screens/home/home_screen.dart';
import 'package:krishimantra/presentation/screens/main_screen.dart';
import 'package:krishimantra/presentation/screens/splash/splash_screen.dart';
import 'package:krishimantra/presentation/screens/video_tutorial/video_list_screen.dart';
import 'package:krishimantra/presentation/screens/language/LanguageSelectionPage.dart';
import 'package:krishimantra/presentation/screens/auth/phone_number_screen.dart';
import 'package:krishimantra/presentation/screens/auth/otp_verification_screen.dart';
import 'package:krishimantra/presentation/screens/auth/signup_screen.dart';

import '../presentation/screens/products/product_list_screen.dart';
import '../presentation/screens/schemes/gov_schemes_screen.dart';

class AppRoutes {
  static const String SPLASH = '/splash';
  static const String LOGIN = '/login';
  static const String HOME = '/home';
  static const String MAIN = '/main';
  static const String CREATE_POST = '/create-post';
  // New routes for services
  static const String CONSULTATION = '/consultation';
  static const String CROP_CALENDAR = '/crop-calendar';
  static const String COMPANIES = '/companies';
  static const String FERTILIZERS = '/fertilizers';
  static const String KRISHI_AI = '/krishi-ai';
  static const String KRISHI_VIDEOS = '/krishi-videos';
  static const String NEWS = '/news';
  static const String SCHEMES = '/schemes';

  // New authentication routes
  static const String LANGUAGE_SELECTION = '/language';
  static const String PHONE_NUMBER = '/phone';
  static const String OTP_VERIFICATION = '/otp';
  static const String SIGNUP = '/signup';

  static final routes = [
    GetPage(name: SPLASH, page: () => SplashScreen()),
    GetPage(name: LOGIN, page: () => LoginScreen()),
    GetPage(name: MAIN, page: () => MainScreen()),
    GetPage(name: HOME, page: () => const HomeScreen()),
    GetPage(name: CREATE_POST, page: () => const CreatePostScreen()),
    // Add your new pages here
    GetPage(name: CONSULTATION, page: () => ChatListScreen()),
    GetPage(name: CROP_CALENDAR, page: () => CropsScreen()),
    GetPage(name: COMPANIES, page: () => CompanyListScreen()),
    GetPage(name: FERTILIZERS, page: () => ProductListScreen()),
    GetPage(name: KRISHI_AI, page: () => AIChatScreen()),
    GetPage(name: KRISHI_VIDEOS, page: () => VideoListScreen()),
    // GetPage(name: NEWS, page: () => NewsScreen()),
    GetPage(name: SCHEMES, page: () => GovSchemesScreen()),

    // New authentication routes
    GetPage(
        name: LANGUAGE_SELECTION, page: () => const LanguageSelectionScreen()),
    GetPage(name: PHONE_NUMBER, page: () => const PhoneNumberScreen()),
    // Note: OTP and Signup screens need parameters, so they'll be navigated to using Get.to() directly
    // rather than using named routes
  ];
}
