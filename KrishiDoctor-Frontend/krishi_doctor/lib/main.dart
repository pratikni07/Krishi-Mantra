import 'package:flutter/material.dart';
import 'package:krishi_doctor/Theme/theme_data.dart';
import 'package:krishi_doctor/Routes/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_config/flutter_config.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    print("Could not load .env file: $e");
  }
  await FlutterConfig.loadEnvVariables();
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Krishi Doctor',
      theme: ThemeClass.themeData,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter().generateRoute,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: snackbarKey,
    );
  }
}

