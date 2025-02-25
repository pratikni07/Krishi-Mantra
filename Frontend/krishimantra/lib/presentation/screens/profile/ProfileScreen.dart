import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';
import '../../../data/services/UserService.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
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
        _buildProfileItem('Experience',
            '${userData?['additionalDetails']?['experience'] ?? 0} years'),
        _buildProfileItem(
            'Rating', '${userData?['additionalDetails']?['rating'] ?? 0}/5'),
      ],
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
        userData?['additionalDetails']?['address'] ?? 'Not specified';
    final String subscriptionType =
        userData?['additionalDetails']?['subscription']?['type'] ?? 'FREE';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
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
                  _buildProfileItem('Email', userData?['email'] ?? ''),
                  _buildProfileItem('Phone', '${userData?['phoneNo'] ?? ''}'),
                  _buildProfileItem('Location', location),
                  _buildProfileItem('Subscription', subscriptionType),
                  _buildConsultantInfo(),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      await _userService.clearAllData();
                      // Navigate to login screen
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/login', // Replace with your login route name
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
