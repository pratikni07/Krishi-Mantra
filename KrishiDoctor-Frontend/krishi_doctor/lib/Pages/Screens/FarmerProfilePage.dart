import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryGreen = Color(0xFF4CAF50);  // Softer main green
  static const Color lightGreen = Color(0xFFE8F5E9);    // Very light green for backgrounds
  static const Color mediumGreen = Color(0xFF81C784);   // Medium shade for accents
  static const Color darkGreen = Color(0xFF388E3C);     // Darker green for text
  static const Color textGrey = Color(0xFF757575);      // For secondary text
  static const Color backgroundGrey = Color(0xFFF5F5F5); // Light grey background
}

class FarmerProfile extends StatefulWidget {
  const FarmerProfile({Key? key}) : super(key: key);

  @override
  State<FarmerProfile> createState() => _FarmerProfileState();
}

class _FarmerProfileState extends State<FarmerProfile> {
  final Map<String, dynamic> farmerData = {
    'name': 'John Smith',
    'age': 45,
    'location': 'Karnataka, India',
    'farmSize': '25 acres',
    'mainCrops': ['Rice', 'Wheat', 'Sugarcane'],
    'experience': '20 years',
    'phoneNumber': '+91 9876543210',
    'email': 'john.smith@email.com',
    'soilType': 'Black Soil',
    'irrigation': 'Drip Irrigation',
    'certifications': ['Organic Farming', 'Good Agricultural Practices'],
    'profileImage': 'https://example.com/profile.jpg',
    'rating': 4.8,
    'totalConsultations': 156,
    'successRate': '95%',
  };

  bool isEditing = false;
@override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGrey,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar with Profile Header
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryGreen,
                      AppColors.darkGreen,
                    ],
                    stops: [0.3, 1.0],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: const CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person, size: 80, color: AppColors.primaryGreen),
                          ),
                        ),
                        if (!isEditing)
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.verified, color: AppColors.primaryGreen, size: 28),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      farmerData['name'],
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          farmerData['location'],
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(isEditing ? Icons.save_rounded : Icons.edit_rounded),
                onPressed: () => setState(() => isEditing = !isEditing),
              ),
            ],
          ),

          // Stats Cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  _buildStatCard('Rating', '${farmerData['rating']}', Icons.star_rounded),
                  _buildStatCard('Consultations', '${farmerData['totalConsultations']}', Icons.people_rounded),
                  _buildStatCard('Success Rate', farmerData['successRate'], Icons.trending_up_rounded),
                ],
              ),
            ),
          ),

          // Main Content
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    'Personal Information',
                    Icons.person_outline_rounded,
                    [
                      _buildInfoTile('Age', '${farmerData['age']} years'),
                      _buildInfoTile('Phone', farmerData['phoneNumber']),
                      _buildInfoTile('Email', farmerData['email']),
                    ],
                  ),
                  const Divider(height: 1),
                  _buildSection(
                    'Farm Details',
                    Icons.landscape_rounded,
                    [
                      _buildInfoTile('Farm Size', farmerData['farmSize']),
                      _buildInfoTile('Soil Type', farmerData['soilType']),
                      _buildInfoTile('Irrigation System', farmerData['irrigation']),
                    ],
                  ),
                  const Divider(height: 1),
                  _buildSection(
                    'Main Crops',
                    Icons.grass_rounded,
                    [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (farmerData['mainCrops'] as List).map((crop) =>
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.lightGreen,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.mediumGreen),
                            ),
                            child: Text(
                              crop,
                              style: const TextStyle(
                                color: AppColors.darkGreen,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ).toList(),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  _buildSection(
                    'Certifications',
                    Icons.verified_rounded,
                    [
                      ...(farmerData['certifications'] as List).map((cert) =>
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.lightGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, 
                              color: AppColors.darkGreen, 
                              size: 20),
                          ),
                          title: Text(
                            cert,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ).toList(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Request Consultation Feature Coming Soon!')),
          );
        },
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.message_rounded),
        label: const Text('Consult Now'),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Expanded(
      child: Card(
        elevation: 4,
        shadowColor: Colors.black26,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGreen,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primaryGreen, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}