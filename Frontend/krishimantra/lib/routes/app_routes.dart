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
import 'package:krishimantra/presentation/screens/settings/settings_screen.dart';
// import 'package:krishimantra/presentation/screens/auth/otp_verification_screen.dart';
// import 'package:krishimantra/presentation/screens/auth/signup_screen.dart';

import '../presentation/screens/marketplace/marketplace_product_detail_screen.dart';
import '../presentation/screens/products/product_list_screen.dart';
import '../presentation/screens/schemes/gov_schemes_screen.dart';
import '../presentation/screens/marketplace/marketplace_screen.dart';

import '../presentation/screens/marketplace/add_product_screen.dart';
import '../presentation/screens/notification/notification_screen.dart';
import '../presentation/screens/subscription/subscription_plans_screen.dart';
import '../presentation/screens/subscription/payment_history_screen.dart';
import '../presentation/screens/iot/device_registration_screen.dart';
import '../presentation/screens/farm_measurement/farm_measurement_screen.dart';
import '../presentation/screens/disease_detection/disease_detection_screen.dart';
import '../presentation/screens/mandi/mandi_price_screen.dart';
import '../presentation/screens/onboarding/edit_farm_screen.dart';
import '../presentation/screens/onboarding/farm_onboarding_screen.dart';

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
  static const String SETTINGS = '/settings';

  // New authentication routes
  static const String LANGUAGE_SELECTION = '/language';
  static const String PHONE_NUMBER = '/phone';
  static const String OTP_VERIFICATION = '/otp';
  static const String SIGNUP = '/signup';

  // Add notification routes
  static const String NOTIFICATIONS = '/notifications';
  static const String NOTIFICATION_SETTINGS = '/notification-settings';

  // Add marketplace routes
  static const String MARKETPLACE = '/marketplace';
  static const String MARKETPLACE_DETAIL = '/marketplace-detail';
  static const String ADD_MARKETPLACE_PRODUCT = '/add-marketplace-product';

  // Subscription routes
  static const String SUBSCRIPTION_PLANS = '/subscription-plans';
  static const String PAYMENT_HISTORY = '/payment-history';

  // IoT Device Registration routes
  static const String DEVICE_REGISTRATION = '/device-registration';

  // Farm Measurement route
  static const String FARM_MEASUREMENT = '/farm-measurement';
  static const String DISEASE_DETECTION = '/disease-detection';
  static const String MANDI_PRICE = '/mandi-price';

  // Farm profile onboarding (krishi-ai)
  static const String FARM_ONBOARDING = '/farm-onboarding';
  static const String EDIT_FARM = '/edit-farm';

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
    GetPage(name: SETTINGS, page: () => const SettingsScreen()),
    GetPage(name: FARM_ONBOARDING, page: () => const FarmOnboardingScreen()),
    GetPage(name: EDIT_FARM, page: () => const EditFarmScreen()),

    // New authentication routes
    GetPage(
        name: LANGUAGE_SELECTION, page: () => const LanguageSelectionScreen()),
    GetPage(name: PHONE_NUMBER, page: () => const PhoneNumberScreen()),
    // Note: OTP and Signup screens need parameters, so they'll be navigated to using Get.to() directly
    // rather than using named routes

    // Notification route
    GetPage(name: NOTIFICATIONS, page: () => const NotificationScreen()),

    // Marketplace routes
    GetPage(name: MARKETPLACE, page: () => const MarketplaceScreen()),
    GetPage(
      name: MARKETPLACE_DETAIL,
      page: () =>
          MarketPlaceProductDetailScreen(productId: Get.arguments as String),
    ),
    GetPage(
        name: ADD_MARKETPLACE_PRODUCT, page: () => const AddProductScreen()),

    // IoT Device Registration route
    GetPage(
      name: DEVICE_REGISTRATION,
      page: () => DeviceRegistrationScreen(
        deviceType: Get.arguments as String,
      ),
    ),

    // Subscription routes
    GetPage(
        name: SUBSCRIPTION_PLANS, page: () => const SubscriptionPlansScreen()),
    GetPage(
        name: PAYMENT_HISTORY, page: () => const PaymentHistoryScreen()),

    // Farm Measurement route
    GetPage(
        name: FARM_MEASUREMENT, page: () => const FarmMeasurementScreen()),
    GetPage(
        name: DISEASE_DETECTION, page: () => const DiseaseDetectionScreen()),
    GetPage(
        name: MANDI_PRICE, page: () => const MandiPriceScreen()),
  ];
}
