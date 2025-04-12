import 'package:flutter/material.dart';
import 'package:get/get.dart';

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

  Widget _buildProfileItem(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultantInfo() {
    if (userData?['accountType'] != 'consultant')
      return const SizedBox.shrink();

    return Column(
      children: [
        _buildProfileItem(experienceText,
            '${userData?['additionalDetails']?['experience'] ?? 0} $yearsText'),
        _buildProfileItem(
            ratingText, '${userData?['additionalDetails']?['rating'] ?? 0}/5'),
      ],
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              await _authController.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              logoutText,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.green,
          ),
        ),
      );
    }

    final String location =
        userData?['additionalDetails']?['address'] ?? notSpecifiedText;
    final String subscriptionType =
        userData?['additionalDetails']?['subscription']?['type'] ?? 'FREE';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        elevation: 0,
        title: Text(
          profileText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              // TODO: Implement edit functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            if (userData?['image'] != null)
              CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage(userData!['image']),
              )
            else
              const CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.green,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
            const SizedBox(height: 16),
            Text(
              '${userData?['firstName']} ${userData?['lastName']}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              userData?['accountType']?.toUpperCase() ?? '',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildProfileItem(emailText, userData?['email'] ?? ''),
                  _buildProfileItem(phoneText, '${userData?['phoneNo'] ?? ''}'),
                  _buildProfileItem(locationText, location),
                  _buildProfileItem(subscriptionText, subscriptionType),
                  _buildConsultantInfo(),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildLogoutButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
