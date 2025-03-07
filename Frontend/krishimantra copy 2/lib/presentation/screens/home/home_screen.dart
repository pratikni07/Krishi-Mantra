import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:krishimantra/data/services/UserService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/colors.dart';
import 'widgets/weather_section.dart';
import '../../widgets/app_header.dart';
import 'widgets/location_dialog.dart';
import 'widgets/list_item.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../data/services/language_service.dart';

import '../../controllers/ads_controller.dart';
import 'widgets/services.dart';
import '../../controllers/feed_controller.dart';
import '../feed/widgets/feed_card.dart';
import '../../../data/services/weather_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showWeather = true;
  String _location = "Fetching location...";
  String _username = "User";
  double _temperature = 0;
  int _humidity = 0;
  int _cloudiness = 0;
  bool _isLoadingWeather = true;
  final AdsController _adsController = Get.find<AdsController>();
  List<dynamic> _homeScreenAds = [];
  List<dynamic> _splashAds = [];
  static const String LAST_SPLASH_SHOWN_KEY = 'last_splash_shown_time';
  final PageController _pageController = PageController();
  List<dynamic> _homeScreenSlider = [];
  int _currentPage = 0;
  Timer? _timer;
  final FeedController _feedController = Get.find<FeedController>();
  final WeatherService _weatherService = WeatherService();
  Position? _currentPosition;
  late LanguageService _languageService;
  String servicesText = '🌾 Services';
  String locationServiceDisabledText = "Location Service Disabled";
  String enableLocationText = "Please enable location services.";
  String permissionDeniedText = "Permission Denied";
  String allowLocationText = "Please allow location access to use this feature.";
  String permissionDeniedForeverText = "Permission Denied Forever";
  String goToSettingsText = "You have denied location permission permanently. Go to settings to enable it.";
  String errorFetchingLocationText = "Error fetching location";
  String closeText = "Close";

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadUserData();
    _initializeLanguage();
    _fetchLocation();
    _initializeAds();
    _initializeSlider();
    _feedController.fetchTopFeeds();
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && _showWeather) {
      setState(() => _showWeather = false);
    } else if (_scrollController.offset <= 50 && !_showWeather) {
      setState(() => _showWeather = true);
    }
  }

  Future<void> _loadUserData() async {
    String? username = await UserService().getFirstName();
    setState(() {
      _username = username ?? "User";
    });
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('🌾 Services'),
      _languageService.translate('Location Service Disabled'),
      _languageService.translate('Please enable location services.'),
      _languageService.translate('Permission Denied'),
      _languageService.translate('Please allow location access to use this feature.'),
      _languageService.translate('Permission Denied Forever'),
      _languageService.translate('You have denied location permission permanently. Go to settings to enable it.'),
      _languageService.translate('Error fetching location'),
      _languageService.translate('Close'),
    ]);

    setState(() {
      servicesText = translations[0];
      locationServiceDisabledText = translations[1];
      enableLocationText = translations[2];
      permissionDeniedText = translations[3];
      allowLocationText = translations[4];
      permissionDeniedForeverText = translations[5];
      goToSettingsText = translations[6];
      errorFetchingLocationText = translations[7];
      closeText = translations[8];
    });
  }

  Future<void> _fetchLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationDialog(
          locationServiceDisabledText, enableLocationText);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showLocationDialog(permissionDeniedText, allowLocationText);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showLocationDialog(
          permissionDeniedForeverText, goToSettingsText);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String locationName = '';

        if (place.locality?.isNotEmpty ?? false) {
          locationName = place.locality!;
        } else if (place.subAdministrativeArea?.isNotEmpty ?? false) {
          locationName = place.subAdministrativeArea!;
        } else if (place.administrativeArea?.isNotEmpty ?? false) {
          locationName = place.administrativeArea!;
        }

        setState(() {
          _currentPosition = position;
          _location = locationName;
        });

        // Fetch weather data after getting location
        await _fetchWeatherData();
      }
    } catch (e) {
      setState(() {
        _location = errorFetchingLocationText;
      });
    }
  }

  Future<void> _fetchWeatherData() async {
    if (_currentPosition == null) return;

    try {
      setState(() => _isLoadingWeather = true);
      
      // For demo purposes, using mock data to avoid API key requirement
      // Replace this with actual API call when you have the API key
      await Future.delayed(Duration(seconds: 1)); // Simulate network delay
      setState(() {
        // Round the temperature to whole number
        _temperature = (28.0 + Random().nextDouble() * 5).roundToDouble();
        _humidity = 60 + Random().nextInt(20);
        _cloudiness = Random().nextInt(100);
        _isLoadingWeather = false;
      });

      /* Uncomment this when you have API key
      final weatherData = await _weatherService.getWeatherData(_currentPosition!);
      setState(() {
        _temperature = double.parse(weatherData['temperature'].toStringAsFixed(0));
        _humidity = weatherData['humidity'];
        _cloudiness = weatherData['cloudiness'];
        _isLoadingWeather = false;
      });
      */
    } catch (e) {
      print('Error fetching weather data: $e');
      setState(() {
        _isLoadingWeather = false;
        // Set default values in case of error
        _temperature = 0.0;
        _humidity = 0;
        _cloudiness = 0;
      });
    }
  }

  Future<void> _initializeAds() async {
    await _fetchAds();
    await _checkAndShowSplashAd();
  }

  Future<void> _fetchAds() async {
    try {
      print('Fetching ads...');
      _splashAds = await _adsController.fetchSplashAds();
      _homeScreenAds = await _adsController.fetchHomeScreenAds();
      
      // Sort home screen ads by priority
      _homeScreenAds.sort((a, b) => (a['priority'] ?? 0).compareTo(b['priority'] ?? 0));
      
      // Debug prints
      print('Splash ads response: $_splashAds');
      print('Number of splash ads: ${_splashAds.length}');
      if (_splashAds.isNotEmpty) {
        print('First splash ad: ${_splashAds.first}');
      }
      
      setState(() {});
    } catch (e, stackTrace) {
      print('Error fetching ads: $e');
      print('Stack trace: $stackTrace');
    }
  }

  Future<void> _checkAndShowSplashAd() async {
    try {
      print('Checking splash ad conditions...');
      final prefs = await SharedPreferences.getInstance();
      final lastShownTime = prefs.getInt(LAST_SPLASH_SHOWN_KEY) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      print('Time since last shown: ${currentTime - lastShownTime}ms');
      print('Has splash ads: ${_splashAds.isNotEmpty}');

      if (_splashAds.isNotEmpty) {
        if (currentTime - lastShownTime >= 7200000) {
          print('Showing splash ad...');
          if (!mounted) return;
          
          await Future.delayed(const Duration(milliseconds: 500));
          _showSplashAd(_splashAds.first);
          
          await prefs.setInt(LAST_SPLASH_SHOWN_KEY, currentTime);
        } else {
          print('Not showing splash ad - too soon since last shown');
        }
      }
    } catch (e) {
      print('Error in _checkAndShowSplashAd: $e');
    }
  }

  void _showSplashAd(dynamic splashAd) {
    if (!mounted) return;
    
    // Debug print to check the splash ad data
    print('Splash Ad Data: $splashAd');
    final String imageUrl = splashAd[0]['dirURL'] ?? '';
    print('Image URL: $imageUrl');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (imageUrl.isNotEmpty) 
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) {
                              return child;
                            }
                            return SizedBox(
                              height: 200,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            print('Error loading image: $error');
                            print('Stack trace: $stackTrace');
                            return Container(
                              height: 200,
                              color: Colors.grey[200],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, size: 40, color: Colors.red),
                                  SizedBox(height: 8),
                                  Text('Failed to load image',
                                      style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey),
                      ),
                    ),
                    child: Text(closeText),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLocationDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => LocationDialog(
        title: title,
        message: message,
        showSettingsButton: title == permissionDeniedForeverText,
      ),
    );
  }

  Future<void> _initializeSlider() async {
    _homeScreenSlider = await _adsController.fetchHomeScreenSlider();
    if (_homeScreenSlider.isNotEmpty) {
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 8), (timer) {
      if (_homeScreenSlider.isEmpty) return;
      
      if (_currentPage < _homeScreenSlider.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentPage,
          duration: Duration(milliseconds: 800),
          curve: Curves.fastOutSlowIn,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double statusBarHeight = mediaQuery.padding.top;
    final double screenWidth = mediaQuery.size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: _showWeather ? 200.0 : 100.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.green,
            title: AppHeader(),
            flexibleSpace: FlexibleSpaceBar(
              background: _showWeather
                  ? WeatherSection(
                      statusBarHeight: statusBarHeight,
                      screenWidth: screenWidth,
                      temperature: _temperature,
                      humidity: _humidity,
                      cloudiness: _cloudiness,
                    )
                  : null,
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.only(top: 16.0),
              child: _buildCarouselSlider(),
            ),
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: 20.0, bottom: 0.0),
                  child: Text(
                    servicesText,
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Services(),
                ),
                // if (_homeScreenAds.isNotEmpty) Container(
                //   margin: EdgeInsets.only(top: 20.0, bottom: 0.0),
                //   child: Text(
                //     'Advertisements',
                //     style: TextStyle(
                //       color: AppColors.green,
                //       fontSize: 22,
                //       fontWeight: FontWeight.bold,
                //     ),
                //     textAlign: TextAlign.center,
                //   ),
                // ),
                if (_homeScreenAds.isNotEmpty) Container(
                  margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 2),
                        blurRadius: 6.0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      _homeScreenAds[0]['dirURL'],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: Icon(Icons.error, color: Colors.red),
                        );
                      },
                    ),
                  ),
                ),
                // Container(
                //   margin: EdgeInsets.only(top: 20.0, bottom: 0.0),
                //   child: Text(
                //     'Top Feeds',
                //     style: TextStyle(
                //       color: AppColors.green,
                //       fontSize: 22,
                //       fontWeight: FontWeight.bold,
                //     ),
                //     textAlign: TextAlign.center,
                //   ),
                // ),
                Obx(() {
                  if (_feedController.isLoadingTopFeeds.value) {
                    return Center(child: CircularProgressIndicator());
                  }
                  
                  return Column(
                    children: _feedController.topFeeds.map((feed) => FeedCard(
                      feed: feed,
                      onLike: () => _feedController.likeFeed(feed.id),
                      onSave: () {}, // Implement save functionality if needed
                    )).toList(),
                  );
                }),
                if (_homeScreenAds.length > 1) ..._homeScreenAds.sublist(1, min(_homeScreenAds.length, 3)).map((ad) => Container(
                  margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        offset: Offset(0, 2),
                        blurRadius: 6.0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      ad['dirURL'],
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: Icon(Icons.error, color: Colors.red),
                        );
                      },
                    ),
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselSlider() {
    if (_homeScreenSlider.isEmpty) {
      return Container();
    }

    return Container(
      height: 200,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _homeScreenSlider.length,
            itemBuilder: (context, index) {
              final ad = _homeScreenSlider[index];
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 10.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      offset: Offset(0, 2),
                      blurRadius: 6.0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    ad['dirURL'],
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Icon(Icons.error, color: Colors.red),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // Smooth page indicator
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _homeScreenSlider.length,
                effect: WormEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 8,
                  dotColor: Colors.white.withOpacity(0.4),
                  activeDotColor: Colors.white,
                ),
                onDotClicked: (index) {
                  _pageController.animateToPage(
                    index,
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeIn,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
