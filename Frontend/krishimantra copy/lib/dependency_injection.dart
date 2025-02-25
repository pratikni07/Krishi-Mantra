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

import 'data/services/UserService.dart';

void initDependencies() {
  final dio = Dio();
  final apiService = ApiService(dio);

  Get.lazyPut(() => AuthRepository(apiService));
  Get.lazyPut(() => AuthController(Get.find<AuthRepository>()));

  Get.lazyPut(() => FeedRepository(apiService));
  Get.lazyPut(() => UserService());
  Get.lazyPut(() =>
      FeedController(Get.find<FeedRepository>(), Get.find<UserService>()));

  Get.lazyPut(() => AdsRepository(apiService));
  Get.lazyPut(() => MessageRepository(apiService));

  // Register MessageController
  Get.lazyPut(() => MessageController(
      Get.find<MessageRepository>(), Get.find<UserService>()));
}
