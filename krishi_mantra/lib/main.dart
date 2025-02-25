import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:krishi_mantra/services/language_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/routes.dart';
import 'screens/loginScreen/Repository/login_repo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final languageService = await LanguageService.getInstance();

  runApp(MyApp(prefs: prefs, languageService: languageService));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;
  const MyApp(
      {super.key,
      required this.prefs,
      required LanguageService languageService});

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (context) => LoginRepo(prefs),
      child: MaterialApp(
        title: 'Krishi Mantra',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
          useMaterial3: true,
        ),
        initialRoute: Routes.splash,
        onGenerateRoute: Routes.generateRoute,
      ),
    );
  }
}
