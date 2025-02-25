import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:krishimantra/data/repositories/ads_repository.dart';
import 'package:krishimantra/data/repositories/auth_repository.dart';
import 'package:krishimantra/data/repositories/feed_repository.dart';
import 'package:krishimantra/data/repositories/message_repository.dart';
import 'package:krishimantra/data/services/api_service.dart';
import 'package:krishimantra/presentation/controllers/auth_controller.dart';
import 'package:krishimantra/presentation/controllers/feed_controller.dart';
import 'package:krishimantra/presentation/controllers/message_controller.dart';
import 'package:krishimantra/data/services/UserService.dart';
import 'package:krishimantra/data/repositories/reel_repository.dart';
import 'package:krishimantra/presentation/controllers/reel_controller.dart';
import 'package:krishimantra/presentation/controllers/ads_controller.dart';
// Add new imports for crop-related classes
import 'package:krishimantra/data/repositories/crop_repository.dart';
import 'package:krishimantra/presentation/controllers/crop_controller.dart';

import 'data/repositories/company_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/scheme_repository.dart';
import 'data/services/LocationService.dart';
import 'presentation/controllers/company_controller.dart';
import 'presentation/controllers/product_controller.dart';
import 'presentation/controllers/scheme_controller.dart';

void initDependencies() {
  final dio = Dio();
  final apiService = ApiService(dio);

  // Existing dependencies
  Get.lazyPut(() => AuthRepository(apiService));
  Get.lazyPut(() => AuthController(Get.find<AuthRepository>()));

  Get.lazyPut(() => FeedRepository(apiService));
  Get.lazyPut(() => UserService());
  Get.lazyPut(() =>
      FeedController(Get.find<FeedRepository>(), Get.find<UserService>()));

  Get.lazyPut(() => AdsRepository(apiService));
  Get.lazyPut(() => AdsController(Get.find<AdsRepository>()));

  Get.lazyPut(() => MessageRepository(apiService));
  Get.lazyPut(() => MessageController(
      Get.find<MessageRepository>(), Get.find<UserService>()));

  Get.lazyPut(() => ReelRepository(apiService, Get.find<UserService>()));
  Get.lazyPut(() => ReelController(Get.find<ReelRepository>()));

  // Add Crop dependencies
  Get.lazyPut(() => CropRepository(apiService));
  Get.lazyPut(() => CropController(Get.find<CropRepository>()));

  // In your dependency injection file
  Get.lazyPut(() => SchemeRepository(apiService));
  Get.lazyPut(() => SchemeController(Get.find<SchemeRepository>()));

  Get.put(LocationService());

  Get.lazyPut(() => CompanyRepository(apiService));
  Get.lazyPut(() => CompanyController(Get.find<CompanyRepository>()));

  Get.lazyPut(() => ProductRepository(apiService));
  Get.lazyPut(() => ProductController(Get.find<ProductRepository>()));

}
