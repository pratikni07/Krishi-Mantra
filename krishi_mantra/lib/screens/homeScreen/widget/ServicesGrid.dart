import 'package:flutter/material.dart';
import 'package:krishi_mantra/screens/features/company/company_list_screen.dart';
import 'package:krishi_mantra/screens/features/crop-calendar/CropCalendarPage.dart';
import 'package:krishi_mantra/screens/features/crop-calendar/ShowAllCrops.dart';
import 'package:krishi_mantra/screens/features/crop_care/ChatList.dart';
import 'package:krishi_mantra/screens/features/news/NewsPage.dart';
import 'package:krishi_mantra/screens/features/weather/WeatherScreen.dart';

class ServiceItem {
  final String icon;
  final String title;
  final Widget screen;

  ServiceItem({
    required this.icon,
    required this.title,
    required this.screen,
  });
}

class ServicesGrid extends StatelessWidget {
  const ServicesGrid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get screen size
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    // Calculate dimensions based on screen size
    final itemWidth = screenSize.width / 4;
    final iconSize = isSmallScreen ? 45.0 : 60.0;
    final verticalPadding = isSmallScreen ? 8.0 : 12.0;

    final List<ServiceItem> services = [
      ServiceItem(
        icon: 'assets/Images/serviceImg/farmdoctor.png',
        title: 'Weather',
        screen: WeatherScreen(),
      ),
      ServiceItem(
        icon: 'assets/Images/serviceImg/seeds.png',
        title: 'Crop Calendar',
        screen: CropListingPage(),
      ),
      ServiceItem(
        icon: 'assets/Images/serviceImg/news.png',
        title: 'AgriDoctor',
        screen: ChatListScreen(),
      ),
      ServiceItem(
        icon: 'assets/Images/serviceImg/fetilizers.png',
        title: 'Krishi AI',
        screen: CompanyListScreen(),
      ),
      ServiceItem(
        icon: 'assets/Images/serviceImg/image-3.png',
        title: 'Fertilizers',
        screen: ChatListScreen(),
      ),
      ServiceItem(
        icon: 'assets/Images/serviceImg/farmers.png',
        title: 'News',
        screen: NewsPage(),
      ),
      ServiceItem(
        icon: 'assets/Images/serviceImg/pestisides.png',
        title: 'Companies',
        screen: CompanyListScreen(),
      ),
      ServiceItem(
        icon: 'assets/Images/serviceImg/seeds1.png',
        title: 'Seeds',
        screen: CropListingPage(),
      ),
    ];

    return Container(
      margin: EdgeInsets.symmetric(vertical: verticalPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(verticalPadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 12,
              childAspectRatio:
                  itemWidth / (itemWidth * 1.3), // Adjusted for text height
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => services[index].screen,
                    ),
                  );
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(0),
                        child: Image.asset(
                          services[index].icon,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: Text(
                        services[index].title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2E7D32),
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
