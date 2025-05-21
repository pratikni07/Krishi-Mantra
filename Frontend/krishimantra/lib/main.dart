import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'dependency_injection.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'presentation/widgets/offline_indicator.dart';
import 'presentation/controllers/connectivity_controller.dart';

// Global error observer for unhandled errors
class GlobalErrorObserver {
  static void observe() {
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      final exception = details.exception;
      // Ignore harmless hardware keyboard errors
      if (exception is FlutterError &&
          exception.message.contains(
              'A KeyUpEvent is dispatched, but the state shows that the physical key is not pressed')) {
        // Ignore this specific hardware keyboard error
        return;
      }
      // Log all other errors
      _logError('Flutter error', details.exception, details.stack);
      // Forward to original error handler
      FlutterError.presentError(details);
    };

    // Catch errors not caught by Flutter framework
    PlatformDispatcher.instance.onError = (error, stack) {
      _logError('Platform dispatcher error', error, stack);
      return true;
    };
  }

  static void _logError(String source, dynamic error, StackTrace? stack) {
    // In production, you would want to send this to a logging service
    if (kDebugMode) {
      print('Error from $source: $error');
      if (stack != null) {
        print('Stack trace: $stack');
      }
    }
  }
}

// Connectivity monitor
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivity = Connectivity();
  final _controller = StreamController<ConnectivityResult>.broadcast();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  Stream<ConnectivityResult> get connectivityStream => _controller.stream;

  void initialize() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((result) {
      _controller.add(result);
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

    // Initialize error observation
    GlobalErrorObserver.observe();

    // Initialize local storage
    await GetStorage.init();

    // Initialize connectivity monitoring
    ConnectivityService().initialize();

    // Initialize dependencies
    try {
      await initDependencies();
    } catch (e, stack) {
      if (kDebugMode) {
        print('Failed to initialize dependencies: $e');
        print('Stack trace: $stack');
      }
      // Continue with app startup even if some dependencies fail
      // Critical dependencies should be checked in the splash screen
    }

    runApp(const MyApp());
  }, (error, stack) {
    // Handle uncaught async errors
    if (kDebugMode) {
      print('Uncaught error: $error');
      print('Stack trace: $stack');
    }
  });
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
      defaultTransition: Transition.fade,
      // Add global error handling
      navigatorObservers: [
        // You could add custom navigation observers here
      ],
      // Add builder to handle global app-level UI needs like offline indicators
      builder: (context, child) {
        return MediaQuery(
          // Prevent font scaling beyond reasonable limits for accessibility
          data: MediaQuery.of(context).copyWith(
            textScaleFactor:
                MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.4),
          ),
          child: Column(
            children: [
              // Add offline indicator at the top of every screen
              const OfflineIndicator(),
              // Main content expands to fill remaining space
              Expanded(child: child!),
            ],
          ),
        );
      },
    );
  }
}
