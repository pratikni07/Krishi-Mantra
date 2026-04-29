import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/config/app_config.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/engagement_observer.dart';
import 'data/services/engagement_service.dart';
import 'data/services/push_notification_service.dart';
import 'dependency_injection.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'routes/app_routes.dart';
import 'core/theme/app_theme.dart';

/// Global error observer for unhandled errors
class GlobalErrorObserver {
  static void observe() {
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      final exception = details.exception;
      // Ignore harmless hardware keyboard errors
      if (exception is FlutterError &&
          exception.message.contains(
              'A KeyUpEvent is dispatched, but the state shows that the physical key is not pressed')) {
        return;
      }
      // Log all other errors
      logger.e(
        'Flutter error: ${details.exception}',
        tag: 'FlutterError',
        error: details.exception,
        stackTrace: details.stack,
      );
      // Forward to original error handler
      FlutterError.presentError(details);
    };

    // Catch errors not caught by Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      logger.e(
        'Platform dispatcher error: $error',
        tag: 'PlatformError',
        error: error,
        stackTrace: stack,
      );
      return true;
    };
  }
}

/// Connectivity monitor service
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivity = Connectivity();
  final _controller = StreamController<ConnectivityResult>.broadcast();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  Stream<ConnectivityResult> get connectivityStream => _controller.stream;

  void initialize() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((result) {
      _controller.add(result);
      logger.d('Connectivity changed: $result', tag: 'Connectivity');
    });
  }

  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _controller.close();
  }
}

void main() {
  // Ensure proper Flutter initialization
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize app configuration based on build mode
    if (kDebugMode) {
      AppConfig.initialize(Environment.development);
    } else if (kProfileMode) {
      AppConfig.initialize(Environment.staging);
    } else {
      AppConfig.initialize(Environment.production);
    }

    // Initialize logger
    AppLogger.instance.initialize();
    logger.i('App starting in ${AppConfig.instance.environment.name} mode', tag: 'App');

    // Initialize error observation
    GlobalErrorObserver.observe();

    // Initialize local storage
    await GetStorage.init();

    // Initialize connectivity monitoring
    ConnectivityService().initialize();

    // Initialize dependencies
    try {
      await initDependencies();
      logger.i('Dependencies initialized successfully', tag: 'App');
    } catch (e, stack) {
      logger.e(
        'Failed to initialize dependencies',
        tag: 'App',
        error: e,
        stackTrace: stack,
      );
      // Continue with app startup even if some dependencies fail
      // Critical dependencies should be checked in the splash screen
    }

    // Initialise the FCM SDK + register the background handler before
    // any push can land. Permission and token registration happen later
    // in the post-auth path (splash) where we know who the token belongs
    // to. If Firebase isn't configured (no google-services.json /
    // GoogleService-Info.plist), this throws and we log + continue —
    // push is degraded but the rest of the app still works.
    try {
      final pushService = PushNotificationService();
      Get.put<PushNotificationService>(pushService, permanent: true);
      await pushService.initialiseSdk();
      logger.i('FCM SDK initialised', tag: 'Push');
    } catch (e, stack) {
      logger.w(
        'FCM SDK initialisation failed; push disabled.',
        tag: 'Push',
        error: e,
        stackTrace: stack,
      );
    }

    runApp(const MyApp());
  }, (error, stack) {
    // Handle uncaught async errors
    logger.e(
      'Uncaught error',
      tag: 'App',
      error: error,
      stackTrace: stack,
    );
  });
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final EngagementLifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = EngagementLifecycleObserver();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    EngagementService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Get.put(ThemeService());

    return GetMaterialApp(
      title: 'Krishi Mantra',
      debugShowCheckedModeBanner: false,
      theme: ThemeService.lightTheme,
      darkTheme: ThemeService.darkTheme,
      themeMode: themeService.theme,
      home: const SplashScreen(),
      getPages: AppRoutes.routes,
      defaultTransition: Transition.fade,
      navigatorObservers: [EngagementNavigatorObserver()],
      builder: (context, child) {
        return MediaQuery(
          // Prevent font scaling beyond reasonable limits for accessibility
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaler.scale(1.0).clamp(0.8, 1.4),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
