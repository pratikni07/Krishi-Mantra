import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import './bloc/splash_bloc.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SplashBloc,SplashState>(
        listener: (context, state){
      if(state is Authenticated){
        Navigator.pushReplacementNamed(context, '/login');
      }
        },
        builder: (context, state){
      return Scaffold(
        body: Center(
          child: Image.asset('assets/Images/Logo.png'),
        ),
      );

    });
  }
}
