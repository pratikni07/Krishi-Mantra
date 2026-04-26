// ignore_for_file: unused_field

import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:krishimantra/data/services/UserService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/home_localizations.dart';
import '../../../core/utils/translation_manager.dart';
import 'widgets/weather_section.dart';
import '../../widgets/app_header.dart';
import 'widgets/location_dialog.dart';
import 'package:get/get.dart';
import '../../controllers/action_card_controller.dart';
import '../../widgets/action_card/action_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../data/services/language_service.dart';
import 'package:krishimantra/core/utils/error_handler.dart';
import '../../../utils/image_utils.dart';
import '../../../core/utils/language_helper.dart';

import '../../controllers/ads_controller.dart';
import 'widgets/services.dart';
import 'widgets/farm_measure_banner.dart'; // ConsultationBanner
import 'widgets/feature_highlights.dart';
import 'widgets/trending_reels_section.dart';
import 'widgets/hot_products_section.dart';
import 'widgets/trending_hashtags.dart';
import 'widgets/latest_schemes_section.dart';
import '../../controllers/feed_controller.dart';
import '../../controllers/subscription_controller.dart';
import '../feed/widgets/feed_card.dart';
import '../../../data/services/weather_service.dart';
import '../../../data/models/feed_model.dart';
import '../../widgets/skeleton/skeleton_widgets.dart';
import '../../widgets/iot/pump_card.dart';
import '../../widgets/iot/crop_sensor_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TranslationMixin {
  final ScrollController _scrollController = ScrollController();
  bool _showWeather = true;
  String _location = "";
  String _username = "User";
  double _temperature = 0;
  int _humidity = 0;
  int _cloudiness = 0;
  bool _isLoadingWeather = true;
  bool _hasLocationPermission = false;
  bool _isLoadingAds = true;
  bool _isLoadingSlider = true;
  String _languageCode = '';
  final AdsController _adsController = Get.find<AdsController>();
  List<dynamic> _homeScreenAds = [];
  List<dynamic> _splashAds = [];
  // ignore: constant_identifier_names
  static const String LAST_SPLASH_SHOWN_KEY = 'last_splash_shown_time';
  final PageController _pageController = PageController();
  List<dynamic> _homeScreenSlider = [];
  int _currentPage = 0;
  Timer? _timer;
  final FeedController _feedController = Get.find<FeedController>();
  final SubscriptionController _subscriptionController =
      Get.find<SubscriptionController>();
  final WeatherService _weatherService = WeatherService();
  Position? _currentPosition;
  List<Map<String, String>> _testimonials = [];

  // Translation keys
  static const String KEY_SERVICES = 'services';
  static const String KEY_LOCATION_DISABLED = 'location_disabled';
  static const String KEY_ENABLE_LOCATION = 'enable_location';
  static const String KEY_PERMISSION_DENIED = 'permission_denied';
  static const String KEY_ALLOW_LOCATION = 'allow_location';
  static const String KEY_PERMISSION_DENIED_FOREVER =
      'permission_denied_forever';
  static const String KEY_GO_TO_SETTINGS = 'go_to_settings';
  static const String KEY_ERROR_FETCHING_LOCATION = 'error_fetching_location';
  static const String KEY_CLOSE = 'close';
  static const String KEY_TESTIMONIALS = 'testimonials';
  static const String KEY_SHARE_APP = 'share_app';
  static const String KEY_FETCHING_LOCATION = 'fetching_location';
  static const String KEY_WEATHER_REQUIRES_LOCATION =
      'weather_requires_location';
  static const String KEY_ALLOW_LOCATION_BTN = 'allow_location_btn';
  static const String KEY_FAILED_TO_LOAD_IMAGE = 'failed_to_load_image';
  static const String KEY_ADVERTISEMENT = 'advertisement';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _registerTranslations();
    _initializeTranslations();
    _syncLanguageCode();
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
    _loadUserData();
    _checkLocationPermission();
    _initializeAds();
    _initializeSlider();
    _feedController.fetchTopFeeds();
    _initializeTestimonials();
  }

  Future<void> _initializeTranslations() async {
    if (!mounted) return;
    setState(() {
      if (_location.isEmpty) {
        _location = _tr(KEY_FETCHING_LOCATION);
      }
    });
  }

  Future<void> _onLanguageChanged() async {
    await _syncLanguageCode();
    await _translateTestimonials();
    if (!mounted) return;
    setState(() {
      if (_location.isEmpty || _location == "Fetching location...") {
        _location = _tr(KEY_FETCHING_LOCATION);
      }
    });
  }

  Future<void> _syncLanguageCode() async {
    final languageService = await LanguageService.getInstance();
    if (!mounted) return;
    setState(() {
      _languageCode = languageService.getLanguageCode();
    });
  }

  String _tr(String key) {
    if (_languageCode.isEmpty) {
      return '';
    }
    return HomeLocalizations.text(key, _languageCode);
  }

  void _registerTranslations() {
    registerTranslation(KEY_SERVICES, '🌾 Services');
    registerTranslation(KEY_LOCATION_DISABLED, 'Location Service Disabled');
    registerTranslation(
        KEY_ENABLE_LOCATION, 'Please enable location services.');
    registerTranslation(KEY_PERMISSION_DENIED, 'Permission Denied');
    registerTranslation(KEY_ALLOW_LOCATION,
        'Please allow location access to use this feature.');
    registerTranslation(
        KEY_PERMISSION_DENIED_FOREVER, 'Permission Denied Forever');
    registerTranslation(KEY_GO_TO_SETTINGS,
        'You have denied location permission permanently. Go to settings to enable it.');
    registerTranslation(KEY_ERROR_FETCHING_LOCATION, 'Error fetching location');
    registerTranslation(KEY_CLOSE, 'Close');
    registerTranslation(KEY_TESTIMONIALS, 'What Farmers Say');
    registerTranslation(KEY_SHARE_APP,
        "Share KrishiMantra with more farmers and enjoy our free services. Let's grow with technology together!");
    registerTranslation(KEY_FETCHING_LOCATION, "Fetching location...");
    registerTranslation(
        KEY_WEATHER_REQUIRES_LOCATION, 'Weather data requires location');
    registerTranslation(KEY_ALLOW_LOCATION_BTN, 'Allow Location');
    registerTranslation(KEY_FAILED_TO_LOAD_IMAGE, 'Failed to load image');
    registerTranslation(KEY_ADVERTISEMENT, 'Advertisement');
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
    if (mounted) {
      setState(() {
        _username = username ?? "User";
      });
    }
  }

  Future<void> _initializeTestimonials() async {
    final sourceTestimonials = [
      {
        'name': 'Rajesh Kumar',
        'location': 'Maharashtra',
        'content':
            'KrishiMantra has helped me increase my crop yield by 30%. The weather predictions are very accurate!',
      },
      {
        'name': 'Anita Patel',
        'location': 'Gujarat',
        'content':
            'I love the marketplace feature. It helped me sell my produce directly to buyers at better prices.',
      },
      {
        'name': 'Suresh Singh',
        'location': 'Punjab',
        'content':
            'The crop disease detection feature saved my entire wheat field this season.',
      }
    ];

    // Assign translated testimonials in one update to avoid language flicker
    _testimonials = sourceTestimonials
        .map((item) => Map<String, String>.from(item))
        .toList();
    await _translateTestimonials();
  }

  Future<void> _translateTestimonials() async {
    // Get language service directly to ensure it's initialized
    final languageService = await LanguageService.getInstance();

    for (var i = 0; i < _testimonials.length; i++) {
      // Translate the content
      _testimonials[i]['content'] =
          await languageService.translate(_testimonials[i]['content'] ?? '');

      // Also translate name format for display (e.g., "Rajesh Kumar" stays, but location can be translated)
      final location = _testimonials[i]['location'] ?? '';
      _testimonials[i]['location'] = await languageService.translate(location);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _hasLocationPermission = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _hasLocationPermission = false);
        return;
      }

      // If we get here, permission is granted
      setState(() => _hasLocationPermission = true);
      _fetchLocation(); // Fetch location only if permission is granted
    } catch (e) {
      setState(() => _hasLocationPermission = false);
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showLocationDialog(
              _tr(KEY_LOCATION_DISABLED), _tr(KEY_ENABLE_LOCATION));
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showLocationDialog(
                _tr(KEY_PERMISSION_DENIED), _tr(KEY_ALLOW_LOCATION));
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationDialog(
              _tr(KEY_PERMISSION_DENIED_FOREVER), _tr(KEY_GO_TO_SETTINGS));
        }
        return;
      }

      // Permission granted
      setState(() => _hasLocationPermission = true);
      _fetchLocation();
    } catch (e) {
      if (mounted) {
        _showLocationDialog(_tr(KEY_ERROR_FETCHING_LOCATION), e.toString());
      }
    }
  }

  Future<void> _fetchLocation() async {
    if (!_hasLocationPermission) {
      logger.d('Location permission not granted, skipping fetch',
          tag: 'HomeScreen');
      return;
    }

    try {
      logger.d('Fetching current position...', tag: 'HomeScreen');
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      logger.d('Got position: ${position.latitude}, ${position.longitude}',
          tag: 'HomeScreen');

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;

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

        logger.d('Location name: $locationName', tag: 'HomeScreen');

        setState(() {
          _currentPosition = position;
          _location = locationName;
        });

        // Fetch weather data after getting location
        logger.d('Calling _fetchWeatherData...', tag: 'HomeScreen');
        await _fetchWeatherData();
      }
    } catch (e) {
      logger.e('Error fetching location', tag: 'HomeScreen', error: e);
      if (mounted) {
        setState(() {
          _location = _tr(KEY_ERROR_FETCHING_LOCATION);
        });
      }
    }
  }

  Future<void> _fetchWeatherData() async {
    if (_currentPosition == null) {
      logger.d('_currentPosition is null, skipping weather fetch',
          tag: 'HomeScreen');
      return;
    }

    try {
      logger.d('Fetching weather data...', tag: 'HomeScreen');
      if (mounted) {
        setState(() => _isLoadingWeather = true);
      }

      final weatherData =
          await _weatherService.getWeatherData(_currentPosition!);

      if (!mounted) return;

      final temp = (weatherData['temperature'] ?? 0).toDouble();
      final humidity = weatherData['humidity'] ?? 0;
      final cloudiness = weatherData['cloudiness'] ?? 0;

      logger.d(
          'Weather data received: temp=$temp, humidity=$humidity, cloudiness=$cloudiness',
          tag: 'HomeScreen');

      setState(() {
        _temperature = temp;
        _humidity = humidity;
        _cloudiness = cloudiness;
        _isLoadingWeather = false;
      });
    } catch (e) {
      logger.e('Error fetching weather data', tag: 'HomeScreen', error: e);
      if (mounted) {
        setState(() {
          _isLoadingWeather = false;
        });
      }
    }
  }

  Future<void> _initializeAds() async {
    try {
      final homeScreenAds = await _adsController.fetchHomeScreenAds();
      final splashAds = await _adsController.fetchSplashAds();

      if (!mounted) return;

      setState(() {
        _homeScreenAds = homeScreenAds;
        _splashAds = splashAds;
        _isLoadingAds = false;
      });

      _checkAndShowSplashAd();
    } catch (e) {
      // Handle error silently
      if (mounted) {
        setState(() {
          _isLoadingAds = false;
        });
      }
    }
  }

  Future<void> _checkAndShowSplashAd() async {
    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastShownTime = prefs.getInt(LAST_SPLASH_SHOWN_KEY) ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;

      if (_splashAds.isNotEmpty) {
        if (currentTime - lastShownTime >= 7200000) {
          if (!mounted) return;

          await Future.delayed(const Duration(milliseconds: 500));
          _showSplashAd(_splashAds.first);

          await prefs.setInt(LAST_SPLASH_SHOWN_KEY, currentTime);
        }
      }
    } catch (e) {}
  }

  void _showSplashAd(dynamic splashAd) {
    if (!mounted) return;

    // Handle different possible data structures safely
    String imageUrl = '';
    try {
      if (splashAd is List && splashAd.isNotEmpty) {
        imageUrl = splashAd[0]['dirURL'] ?? '';
      } else if (splashAd is Map) {
        imageUrl = splashAd['dirURL'] ?? '';
      }
    } catch (e) {}

    // Validate the URL
    imageUrl = ImageUtils.validateUrl(imageUrl);

    // Don't show dialog if no valid image URL
    if (imageUrl.isEmpty) {
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        ResponsiveUtils.init(context);
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: ResponsiveUtils.wp(90),
                  padding: RPadding.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (imageUrl.isNotEmpty)
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: ResponsiveUtils.hp(70),
                          ),
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusL),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) {
                                  return child;
                                }
                                return SizedBox(
                                  height: ResponsiveUtils.hp(25),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          loadingProgress.expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                      .cumulativeBytesLoaded /
                                                  loadingProgress
                                                      .expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: ResponsiveUtils.hp(25),
                                  color: AppColors.shimmerBase,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.error,
                                          size: AppSizes.iconXL,
                                          color: AppColors.error),
                                      SizedBox(height: AppSizes.paddingS),
                                      Text(_tr(KEY_FAILED_TO_LOAD_IMAGE),
                                          style: TextStyle(
                                            color: AppColors.error,
                                            fontSize: AppSizes.fontM,
                                          )),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // X close button positioned at top right
                Positioned(
                  top: -12,
                  right: -12,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowLight,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
              ],
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
        showSettingsButton: title == _tr(KEY_PERMISSION_DENIED_FOREVER),
      ),
    );
  }

  Future<void> _initializeSlider() async {
    try {
      await _fetchSliderWithRetry();
      if (_homeScreenSlider.isNotEmpty && mounted) {
        _startAutoScroll();
      }
    } catch (e) {
      // Error handled silently
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingSlider = false;
        });
      }
    }
  }

  Future<void> _fetchSliderWithRetry() async {
    const maxRetries = 3;
    int retryCount = 0;
    Duration delay = const Duration(seconds: 1);

    while (retryCount < maxRetries) {
      try {
        final sliderData = await _adsController.fetchHomeScreenSlider();

        if (!mounted) return;

        _homeScreenSlider = sliderData;
        return; // Success, exit the function
      } catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          rethrow; // We've reached max retries, rethrow the exception
        }

        // Wait with exponential backoff before next retry
        await Future.delayed(delay);
        delay *= 2; // Double the delay for next retry
      }
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
    TranslationManager.instance
        .removeLanguageChangeListener(_onLanguageChanged);
    _scrollController.dispose();
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    // Reset flags
    setState(() {
      _isLoadingWeather = true;
      _isLoadingAds = true;
      _isLoadingSlider = true;
    });

    // Refresh all data
    await _checkLocationPermission();
    await _initializeAds();
    await _initializeSlider();

    _feedController.fetchTopFeeds();

    setState(() {
      _isLoadingWeather = false;
    });

    return;
  }

  // Loading weather widget
  Widget _buildLoadingWeather() {
    return Container(
      height: ResponsiveUtils.hp(12),
      color: AppColors.green,
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 3,
        ),
      ),
    );
  }

  // Location request widget
  Widget _buildLocationRequestWidget() {
    return Container(
      padding: RPadding.symmetric(vertical: 16, horizontal: 24),
      color: AppColors.green,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on,
                  color: Colors.white, size: AppSizes.iconM),
              SizedBox(width: AppSizes.paddingS),
              Text(
                _tr(KEY_WEATHER_REQUIRES_LOCATION),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: AppSizes.fontL,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.paddingS),
          ElevatedButton(
            onPressed: _requestLocationPermission,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.green,
              padding: RPadding.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
              ),
            ),
            child: Text(
              _tr(KEY_ALLOW_LOCATION_BTN),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.fontM,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // Dynamic sizes using ResponsiveUtils
    final cardPadding = AppSizes.paddingL;
    final sectionSpacing =
        ResponsiveUtils.responsive(mobile: 16.0, tablet: 24.0);
    final titleFontSize = AppSizes.fontXL;
    final appBarExpandedHeight =
        ResponsiveUtils.responsive(mobile: 200.0, tablet: 240.0);
    final appBarCollapsedHeight =
        ResponsiveUtils.responsive(mobile: 100.0, tablet: 120.0);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: RefreshIndicator(
        color: AppColors.green,
        onRefresh: _refreshData,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight:
                  _showWeather ? appBarExpandedHeight : appBarCollapsedHeight,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.green,
              title: AppHeader(),
              flexibleSpace: FlexibleSpaceBar(
                background: _showWeather
                    ? WeatherSection(
                        statusBarHeight: statusBarHeight,
                        screenWidth: ResponsiveUtils.screenWidth,
                        temperature: _temperature,
                        humidity: _humidity,
                        cloudiness: _cloudiness,
                        hasLocationPermission: _hasLocationPermission,
                        onRequestLocation: _requestLocationPermission,
                      )
                    : null,
              ),
            ),

            // Today's action card (krishi-ai). Lazy-loads on first build via
            // the ActionCardController binding registered in DI.
            const SliverToBoxAdapter(child: _ActionCardSection()),

            // Carousel Slider
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.symmetric(vertical: sectionSpacing * 0.5),
                child: _buildCarouselSlider(),
              ),
            ),

            // IoT Pump Section (shown only when admin enabled + active add-on)
            SliverToBoxAdapter(
              child: Obx(
                () => _subscriptionController.hasWaterPumpAccess
                    ? const IoTPumpSection()
                    : const SizedBox.shrink(),
              ),
            ),

            // Krishi Doctor Section (shown only when admin enabled + active add-on)
            SliverToBoxAdapter(
              child: Obx(
                () => _subscriptionController.hasCropMonitoringAccess
                    ? const IoTCropSensorSection()
                    : const SizedBox.shrink(),
              ),
            ),

            // Consultation Banner
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.only(top: sectionSpacing * 0.5),
                child: const ConsultationBanner(),
              ),
            ),

            // Services Section
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(
                        top: sectionSpacing * 0.5,
                        bottom: sectionSpacing * 0.25),
                    child: Text(
                      _tr(KEY_SERVICES),
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.only(
                        left: cardPadding,
                        right: cardPadding,
                        bottom: sectionSpacing * 0.25),
                    child: Services(),
                  ),
                ],
              ),
            ),

            // Feature Highlights Section
            const SliverToBoxAdapter(
              child: FeatureHighlights(),
            ),

            // Trending Reels Section
            const SliverToBoxAdapter(
              child: TrendingReelsSection(),
            ),

            // Hot Products Section
            const SliverToBoxAdapter(
              child: HotProductsSection(),
            ),

            // Trending Hashtags Section
            const SliverToBoxAdapter(
              child: TrendingHashtags(),
            ),

            // Ads and Feeds
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // First Ad (show skeleton while loading, then actual ad)
                  if (_isLoadingAds)
                    const SkeletonAdBanner()
                  else if (_homeScreenAds.isNotEmpty)
                    Container(
                      margin: EdgeInsets.symmetric(
                          horizontal: cardPadding, vertical: cardPadding * 0.5),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowLight,
                            offset: Offset(0, 2),
                            blurRadius: 6.0,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSizes.radiusL),
                        child: Image.network(
                          ImageUtils.validateUrl(
                              _homeScreenAds[0]['dirURL'] ?? ''),
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            logger.e('Error loading home screen ad',
                                tag: 'HomeScreen', error: error);
                            return Container(
                              height: ResponsiveUtils.hp(25),
                              color: AppColors.shimmerBase,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error,
                                      color: AppColors.error,
                                      size: AppSizes.iconM),
                                  SizedBox(height: AppSizes.paddingS),
                                  Text(
                                    _tr(KEY_ADVERTISEMENT),
                                    style: TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: AppSizes.fontM,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  // Top Feeds - Using GetBuilder to avoid RxList.length infinite recursion
                  GetBuilder<FeedController>(
                    init: _feedController,
                    builder: (controller) {
                      if (controller.isLoadingTopFeeds.value) {
                        return Column(
                          children: const [
                            SkeletonFeedCard(),
                            SkeletonFeedCard(),
                          ],
                        );
                      }

                      // Create a non-reactive copy to avoid RxList issues
                      final topFeedsList =
                          List<FeedModel>.from(controller.topFeeds);

                      return Column(
                        children: topFeedsList
                            .map((feed) => FeedCard(
                                  feed: feed,
                                  onLike: () => controller.likeFeed(feed.id),
                                  onSave: () {},
                                ))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Latest Schemes Section
            const SliverToBoxAdapter(
              child: LatestSchemesSection(),
            ),

            // Testimonials Section
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.only(
                        top: sectionSpacing, bottom: sectionSpacing * 0.5),
                    child: Text(
                      _tr(KEY_TESTIMONIALS),
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    height: ResponsiveUtils.responsive(
                        mobile: 160.0, tablet: 200.0),
                    margin: EdgeInsets.only(bottom: sectionSpacing * 0.5),
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: cardPadding),
                      itemCount: _testimonials.length,
                      itemBuilder: (context, index) {
                        return _buildHorizontalTestimonialCard(
                            _testimonials[index]);
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Share App Section
            SliverToBoxAdapter(
              child: Container(
                margin: EdgeInsets.symmetric(
                    horizontal: cardPadding * 1.5, vertical: sectionSpacing),
                padding: RPadding.all(16),
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  border: Border.all(color: AppColors.green, width: 1.0),
                ),
                child: Text(
                  _tr(KEY_SHARE_APP),
                  style: TextStyle(
                    color: AppColors.green,
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Bottom padding
            SliverToBoxAdapter(
              child: SizedBox(height: sectionSpacing),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarouselSlider() {
    final carouselHeight =
        ResponsiveUtils.responsive(mobile: 200.0, tablet: 280.0);

    // Show skeleton while loading
    if (_isLoadingSlider && _homeScreenSlider.isEmpty) {
      return Container(
        height: carouselHeight,
        child: const SkeletonCarouselItem(),
      );
    }

    if (_homeScreenSlider.isEmpty) {
      return const SizedBox.shrink();
    }
    final dotSize = ResponsiveUtils.responsive(mobile: 8.0, tablet: 10.0);

    return Container(
      height: carouselHeight,
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
                margin: EdgeInsets.symmetric(horizontal: AppSizes.paddingM),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      offset: Offset(0, 2),
                      blurRadius: 6.0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
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
                        color: AppColors.shimmerBase,
                        child: Icon(Icons.error,
                            color: AppColors.error, size: AppSizes.iconM),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // Smooth page indicator
          Positioned(
            bottom: AppSizes.paddingM,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _pageController,
                count: _homeScreenSlider.length,
                effect: WormEffect(
                  dotHeight: dotSize,
                  dotWidth: dotSize,
                  spacing: dotSize,
                  dotColor: AppColors.white.withOpacity(0.4),
                  activeDotColor: AppColors.white,
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

  Widget _buildHorizontalTestimonialCard(Map<String, String> testimonial) {
    final cardWidth = ResponsiveUtils.responsive(mobile: 320.0, tablet: 400.0);

    return Container(
      width: cardWidth,
      margin: EdgeInsets.only(right: AppSizes.paddingM),
      padding: RPadding.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        border: Border.all(color: AppColors.green, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            offset: Offset(0, 2),
            blurRadius: 4.0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quote icon at the top
          Align(
            alignment: Alignment.topLeft,
            child: Icon(
              Icons.format_quote,
              color: AppColors.green,
              size: AppSizes.iconM,
            ),
          ),

          // Content first (main testimonial text)
          Expanded(
            child: Padding(
              padding: RPadding.symmetric(vertical: 8),
              child: Text(
                testimonial['content'] ?? '',
                style: TextStyle(
                  fontSize: AppSizes.fontM,
                  color: AppColors.textDark,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 5,
              ),
            ),
          ),

          // Name and location at the bottom right
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              "- ${testimonial['name'] ?? ''} (${testimonial['location']?.split(',')[0] ?? ''})",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppSizes.fontS,
                fontStyle: FontStyle.italic,
                color: AppColors.textDark,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}


/// Lightweight wrapper that mounts the action-card on the home screen.
/// Triggers load() the first time it builds; the controller is fenix-cached
/// so subsequent home rebuilds reuse the existing instance + state.
class _ActionCardSection extends StatefulWidget {
  const _ActionCardSection();
  @override
  State<_ActionCardSection> createState() => _ActionCardSectionState();
}

class _ActionCardSectionState extends State<_ActionCardSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final c = Get.find<ActionCardController>();
        if (c.card.value == null) c.load();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) => const ActionCardWidget();
}
