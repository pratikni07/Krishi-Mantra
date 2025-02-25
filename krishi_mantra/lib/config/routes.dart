import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:krishi_mantra/screens/ComingSoonFeaturesPage.dart';
import '../screens/LanguageSelectionPage.dart';
import '../screens/homeScreen/home_page.dart';
import '../screens/loginScreen/Repository/login_repo.dart';
import '../screens/loginScreen/bloc/login_bloc.dart';
import '../screens/loginScreen/login_page.dart';
import '../screens/splash_screen.dart';

class Routes {
  static const String splash = '/';
  static const String language = '/language';

  static const String home = '/home';
  static const String login = '/login';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => LoginBloc(context.read<LoginRepo>()),
            child: const SplashScreen(),
          ),
        );
      case language:
        return MaterialPageRoute(
            builder: (_) => const LanguageSelectionScreen());

      case home:
        return MaterialPageRoute(builder: (_) => const FarmerHomePage());
      // return MaterialPageRoute(builder: (_) => ComingSoonFeaturesPage());
      case login:
        return MaterialPageRoute(
          builder: (context) => BlocProvider(
            create: (context) => LoginBloc(context.read<LoginRepo>()),
            child: const LoginScreen(),
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
