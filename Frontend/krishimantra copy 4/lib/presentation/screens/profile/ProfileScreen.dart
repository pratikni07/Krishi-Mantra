import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/colors.dart';
import '../../../data/services/UserService.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/auth_controller.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final AuthController _authController = Get.find<AuthController>();
  late LanguageService _languageService;
  Map<String, dynamic>? userData;
  bool isLoading = true;

  // Translatable text
  String profileText = 'Profile';
  String experienceText = 'Experience';
  String yearsText = 'years';
  String ratingText = 'Rating';
  String emailText = 'Email';
  String phoneText = 'Phone';
  String locationText = 'Location';
  String subscriptionText = 'Subscription';
  String notSpecifiedText = 'Not specified';
  String logoutText = 'Logout';
  String editProfileText = 'Edit Profile';
  String postsText = 'Posts';
  String commentsText = 'Comments';
  String likesText = 'Likes';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeLanguage();
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('Profile'),
      _languageService.translate('Experience'),
      _languageService.translate('years'),
      _languageService.translate('Rating'),
      _languageService.translate('Email'),
      _languageService.translate('Phone'),
      _languageService.translate('Location'),
      _languageService.translate('Subscription'),
      _languageService.translate('Not specified'),
      _languageService.translate('Logout'),
      _languageService.translate('Edit Profile'),
      _languageService.translate('Posts'),
      _languageService.translate('Comments'),
      _languageService.translate('Likes'),
    ]);

    setState(() {
      profileText = translations[0];
      experienceText = translations[1];
      yearsText = translations[2];
      ratingText = translations[3];
      emailText = translations[4];
      phoneText = translations[5];
      locationText = translations[6];
      subscriptionText = translations[7];
      notSpecifiedText = translations[8];
      logoutText = translations[9];
      editProfileText = translations[10];
      postsText = translations[11];
      commentsText = translations[12];
      likesText = translations[13];
    });
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      final user = await _userService.getUser();
      if (user != null) {
        setState(() {
          userData = user.toJson();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsiveness
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final paddingTop = mediaQuery.padding.top;
    final isSmallScreen = screenWidth < 360;
    
    // Calculate dynamic sizes
    final appBarHeight = screenHeight * 0.28;
    final profileImageSize = isSmallScreen ? 80.0 : 90.0;
    final cardPadding = isSmallScreen ? 12.0 : 16.0;
    final textScaleFactor = mediaQuery.textScaleFactor;
    final titleFontSize = isSmallScreen ? 18.0 : 22.0;
    
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.green,
          ),
        ),
      );
    }

    final String fullName = '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}';
    final String userType = userData?['accountType']?.toUpperCase() ?? '';
    final String location = userData?['additionalDetails']?['address'] ?? notSpecifiedText;
    final String subscriptionType = userData?['additionalDetails']?['subscription']?['type'] ?? 'FREE';
    final String experience = userData?['additionalDetails']?['experience']?.toString() ?? '0';
    final String rating = userData?['additionalDetails']?['rating']?.toString() ?? '0';

    // Mock statistics - replace with real data when available
    final int postsCount = userData?['stats']?['posts'] ?? 5;
    final int commentsCount = userData?['stats']?['comments'] ?? 12;
    final int likesCount = userData?['stats']?['likes'] ?? 28;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar with Profile Image
          SliverAppBar(
            expandedHeight: appBarHeight,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.green,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Get.back(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: false,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.green,
                          AppColors.green.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                  
                  // Profile image and name
                  Positioned(
                    top: paddingTop + 60,
                    left: cardPadding + 4,
                    child: Row(
                      children: [
                        // Profile Image with border
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: profileImageSize / 2,
                            backgroundColor: Colors.white,
                            child: userData?['image'] != null
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: userData!['image'],
                                      fit: BoxFit.cover,
                                      width: profileImageSize - 4,
                                      height: profileImageSize - 4,
                                      placeholder: (context, url) => const CircularProgressIndicator(
                                        color: AppColors.green,
                                        strokeWidth: 2,
                                      ),
                                      errorWidget: (context, url, error) => const Icon(
                                        Icons.person,
                                        size: 40,
                                        color: AppColors.green,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: AppColors.green,
                                  ),
                          ),
                        ),
                        SizedBox(width: 15),
                        // Name and type
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20 / textScaleFactor,
                              ),
                            ),
                            Text(
                              userType,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w400,
                                fontSize: 14 / textScaleFactor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: cardPadding, 
                vertical: isSmallScreen ? 8 : 12
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics row
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: EdgeInsets.all(cardPadding),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(postsText, postsCount.toString(), isSmallScreen),
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.grey[300],
                        ),
                        _buildStatItem(commentsText, commentsCount.toString(), isSmallScreen),
                        Container(
                          height: 40,
                          width: 1,
                          color: Colors.grey[300],
                        ),
                        _buildStatItem(likesText, likesCount.toString(), isSmallScreen),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 16),
                  
                  // Contact Information
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Contact Info',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        const Divider(),
                        _buildProfileInfoItem(Icons.email, emailText, userData?['email'] ?? ''),
                        _buildProfileInfoItem(Icons.phone, phoneText, userData?['phoneNo']?.toString() ?? ''),
                        _buildProfileInfoItem(Icons.location_on, locationText, location),
                      ],
                    ),
                  ),

                  // Subscription Info
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Account Info',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.grey[800],
                            ),
                          ),
                        ),
                        const Divider(),
                        _buildProfileInfoItem(Icons.card_membership, subscriptionText, subscriptionType),
                        if (userData?['accountType'] == 'consultant') ...[
                          _buildProfileInfoItem(Icons.work, experienceText, '$experience $yearsText'),
                          _buildProfileInfoItem(Icons.star, ratingText, '$rating/5'),
                        ],
                      ],
                    ),
                  ),

                  // Edit Profile Button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement edit profile functionality
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 54),
                      ),
                      child: Text(
                        editProfileText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // Logout Button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: ElevatedButton(
                      onPressed: () async {
                        // Show confirmation dialog
                        Get.dialog(
                          AlertDialog(
                            title: Text('Logout'),
                            content: Text('Are you sure you want to logout?'),
                            actions: [
                              TextButton(
                                onPressed: () => Get.back(),
                                child: Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Get.back();
                                  await _authController.logout();
                                },
                                child: Text(
                                  'Logout',
                                  style: TextStyle(color: Colors.red[400]),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 54),
                      ),
                      child: Text(
                        logoutText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isSmallScreen) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: AppColors.green,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 12 : 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.green,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
