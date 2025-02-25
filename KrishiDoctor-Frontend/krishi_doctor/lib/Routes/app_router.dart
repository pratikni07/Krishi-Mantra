import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:krishi_doctor/Login/FarmerLoginScreen.dart';
import 'package:krishi_doctor/Login/Repository/login_repo.dart';
import 'package:krishi_doctor/Login/login_screen.dart';
import 'package:krishi_doctor/Pages/Screens/ChatScreen.dart';
import 'package:krishi_doctor/Pages/Screens/CropCalendarPage.dart';
import 'package:krishi_doctor/Pages/Screens/CropSelectionPage.dart';
import 'package:krishi_doctor/Pages/Screens/FarmerEventsPage.dart';
import 'package:krishi_doctor/Pages/Screens/FarmerProfilePage.dart';
import 'package:krishi_doctor/Pages/Screens/FeedScreen.dart';
import 'package:krishi_doctor/Pages/Screens/HomePage.dart';
import 'package:krishi_doctor/Pages/Screens/LanguageSelectionPage.dart';
import 'package:krishi_doctor/Pages/Screens/MarketPriceScreen.dart';
import 'package:krishi_doctor/Pages/Screens/NewsPage.dart';
import 'package:krishi_doctor/Pages/Screens/ReelPage.dart';
import 'package:krishi_doctor/Pages/Screens/WeatherScreen.dart';
import 'package:krishi_doctor/Pages/Screens/company_details_screen.dart';
import 'package:krishi_doctor/Pages/Screens/company_list_screen.dart';
import 'package:krishi_doctor/Pages/Screens/product_details_screen.dart';
import '../Login/bloc/login_bloc.dart';
import '../Splash/Repository/splashRepo.dart';
import '../Splash/bloc/splash_bloc.dart';
import '../Splash/splash_screen.dart';
class AppRouter{
  Route generateRoute(RouteSettings settings){
    switch(settings.name){
      case '/':
        return MaterialPageRoute(builder: (_)=>RepositoryProvider(
          create: (context)=>SplashRepo(),
          child: BlocProvider(
            create: (context)=>SplashBloc(context.read<SplashRepo>())..add(AuthCheck()),
            child: SplashScreen(),
          ),
        ));


      // login screen
      // case '/login':
      //   return MaterialPageRoute(builder: (_)=>RepositoryProvider(create: (context)=>LoginRepo(),
      //   child: BlocProvider(
      //     create: (context)=>LoginBloc(context.read<LoginRepo>()),
      //     child: LoginScreen(),
      //   ),
      // ));


      // Home Page
      // case '/login':
      //   return MaterialPageRoute(builder: (_)=>RepositoryProvider(create: (context)=>LoginRepo(),
      //   child: BlocProvider(
      //     create: (context)=>LoginBloc(context.read<LoginRepo>()),
      //     child: FarmerHomePage(),
      //   ),
      // ));


      // Reels page 
      //  case '/login':
      //   return MaterialPageRoute(builder: (_)=>RepositoryProvider(create: (context)=>LoginRepo(),
      //   child: BlocProvider(
      //     create: (context)=>LoginBloc(context.read<LoginRepo>()),
      //     child: ReelsPage(),
      //   ),
      // ));


      // Chat screen
      // case '/login':
      //   return MaterialPageRoute(
      //     builder: (_) => RepositoryProvider(
      //       create: (context) => LoginRepo(),
      //       child: BlocProvider(
      //         create: (context) => LoginBloc(context.read()),
      //         child: ChatScreen(
      //           userName: 'Pratik Nikat', 
      //           userProfilePic: 'https://images.ctfassets.net/h6goo9gw1hh6/2sNZtFAWOdP1lmQ33VwRN3/24e953b920a9cd0ff2e1d587742a2472/1-intro-photo-final.jpg?w=1200&h=992&fl=progressive&q=70&fm=jpg', // Provide a default profile picture
      //         ),
      //       ),
      //     ),
      //   );


      // Farmer Event
      //  case '/login':
      //   return MaterialPageRoute(
      //     builder: (_) => RepositoryProvider(
      //       create: (context) => LoginRepo(),
      //       child: BlocProvider(
      //         create: (context) => LoginBloc(context.read()),
      //         child: FarmerEventsPage()
      //       ),
      //     ),
      //   );


      // company description and product description 
      //  case '/login':
      //   return MaterialPageRoute(
      //     builder: (_) => RepositoryProvider(
      //       create: (context) => LoginRepo(),
      //       child: BlocProvider(
      //         create: (context) => LoginBloc(context.read()),
      //         child: CompanyListScreen()
      //       ),
      //     ),
      //   );
      //   case '/company-details':
      //   return MaterialPageRoute(
      //     builder: (_) => RepositoryProvider(
      //       create: (context) => LoginRepo(),
      //       child: BlocProvider(
      //         create: (context) => LoginBloc(context.read()),
      //         child: CompanyDetailsScreen()
      //       ),
      //     ),
      //   );
      //   case '/product-details':
      //   return MaterialPageRoute(
      //     builder: (_) => RepositoryProvider(
      //       create: (context) => LoginRepo(),
      //       child: BlocProvider(
      //         create: (context) => LoginBloc(context.read()),
      //         child: ProductDetailsScreen()
      //       ),
      //     ),
      //   );



      // CropCalendarScreen
      //  case '/login':
      //   return MaterialPageRoute(
      //     builder: (_) => RepositoryProvider(
      //       create: (context) => LoginRepo(),
      //       child: BlocProvider(
      //         create: (context) => LoginBloc(context.read()),
      //         child: CropCalendarScreen()
      //       ),
      //     ),
      //   );


      // news app 
      // case '/login':
      //   return MaterialPageRoute(builder: (_)=>RepositoryProvider(create: (context)=>LoginRepo(),
      //   child: BlocProvider(
      //     create: (context)=>LoginBloc(context.read<LoginRepo>()),
      //     child: NewsPage(),
      //   ),
      // ));


      // Feed section 
      // case '/login':
      //   return MaterialPageRoute(builder: (_)=>RepositoryProvider(create: (context)=>LoginRepo(),
      //   child: BlocProvider(
      //     create: (context)=>LoginBloc(context.read<LoginRepo>()),
      //     child: FarmerProfile(),
      //   ),
      // ));


      //CropSelectionScreen
      // case '/login':
      //   return MaterialPageRoute(builder: (_)=>RepositoryProvider(create: (context)=>LoginRepo(),
      //   child: BlocProvider(
      //     create: (context)=>LoginBloc(context.read<LoginRepo>()),
      //     child: CropSelectionScreen(),
      //   ),
      // ));


      //LanguageSelectionScreen
      // case '/login':
      //   return MaterialPageRoute(builder: (_)=>RepositoryProvider(create: (context)=>LoginRepo(),
      //   child: BlocProvider(
      //     create: (context)=>LoginBloc(context.read<LoginRepo>()),
      //     child: LanguageSelectionScreen(),
      //   ),
      // ));


      // WeatherScreen
      // case '/login':
      //   return MaterialPageRoute(builder: (_)=>RepositoryProvider(create: (context)=>LoginRepo(),
      //   child: BlocProvider(
      //     create: (context)=>LoginBloc(context.read<LoginRepo>()),
      //     child: WeatherScreen(),
      //   ),
      // ));


      // MarketPriceScreen
      case '/login':
        return MaterialPageRoute(builder: (_)=>RepositoryProvider(create: (context)=>LoginRepo(),
        child: BlocProvider(
          create: (context)=>LoginBloc(context.read<LoginRepo>()),
          child: MarketPriceScreen(),
        ),
      ));


      default:
        return MaterialPageRoute(builder: (_)=>RepositoryProvider(
          create: (context)=>SplashRepo(),
          child: BlocProvider(
            create: (context)=>SplashBloc(context.read<SplashRepo>())..add(AuthCheck()),
            child: SplashScreen(),
          ),
        ));
    }
  }
}