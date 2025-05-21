// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:krishimantra/presentation/screens/cropcare/ChatListScreen.dart';
import 'package:krishimantra/presentation/screens/feed/feed_screen.dart';
import 'package:krishimantra/presentation/screens/profile/ProfileScreen.dart';
import '../../data/services/language_service.dart';

import '../../core/constants/colors.dart';
import 'home/home_screen.dart';
import 'reel/reels_page.dart';
import 'package:get/get.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  late LanguageService _languageService;
  String homeText = 'Home';
  String feedText = 'Feed';
  String cropCareText = 'Crop Care';
  String reelsText = 'Reels';
  String profileText = 'Profile';

  final List<Widget> _pages = [
    const HomeScreen(),
    FeedScreen(),
    const ChatListScreen(),
    const ReelsPage(),
    const ProfileScreen()
  ];

  @override
  void initState() {
    super.initState();
    _initializeLanguage();
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('Home'),
      _languageService.translate('Feed'),
      _languageService.translate('Crop Care'),
      _languageService.translate('Reels'),
      _languageService.translate('Profile'),
    ]);

    setState(() {
      homeText = translations[0];
      feedText = translations[1];
      cropCareText = translations[2];
      reelsText = translations[3];
      profileText = translations[4];
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          elevation: 0,
          backgroundColor: AppColors.white,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppColors.green,
          unselectedItemColor: AppColors.textGrey,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.green,
                      width: 3.0,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 5),
                child: Icon(Icons.home_rounded, color: AppColors.green),
              ),
              label: homeText,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_4x4_outlined),
              activeIcon: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.green,
                      width: 3.0,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 5),
                child: Icon(Icons.grid_view_outlined, color: AppColors.green),
              ),
              label: feedText,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.eco_outlined),
              activeIcon: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.green,
                      width: 3.0,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 5),
                child: Icon(Icons.eco_rounded, color: AppColors.green),
              ),
              label: cropCareText,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.video_library_outlined),
              activeIcon: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.green,
                      width: 3.0,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 5),
                child: Icon(Icons.video_library, color: AppColors.green),
              ),
              label: reelsText,
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppColors.green,
                      width: 3.0,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(top: 5),
                child: Icon(Icons.person_rounded, color: AppColors.green),
              ),
              label: profileText,
            ),
          ],
        ),
      ),
    );
  }
}
