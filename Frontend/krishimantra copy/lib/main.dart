import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/routes/app_routes.dart';
import 'dependency_injection.dart';

void main() {
  initDependencies();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Krishi Mantra',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system, 
      initialRoute: AppRoutes.SPLASH,
      getPages: AppRoutes.routes,
      debugShowCheckedModeBanner: false,
    );
  }
}
