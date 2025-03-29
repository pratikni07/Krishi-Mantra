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
import 'package:krishimantra/data/repositories/presigned_url_repository.dart';
import 'package:krishimantra/presentation/controllers/presigned_url_controller.dart';
// Add new imports for marketplace
import 'package:krishimantra/data/repositories/marketplace_repository.dart';
import 'package:krishimantra/presentation/controllers/marketplace_controller.dart';

void initDependencies() {
  // Initialize Dio and ApiService first
  final dio = Dio();
  Get.put(ApiService(dio), permanent: true);

  // Initialize core services with permanent: true
  Get.put(UserService(), permanent: true);
  Get.put(SocketService(), permanent: true);
  Get.put(LocationService(), permanent: true);

  // Initialize repositories with fenix: true
  Get.lazyPut(() => AuthRepository(Get.find<ApiService>()), fenix: true);
  Get.lazyPut(() => FeedRepository(Get.find<ApiService>()), fenix: true);
  Get.lazyPut(() => AdsRepository(Get.find<ApiService>()), fenix: true);
  Get.lazyPut(() => MessageRepository(Get.find<ApiService>()), fenix: true);
  Get.lazyPut(
      () => ReelRepository(Get.find<ApiService>(), Get.find<UserService>()),
      fenix: true);
  Get.lazyPut(() => VideoTutorialRepository(Get.find<ApiService>()),
      fenix: true);
  Get.lazyPut(() => SchemeRepository(Get.find<ApiService>()), fenix: true);
  Get.lazyPut(() => CompanyRepository(Get.find<ApiService>()), fenix: true);
  Get.lazyPut(() => ProductRepository(Get.find<ApiService>()), fenix: true);
  Get.lazyPut(() => AIChatRepository(Get.find<ApiService>()), fenix: true);
  Get.lazyPut(() => PresignedUrlRepository(Get.find<ApiService>()),
      fenix: true);
  Get.lazyPut(() => CropRepository(Get.find<ApiService>()), fenix: true);
  // Add marketplace repository
  Get.lazyPut(() => MarketplaceRepository(Get.find<ApiService>()), fenix: true);

  // Initialize controllers with fenix: true
  Get.lazyPut(
    () => AuthController(Get.find<AuthRepository>()),
    fenix: true,
  );

  Get.lazyPut(
    () => FeedController(
      Get.find<FeedRepository>(),
      Get.find<UserService>(),
    ),
    fenix: true,
  );

  Get.lazyPut(
    () => AdsController(Get.find<AdsRepository>()),
    fenix: true,
  );

  Get.lazyPut(
    () => MessageController(
      Get.find<MessageRepository>(),
      Get.find<UserService>(),
    ),
    fenix: true,
  );

  Get.lazyPut(
    () => ReelController(Get.find<ReelRepository>()),
    fenix: true,
  );

  Get.lazyPut(
    () => VideoTutorialController(
      Get.find<VideoTutorialRepository>(),
      Get.find<UserService>(),
    ),
    fenix: true,
  );

  Get.lazyPut(
    () => SchemeController(Get.find<SchemeRepository>()),
    fenix: true,
  );

  Get.lazyPut(
    () => CompanyController(Get.find<CompanyRepository>()),
    fenix: true,
  );

  Get.lazyPut(
    () => ProductController(Get.find<ProductRepository>()),
    fenix: true,
  );

  Get.lazyPut(
    () => AIChatController(
      Get.find<AIChatRepository>(),
      Get.find<UserService>(),
    ),
    fenix: true,
  );

  Get.lazyPut(
    () => PresignedUrlController(Get.find<PresignedUrlRepository>()),
    fenix: true,
  );

  Get.lazyPut(
    () => CropController(Get.find<CropRepository>()),
    fenix: true,
  );

  // Add marketplace controller
  Get.lazyPut(
    () => MarketplaceController(
      Get.find<MarketplaceRepository>(),
      Get.find<UserService>(),
    ),
    fenix: true,
  );

  // Initialize VideoController
  Get.put(VideoController(), permanent: true);
}
