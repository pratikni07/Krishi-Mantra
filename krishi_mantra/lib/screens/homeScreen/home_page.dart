import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:krishi_mantra/API/HomeScreenAPI.dart';
import 'package:krishi_mantra/screens/components/PostCard.dart';
import 'package:krishi_mantra/screens/components/TestimonialSection.dart';
import 'package:krishi_mantra/screens/components/NewsCard.dart';
import 'package:geolocator/geolocator.dart';
import 'package:krishi_mantra/screens/features/Subscription/SubscriptionScreen.dart';
import 'package:krishi_mantra/screens/features/crop_care/ChatList.dart';
import 'package:krishi_mantra/screens/features/crop_care/ChatScreen.dart';
import 'package:krishi_mantra/screens/features/feeds/FeedScreen.dart';
import 'package:krishi_mantra/screens/features/govschemes/GovSchemesScreen.dart';
import 'package:krishi_mantra/screens/features/mandi/MarketPriceScreen.dart';
import 'package:krishi_mantra/screens/features/profile/FarmerProfilePage.dart';
import 'package:krishi_mantra/screens/features/reels/ReelPage.dart';
import 'package:krishi_mantra/screens/features/videosScreen/VideoHomeScreen.dart';
import 'package:krishi_mantra/screens/features/videosScreen/VideoPlayerScreen.dart';
import 'package:krishi_mantra/screens/homeScreen/widget/PromoModal.dart';
import 'package:krishi_mantra/screens/homeScreen/widget/ServicesGrid.dart';
import 'package:krishi_mantra/services/storage_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdCarousel extends StatelessWidget {
  final List<Map<String, dynamic>> ads;

  const AdCarousel({super.key, required this.ads});

  @override
  Widget build(BuildContext context) {
    return ads.isEmpty
        ? const SizedBox.shrink()
        : SizedBox(
            height: 100,
            child: PageView.builder(
              itemCount: ads.length,
              itemBuilder: (context, index) {
                return Container(
                  child: ClipRRect(
                    child: SizedBox(
                      child: Image.network(
                        ads[index]['dirURL'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.error),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          );
  }
}

class DynamicHeader extends StatefulWidget {
  final bool isCollapsed;
  const DynamicHeader({Key? key, required this.isCollapsed}) : super(key: key);

  @override
  State<DynamicHeader> createState() => _DynamicHeaderState();
}

class _DynamicHeaderState extends State<DynamicHeader> {
  String userName = '';
  String location = 'Unknown Location';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final name = await StorageService.getUserName();
      final prefs = await SharedPreferences.getInstance();
      final userLocation = prefs.getString('city_name');

      setState(() {
        userName = name ?? 'User';
        location = userLocation ?? 'Unknown Location';
      });
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Widget _buildCollapsedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Hello',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.waving_hand,
                          color: Colors.yellow, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Welcome, $userName',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    location,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Row(
                children: [
                  Icon(Icons.chat_bubble_outline,
                      color: Colors.white, size: 20),
                  SizedBox(width: 16),
                  Icon(Icons.notifications_none, color: Colors.white, size: 20),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.waving_hand,
                          color: Color.fromARGB(255, 249, 227, 23)),
                      SizedBox(width: 5),
                      Text(
                        'Hello',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Welcome, $userName',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    location,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const Row(
                children: [
                  Icon(Icons.chat_bubble_outline, color: Colors.white),
                  SizedBox(width: 16),
                  Icon(Icons.notifications_none, color: Colors.white),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.isCollapsed
        ? _buildCollapsedHeader()
        : _buildExpandedHeader();
  }
}

class FarmerHomePage extends StatefulWidget {
  const FarmerHomePage({super.key});

  @override
  State<FarmerHomePage> createState() => _FarmerHomePageState();
}

class _FarmerHomePageState extends State<FarmerHomePage> {
  int _currentIndex = 0;
  bool _isLocationSaved = false;
  String _savedLocation = '';
  String _cityName = 'Unknown Location';
  Position? _currentPosition;
  List<Map<String, dynamic>> priority1Ads = [];
  List<Map<String, dynamic>> priority2Ads = [];
  bool isLoading = true;
  bool _isInitialLocationCheck = true;

  Timer? _modalTimer;
  static const String LAST_MODAL_TIME_KEY = 'last_modal_time';

  final List<Map<String, String>> promoData = [
    {
      'imageUrl':
          'https://img.pikbest.com/origin/06/30/22/05ppIkbEsTaxg.jpg!w700wp',
      'targetUrl': 'https://example.com/promo1'
    }
  ];

  @override
  void initState() {
    super.initState();
    fetchAds();
    _checkLocationStatus();
    _initializeModalTimer();
  }

  @override
  void dispose() {
    _modalTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeModalTimer() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShownTime = prefs.getInt(LAST_MODAL_TIME_KEY) ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    if (currentTime - lastShownTime >=
        const Duration(hours: 2).inMilliseconds) {
      // Show modal immediately if 2 hours have passed
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPromoModal();
      });
    }

    // Set up periodic timer for every 2 hours
    _modalTimer = Timer.periodic(const Duration(hours: 2), (timer) {
      _showPromoModal();
    });
  }

  Future<void> _showPromoModal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        LAST_MODAL_TIME_KEY, DateTime.now().millisecondsSinceEpoch);

    if (!mounted) return;

    // Show the modal with the first promo item
    // You can implement logic to rotate through different promos
    final promo = promoData.first;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return PromoModal(
          imageUrl: promo['imageUrl']!,
          targetUrl: promo['targetUrl']!,
          onClose: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> fetchAds() async {
    try {
      final response = await ApiService().getHomeScreenAds();

      if (response.statusCode == 200) {
        final List<dynamic> adsData = json.decode(response.body);

        setState(() {
          priority1Ads = adsData
              .where((ad) => ad['prority'] == 1)
              .map((ad) => Map<String, dynamic>.from(ad))
              .toList();

          priority2Ads = adsData
              .where((ad) => ad['prority'] == 2)
              .map((ad) => Map<String, dynamic>.from(ad))
              .toList();

          // print('Priority 1 Ads: $priority1Ads');
          // print('Priority 2 Ads: $priority2Ads');

          isLoading = false;
        });
      } else {
        throw Exception('Failed to load ads: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in fetchAds: $e'); // Debug print
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading ads: $e')),
      );
    }
  }

  Future<void> _checkLocationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasLocation = prefs.containsKey('user_location');

    setState(() {
      _isLocationSaved = hasLocation;
      _savedLocation = prefs.getString('user_location') ?? '';
      _cityName = prefs.getString('city_name') ?? 'Unknown Location';
    });

    if (_isInitialLocationCheck && !hasLocation) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLocationAccessModal();
      });
      _isInitialLocationCheck = false;
    } else if (hasLocation && _cityName == 'Unknown Location') {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        _showLocationAccessModal();
        return;
      }

      setState(() {
        isLoading = true;
      });

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      await _getAddressFromLatLng(position);
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Location services are disabled. Please enable the services'),
      ));
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Location permissions are permanently denied'),
      ));
      return false;
    }

    return true;
  }

  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      Placemark place = placemarks[0];
      setState(() {
        _cityName =
            place.locality ?? place.subAdministrativeArea ?? 'Unknown Location';
        _savedLocation = '${position.latitude},${position.longitude}';
        _isLocationSaved = true;
      });

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_location', _savedLocation);
      await prefs.setString('city_name', _cityName);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _requestLocation() async {
    try {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        _showLocationAccessModal();
        return;
      }

      await _getCurrentLocation();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to retrieve location: $e')),
      );
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Access Denied'),
          content: const Text(
              'Please enable location permissions in your device settings to use this feature.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showLocationAccessModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async =>
              false, // Prevent back button from closing modal
          child: Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.location_on, size: 100, color: Colors.green[700]),
                const SizedBox(height: 20),
                Text(
                  'Enable Location Access',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[900],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                Text(
                  'We need your location to provide personalized agricultural insights, weather updates, and local crop recommendations.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Set a default location or handle "Not Now" case
                        setState(() {
                          _cityName = 'Location Not Set';
                          _isLocationSaved = false;
                        });
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[100],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        'Not Now',
                        style: TextStyle(
                          color: Colors.red[800],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _requestLocation();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: const Text(
                        'Allow Access',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentIndex == 0
          ? HomeContent(
              priority1Ads: priority1Ads,
              priority2Ads: priority2Ads,
              isLoading: isLoading,
            )
          : _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF4CAF50),
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view),
              label: 'Feed',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.volunteer_activism_outlined),
              activeIcon: Icon(Icons.volunteer_activism),
              label: 'Crop Care',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.store_outlined),
              activeIcon: Icon(Icons.store),
              label: 'Reels',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  final List<Widget> _pages = [
    // const Center(child: Text('Home Page')),
    HomeContent(),
    const FeedPage(),
    ChatListScreen(),
    // ReelsPage(),
    // VideoPlayerScreen(),
    GovSchemesScreen(),
    // SubscriptionScreen(),
    // VideoHomeScreen(),
    const FarmerProfile()
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }
}

class HomeContent extends StatelessWidget {
  final List<Map<String, dynamic>> priority1Ads;
  final List<Map<String, dynamic>> priority2Ads;
  final bool isLoading;

  const HomeContent({
    super.key,
    this.priority1Ads = const [],
    this.priority2Ads = const [],
    this.isLoading = false,
  });

  Widget _buildWeatherItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return [
          SliverAppBar(
            expandedHeight: 180.0,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF4CAF50),
            flexibleSpace: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isCollapsed =
                    constraints.biggest.height <= kToolbarHeight + 30;
                final double currentHeight = constraints.biggest.height;
                final double maxHeight = 180.0;
                final double minHeight = kToolbarHeight + 30;

                return FlexibleSpaceBar(
                  background: Container(
                    color: const Color(0xFF4CAF50),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        DynamicHeader(isCollapsed: false),
                        if (currentHeight > minHeight)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildWeatherItem(
                                    Icons.thermostat, "Temp", "40 C"),
                                _buildWeatherItem(
                                    Icons.water_drop, "Humidity", "35%"),
                                _buildWeatherItem(
                                    Icons.cloud, "Cloud", "- - -"),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  titlePadding: EdgeInsets.zero,
                  title: isCollapsed
                      ? DynamicHeader(isCollapsed: true)
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
        ];
      },
      body: Container(
        color: const Color(0xFFF5F5F5),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    '🌱 Services!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF008336),
                    ),
                  ),
                ),
                const ServicesGrid(),
                const SizedBox(height: 9),
                if (isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  AdCarousel(ads: priority1Ads),

                // testonmial
                TestimonialSection(),
                // FacebookPostCard(
                //   username: "John Doe",
                //   profileImageUrl:
                //       "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSR7ahvb8aEN76vOIivqeFpa9_gBV5rZm2erw&s",
                //   postTime: "2 hours ago",
                //   postContent:
                //       "Check out this beautiful landscape! Check out this beautiful landscape!Check out this beautiful landscape!Check out this beautiful landscape!Check out this beautiful landscape!",
                //   mediaUrl:
                //       "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSR7ahvb8aEN76vOIivqeFpa9_gBV5rZm2erw&s",
                //   mediaType: MediaType.image,
                // ),
                AdCarousel(ads: priority2Ads),
                const SizedBox(height: 26),
                const Center(
                  child: Text(
                    'News',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF008336),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                MarathiNewsCard(
                  category: 'शेतीवृत्त',
                  title: 'कांदा दर घसरण्याचा धोका – कृषी तज्ज्ञांचे मत',
                  content:
                      'केंद्र सरकारने शेतकऱ्यांना जैविक शेतीकडे प्रोत्साहन देणारी योजना सुरू केली आहे. योजनेअंतर्गत जैविक खते व बियाणांवर ५०% अनुदान दिले जाणार आहे',
                  imageUrl:
                      'https://www.agriculturetoday.in/assets/img/upcoming-events/africa-agri-expo.jpg', // Replace with actual image URL
                  publishedDate: DateTime(2025, 11, 30),
                ),
                SizedBox(
                  height: 10,
                ),
                MarathiNewsCard(
                  category: 'शेतीवृत्त',
                  title: 'कांदा दर घसरण्याचा धोका ',
                  content:
                      'केंद्र सरकारने शेतकऱ्यांना जैविक शेतीकडे प्रोत्साहन देणारी योजना सुरू केली आहे.योजनेअंतर्गत जैविक खते व बियाणांवर ५०% अनुदान दिले जाणार आहे',
                  imageUrl:
                      'https://www.agriculturetoday.in/assets/img/upcoming-events/africa-agri-expo.jpg', // Replace with actual image URL
                  publishedDate: DateTime(2025, 11, 30),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(const MaterialApp(
    home: FarmerHomePage(),
  ));
}
