import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:krishimantra/data/repositories/ads_repository.dart';
import 'package:krishimantra/data/repositories/ai_chat_repository.dart';
import 'package:krishimantra/data/repositories/auth_repository.dart';
import 'package:krishimantra/data/repositories/feed_repository.dart';
import 'package:krishimantra/data/repositories/message_repository.dart';
import 'package:krishimantra/data/services/api_service.dart';
import 'package:krishimantra/data/services/SocketService.dart';
import 'package:krishimantra/presentation/controllers/ai_chat_controller.dart';
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
// Add imports for video tutorial
import 'package:krishimantra/data/repositories/video_tutorial_repository.dart';
import 'package:krishimantra/presentation/controllers/video_tutorial_controller.dart';

import 'data/repositories/company_repository.dart';
import 'data/repositories/product_repository.dart';
import 'data/repositories/scheme_repository.dart';
import 'data/services/LocationService.dart';
import 'presentation/controllers/company_controller.dart';
import 'presentation/controllers/product_controller.dart';
import 'presentation/controllers/scheme_controller.dart';
import 'presentation/screens/feed/widgets/feed_card.dart';

void initDependencies() {
  // Initialize Dio and ApiService first
  final dio = Dio();
  Get.put(ApiService(dio), permanent: true);

  // Initialize core services
  Get.put(UserService(), permanent: true);
  Get.put(SocketService(), permanent: true);

  // Initialize repositories
  Get.lazyPut(() => AuthRepository(Get.find<ApiService>()));
  Get.lazyPut(() => FeedRepository(Get.find<ApiService>()));
  Get.lazyPut(() => AdsRepository(Get.find<ApiService>()));
  Get.lazyPut(() => MessageRepository(Get.find<ApiService>()));
  Get.lazyPut(
      () => ReelRepository(Get.find<ApiService>(), Get.find<UserService>()));
  Get.put(CropRepository(Get.find<ApiService>()), permanent: true);
  Get.lazyPut(() => SchemeRepository(Get.find<ApiService>()));
  Get.put(CompanyRepository(Get.find<ApiService>()), permanent: true);
  Get.lazyPut(() => ProductRepository(Get.find<ApiService>()));
  Get.lazyPut(() => AIChatRepository(Get.find<ApiService>()));

  // Initialize controllers (move before VideoTutorialRepository)
  Get.lazyPut(() => AuthController(Get.find<AuthRepository>()));
  Get.lazyPut(() => FeedController(
        Get.find<FeedRepository>(),
        Get.find<UserService>(),
      ));
  Get.put(AdsController(Get.find<AdsRepository>()), permanent: true);
  Get.lazyPut(() => MessageController(
        Get.find<MessageRepository>(),
        Get.find<UserService>(),
      ));
  Get.lazyPut(() => ReelController(Get.find<ReelRepository>()));
  Get.put(CropController(Get.find<CropRepository>()), permanent: true);
  Get.lazyPut(() => SchemeController(Get.find<SchemeRepository>()));
  Get.put(CompanyController(Get.find<CompanyRepository>()), permanent: true);
  Get.lazyPut(() => ProductController(Get.find<ProductRepository>()));
  Get.lazyPut(() => AIChatController(
        Get.find<AIChatRepository>(),
        Get.find<UserService>(),
      ));

  // Add VideoTutorialRepository (after controllers have been initialized)
  Get.put(VideoTutorialRepository(Get.find<ApiService>()), permanent: true);

  // Add VideoTutorialController
  Get.put(
      VideoTutorialController(
        Get.find<VideoTutorialRepository>(),
        Get.find<UserService>(),
      ),
      permanent: true);

  // Location service
  Get.put(LocationService());

  // Add VideoController
  Get.put(VideoController(), permanent: true);
}
