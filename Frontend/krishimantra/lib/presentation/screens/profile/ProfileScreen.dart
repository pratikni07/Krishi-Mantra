import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/services/UserService.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/subscription_controller.dart';
import '../../widgets/skeleton/skeleton_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final ApiService _apiService = Get.find<ApiService>();
  final AuthController _authController = Get.find<AuthController>();
  late SubscriptionController _subscriptionController;
  late LanguageService _languageService;
  Map<String, dynamic>? userData;
  bool isLoading = true;

  // User statistics
  int postsCount = 0;
  int commentsCount = 0;
  int likesCount = 0;

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
  String contactInfoText = 'Contact Info';
  String accountInfoText = 'Account Info';
  String logoutConfirmText = 'Are you sure you want to logout?';
  String cancelText = 'Cancel';
  String settingsText = 'Settings';
  String manageSubscriptionText = 'Manage Subscription';
  String currentPlanText = 'Current Plan';
  String expiresOnText = 'Expires on';
  String upgradePlanText = 'Upgrade Plan';
  String freeText = 'FREE';

  @override
  void initState() {
    super.initState();
    _subscriptionController = Get.find<SubscriptionController>();
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
      _languageService.translate('Contact Info'),
      _languageService.translate('Account Info'),
      _languageService.translate('Are you sure you want to logout?'),
      _languageService.translate('Cancel'),
      _languageService.translate('Settings'),
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
      contactInfoText = translations[14];
      accountInfoText = translations[15];
      logoutConfirmText = translations[16];
      cancelText = translations[17];
      settingsText = translations[18];
    });
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      final user = await _userService.getUser();
      if (user != null) {
        setState(() {
          userData = user.toJson();
        });
        // Fetch user statistics
        await _fetchUserStats(user.id);
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
    setState(() => isLoading = false);
  }

  Future<void> _fetchUserStats(String userId) async {
    try {
      final endpoint = ApiConstants.replacePathParams(
        ApiConstants.USER_STATS,
        {'userId': userId},
      );
      final response = await _apiService.get(endpoint);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final stats = response.data['data']['stats'];
        setState(() {
          postsCount = stats['posts'] ?? 0;
          commentsCount = stats['comments'] ?? 0;
          likesCount = stats['likes'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final paddingTop = MediaQuery.of(context).padding.top;

    // Calculate dynamic sizes using ResponsiveUtils
    final appBarHeight = ResponsiveUtils.hp(28);
    final profileImageSize = ResponsiveUtils.responsive(mobile: 80.0, tablet: 100.0);
    final cardPadding = AppSizes.paddingL;

    if (isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffoldBackground,
        body: const SkeletonProfileScreen(),
      );
    }

    final String fullName =
        '${userData?['firstName'] ?? ''} ${userData?['lastName'] ?? ''}';
    final String userType = userData?['accountType']?.toUpperCase() ?? '';
    final String location =
        userData?['additionalDetails']?['address'] ?? notSpecifiedText;
    final String subscriptionType =
        userData?['additionalDetails']?['subscription']?['type'] ?? 'FREE';
    final String experience =
        userData?['additionalDetails']?['experience']?.toString() ?? '0';
    final String rating =
        userData?['additionalDetails']?['rating']?.toString() ?? '0';

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
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
              icon: Icon(Icons.arrow_back, color: AppColors.white, size: AppSizes.iconM),
              onPressed: () => Get.back(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                '',
                style: TextStyle(
                  color: AppColors.white,
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
                    top: paddingTop + ResponsiveUtils.hp(8),
                    left: cardPadding + 4,
                    child: Row(
                      children: [
                        // Profile Image with border
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.white,
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: profileImageSize / 2,
                            backgroundColor: AppColors.white,
                            child: userData?['image'] != null
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: userData!['image'],
                                      fit: BoxFit.cover,
                                      width: profileImageSize - 4,
                                      height: profileImageSize - 4,
                                      placeholder: (context, url) =>
                                          CircularProgressIndicator(
                                        color: AppColors.green,
                                        strokeWidth: 2,
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Icon(
                                        Icons.person,
                                        size: AppSizes.iconXL,
                                        color: AppColors.green,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    size: AppSizes.iconXL,
                                    color: AppColors.green,
                                  ),
                          ),
                        ),
                        SizedBox(width: AppSizes.paddingL),
                        // Name and type
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: AppSizes.fontXL,
                              ),
                            ),
                            Text(
                              userType,
                              style: TextStyle(
                                color: AppColors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w400,
                                fontSize: AppSizes.fontS,
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
              padding: RPadding.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics row
                  Container(
                    margin: EdgeInsets.only(top: AppSizes.paddingS),
                    padding: RPadding.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowLight,
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(postsText, postsCount.toString()),
                        Container(
                          height: ResponsiveUtils.hp(5),
                          width: 1,
                          color: AppColors.borderLight,
                        ),
                        _buildStatItem(commentsText, commentsCount.toString()),
                        Container(
                          height: ResponsiveUtils.hp(5),
                          width: 1,
                          color: AppColors.borderLight,
                        ),
                        _buildStatItem(likesText, likesCount.toString()),
                      ],
                    ),
                  ),

                  SizedBox(height: AppSizes.paddingL),

                  // Contact Information
                  Container(
                    margin: EdgeInsets.symmetric(vertical: AppSizes.paddingS),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowLight,
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: RPadding.only(left: 16, top: 16, right: 16, bottom: 8),
                          child: Text(
                            contactInfoText,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: AppSizes.fontL,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                        const Divider(color: AppColors.divider),
                        _buildProfileInfoItem(
                            Icons.email, emailText, userData?['email'] ?? ''),
                        _buildProfileInfoItem(Icons.phone, phoneText,
                            userData?['phoneNo']?.toString() ?? ''),
                        _buildProfileInfoItem(
                            Icons.location_on, locationText, location),
                      ],
                    ),
                  ),

                  // Enhanced Subscription Section
                  Obx(() {
                    final subscription = _subscriptionController.currentSubscription.value;
                    final currentPlan = _subscriptionController.currentPlan.value;
                    final isFreePlan = _subscriptionController.isFreePlan.value;
                    
                    return Container(
                      margin: EdgeInsets.symmetric(vertical: AppSizes.paddingS),
                      decoration: BoxDecoration(
                        gradient: isFreePlan
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.green.withOpacity(0.1),
                                  AppColors.green.withOpacity(0.05),
                                ],
                              ),
                        color: isFreePlan ? AppColors.white : null,
                        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowLight,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: isFreePlan
                            ? null
                            : Border.all(
                                color: AppColors.green.withOpacity(0.3),
                                width: 1,
                              ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header with icon
                          Padding(
                            padding: RPadding.only(left: 16, top: 16, right: 16, bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: RPadding.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(AppSizes.radiusL),
                                      ),
                                      child: Icon(
                                        Icons.card_membership,
                                        color: AppColors.green,
                                        size: AppSizes.iconM,
                                      ),
                                    ),
                                    SizedBox(width: AppSizes.paddingM),
                                    Text(
                                      subscriptionText,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: AppSizes.fontL,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                  ],
                                ),
                                // Plan badge
                                Container(
                                  padding: RPadding.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isFreePlan
                                        ? AppColors.textGrey.withOpacity(0.1)
                                        : AppColors.green,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    currentPlan?.displayName ?? freeText,
                                    style: TextStyle(
                                      color: isFreePlan ? AppColors.textGrey : AppColors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: AppSizes.fontS,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(color: AppColors.divider),
                          
                          // Subscription details
                          if (!isFreePlan && subscription != null) ...[
                            Padding(
                              padding: RPadding.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: AppColors.green,
                                    size: AppSizes.iconS,
                                  ),
                                  SizedBox(width: AppSizes.paddingM),
                                  Text(
                                    '$expiresOnText: ',
                                    style: TextStyle(
                                      color: AppColors.textGrey,
                                      fontSize: AppSizes.fontM,
                                    ),
                                  ),
                                  Text(
                                    _formatDate(subscription.endDate),
                                    style: TextStyle(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.w600,
                                      fontSize: AppSizes.fontM,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: RPadding.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.repeat,
                                    color: AppColors.green,
                                    size: AppSizes.iconS,
                                  ),
                                  SizedBox(width: AppSizes.paddingM),
                                  Text(
                                    subscription.billingCycle == 'yearly' ? 'Yearly' : 'Monthly',
                                    style: TextStyle(
                                      color: AppColors.textDark,
                                      fontSize: AppSizes.fontM,
                                    ),
                                  ),
                                  if (subscription.autoRenew) ...[
                                    SizedBox(width: AppSizes.paddingM),
                                    Container(
                                      padding: RPadding.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        'Auto-renew',
                                        style: TextStyle(
                                          color: AppColors.green,
                                          fontSize: AppSizes.fontXS,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ] else ...[
                            Padding(
                              padding: RPadding.all(16),
                              child: Text(
                                'Upgrade to unlock premium features',
                                style: TextStyle(
                                  color: AppColors.textGrey,
                                  fontSize: AppSizes.fontM,
                                ),
                              ),
                            ),
                          ],
                          
                          // Manage Subscription Button
                          Padding(
                            padding: RPadding.all(16),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Get.toNamed('/subscription-plans');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFreePlan ? AppColors.green : AppColors.white,
                                  foregroundColor: isFreePlan ? AppColors.white : AppColors.green,
                                  elevation: 0,
                                  side: isFreePlan ? null : BorderSide(color: AppColors.green),
                                  padding: RPadding.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                                  ),
                                ),
                                child: Text(
                                  isFreePlan ? upgradePlanText : manageSubscriptionText,
                                  style: TextStyle(
                                    fontSize: AppSizes.fontM,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Consultant Info (if applicable)
                  if (userData?['accountType'] == 'consultant')
                    Container(
                      margin: EdgeInsets.symmetric(vertical: AppSizes.paddingS),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowLight,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: RPadding.only(left: 16, top: 16, right: 16, bottom: 8),
                            child: Text(
                              accountInfoText,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: AppSizes.fontL,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          const Divider(color: AppColors.divider),
                          _buildProfileInfoItem(Icons.work, experienceText,
                              '$experience $yearsText'),
                          _buildProfileInfoItem(
                              Icons.star, ratingText, '$rating/5'),
                        ],
                      ),
                    ),

                  // Edit Profile Button
                  Container(
                    width: double.infinity,
                    margin: RPadding.only(left: 16, top: 24, right: 16, bottom: 8),
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Implement edit profile functionality
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: AppColors.white,
                        padding: RPadding.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                        ),
                        minimumSize: Size(double.infinity, AppSizes.buttonHeight),
                      ),
                      child: Text(
                        editProfileText,
                        style: TextStyle(
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),

                  // Logout Button
                  Container(
                    width: double.infinity,
                    margin: RPadding.symmetric(horizontal: 16, vertical: 8),
                    child: OutlinedButton(
                      onPressed: () {
                        // Show logout confirmation dialog
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              backgroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                              ),
                              title: Text(
                                logoutText,
                                style: TextStyle(
                                  fontSize: AppSizes.fontL,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              content: Text(
                                logoutConfirmText,
                                style: TextStyle(
                                  fontSize: AppSizes.fontM,
                                  color: AppColors.textGrey,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    cancelText,
                                    style: TextStyle(
                                      color: AppColors.textGrey,
                                      fontWeight: FontWeight.w600,
                                      fontSize: AppSizes.fontM,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _authController.logout();
                                  },
                                  child: Text(
                                    logoutText,
                                    style: TextStyle(
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w600,
                                      fontSize: AppSizes.fontM,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.green),
                        padding: RPadding.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
                        ),
                      ),
                      child: Text(
                        logoutText,
                        style: TextStyle(
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ),

                  // Settings Button
                  Container(
                    width: double.infinity,
                    margin: RPadding.only(left: 16, top: 8, right: 16, bottom: 16),
                    child: TextButton.icon(
                      onPressed: () {
                        Get.toNamed('/settings');
                      },
                      icon: Icon(Icons.settings, color: AppColors.green, size: AppSizes.iconM),
                      label: Text(
                        settingsText,
                        style: TextStyle(
                          fontSize: AppSizes.fontL,
                          fontWeight: FontWeight.bold,
                          color: AppColors.green,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom padding
          SliverToBoxAdapter(
            child: SizedBox(height: AppSizes.paddingXXL),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: AppSizes.fontXL,
            fontWeight: FontWeight.bold,
            color: AppColors.green,
          ),
        ),
        SizedBox(height: AppSizes.paddingS),
        Text(
          label,
          style: TextStyle(
            fontSize: AppSizes.fontS,
            color: AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfoItem(IconData icon, String label, String value) {
    return Padding(
      padding: RPadding.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: RPadding.all(8),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSizes.radiusL),
            ),
            child: Icon(
              icon,
              color: AppColors.green,
              size: AppSizes.iconS,
            ),
          ),
          SizedBox(width: AppSizes.paddingL),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: AppSizes.fontS,
                  color: AppColors.textLight,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: AppSizes.fontL,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
