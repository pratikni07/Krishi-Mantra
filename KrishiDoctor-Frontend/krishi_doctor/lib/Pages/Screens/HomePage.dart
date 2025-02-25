import 'package:flutter/material.dart';
import 'package:krishi_doctor/Pages/components/NewsCard.dart';
import 'package:krishi_doctor/Pages/components/PostCard.dart';
import 'package:krishi_doctor/Pages/components/TestimonialSection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class FarmerHomePage extends StatefulWidget {
  const FarmerHomePage({super.key});

  @override
  State<FarmerHomePage> createState() => _FarmerHomePageState();
}

class _FarmerHomePageState extends State<FarmerHomePage> {
  bool _isLocationSaved = false;
  String _savedLocation = '';

  @override
  void initState() {
    super.initState();
    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isLocationSaved = prefs.containsKey('user_location');
      _savedLocation = prefs.getString('user_location') ?? '';
    });

    if (!_isLocationSaved) {
      // Delay to ensure widget is built before showing dialog
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showLocationAccessModal();
      });
    }
  }

  Future<void> _requestLocation() async {
    // Check and request location permissions
    var status = await Permission.location.request();
    
    if (status.isGranted) {
      try {
        // Get current position
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        // Save location to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_location', 
          '${position.latitude},${position.longitude}'
        );

        // Update state
        setState(() {
          _isLocationSaved = true;
          _savedLocation = '${position.latitude},${position.longitude}';
        });

        // Close the modal
        Navigator.of(context).pop();
      } catch (e) {
        // Handle location retrieval error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to retrieve location: $e')),
        );
      }
    } else {
      // Handle permission denied
      _showPermissionDeniedDialog();
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Access Denied'),
          content: Text('Please enable location permissions in your device settings to use this feature.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: Text('Open Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(30),
        ),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.5,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
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
              // Location Icon
              Icon(
                Icons.location_on,
                size: 100,
                color: Colors.green[700],
              ),
              
              SizedBox(height: 20),
              
              // Title
              Text(
                'Enable Location Access',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 15),
              
              // Description
              Text(
                'We need your location to provide personalized agricultural insights, weather updates, and local crop recommendations.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 30),
              
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Deny Button
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[100],
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
                  
                  SizedBox(width: 20),
                  
                  // Allow Button
                  ElevatedButton(
                    onPressed: _requestLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Krishi Mantra'),
        backgroundColor: Colors.green,
        actions: [
          // Show saved location in app bar if available
          if (_isLocationSaved)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.white),
                  Text(
                    _savedLocation,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),

      body: Container(
        color: const Color(0xFFF5F5F5), // Background color of body
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Section
                const Center(
                  child: Text(
                    '🌱 Services!',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF008336), // Adding the green color
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                
                // Services Grid Section
              //  Container(
              //     padding: const EdgeInsets.all(10),
              //     decoration: BoxDecoration(
              //       color: const Color.fromARGB(255, 255, 255, 255),
              //       borderRadius: BorderRadius.circular(10),
              //       // border: Border.all(color: const Color(0xFF008336)),
              //     ),
              //     // height: MediaQuery.of(context).size.height * 0.3,
              //     child: GridView.builder(
              //       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              //         crossAxisCount: 4, 
              //         crossAxisSpacing: 8,
              //         mainAxisSpacing: 30, 
              //       ),
              //       itemCount: 8, 
              //       itemBuilder: (context, index) {
              //         return Column(
              //           mainAxisAlignment: MainAxisAlignment.center,
              //           children: [
              //             ClipOval(
              //               child: Image.network(
              //                 'https://thumbs.dreamstime.com/b/indian-farmer-empty-hand-product-putting-pointing-finger-174017270.jpg', 
              //                 width: 82, 
              //                 height: 82,
              //                 fit: BoxFit.cover,
              //               ),
              //             ),
              //             const SizedBox(height: 10),
              //             Text(
              //               'Image ${index + 1}',
              //               style: const TextStyle(
              //                 fontSize: 14,
              //                 fontWeight: FontWeight.bold,
              //                 color: const Color(0xFF008336),
              //               ),
              //             ),
              //           ],
              //         );
              //       },
              //       shrinkWrap: true, 
              //       physics: const NeverScrollableScrollPhysics(),
              //     ),
              //   ),

                const SizedBox(height: 16),

                // Ads Section 
                Container(
                  child: Image.network(
                          'https://yojnaias.com/wp-content/uploads/2023/04/PM-KISAN.png', 
                          fit: BoxFit.cover,
                  ),
                ),

          
                // TOP POST SECTION 

                // Testinomial 
                TestimonialSection(),

                // Example with an image
                const FacebookPostCard(
                  username: "John Doe",
                  profileImageUrl: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSR7ahvb8aEN76vOIivqeFpa9_gBV5rZm2erw&s",
                  postTime: "2 hours ago",
                  postContent: "Check out this beautiful landscape! Check out this beautiful landscape!Check out this beautiful landscape!Check out this beautiful landscape!Check out this beautiful landscape!",
                  mediaUrl: "https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSR7ahvb8aEN76vOIivqeFpa9_gBV5rZm2erw&s",
                  mediaType: MediaType.image,
                ),

                // // Example with a video
                // const FacebookPostCard(
                //   username: "Jane Smith",
                //   profileImageUrl: "https://images.ctfassets.net/h6goo9gw1hh6/2sNZtFAWOdP1lmQ33VwRN3/24e953b920a9cd0ff2e1d587742a2472/1-intro-photo-final.jpg?w=1200&h=992&fl=progressive&q=70&fm=jpg",
                //   postTime: "1 hour ago",
                //   postContent: "My latest travel vlog!",
                //   mediaUrl: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4",
                //   mediaType: MediaType.video,
                // ),

                // // Example without media
                // const FacebookPostCard(
                //   username: "User",
                //   profileImageUrl: "https://images.ctfassets.net/h6goo9gw1hh6/2sNZtFAWOdP1lmQ33VwRN3/24e953b920a9cd0ff2e1d587742a2472/1-intro-photo-final.jpg?w=1200&h=992&fl=progressive&q=70&fm=jpg",
                //   postTime: "Just now",
                //   postContent: "Just thinking out loud...",
                //   mediaType: MediaType.none,
                // ),
               
               // Ads Section 
                Container(
                  child: Image.network(
                          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcReOD9y7ioHCt1dsX7uX41otL_fIWZxgE6SPA&s', 
                          fit: BoxFit.cover,
                  ),
                ),
                

                const SizedBox(height: 26),
                //  News Section 
                const Center(
                  child: Text(
                    'News',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF008336), // Adding the green color
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                NewsCard(
                  title: 'Major Breakthrough in Renewable Energy Research',
                  imageUrl: 'https://images.hindustantimes.com/rf/image_size_960x540/HT/p2/2018/12/26/Pictures/files-india-weather-monsoon_b5f4a298-0917-11e9-8b39-01e96223c804.jpg',
                  content: 'Scientists at the University of Technology have developed a new type of solar panel that is 20% more efficient than traditional designs. This breakthrough could significantly reduce the cost of solar power and accelerate the transition to renewable energy.',
                  publishedDate: DateTime(2023, 5, 15),
                ),
                 NewsCard(
                  title: 'Major Breakthrough in Renewable Energy Research',
                  imageUrl: 'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRydbhrDtLoiZYJ8rHtmqTUqxJtxnmQr6i0Pg&s',
                  content: 'Scientists at the University of Technology have developed a new type of solar panel that is 20% more efficient than traditional designs. This breakthrough could significantly reduce the cost of solar power and accelerate the transition to renewable energy.',
                  publishedDate: DateTime(2023, 5, 15),
                ),




                // // Quick Actions Section
                // const Text(
                //   'Quick Actions',
                //   style: TextStyle(
                //     fontSize: 20,
                //     fontWeight: FontWeight.bold,
                //   ),
                // ),
                // const SizedBox(height: 8),
                // Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //   children: [
                //     ElevatedButton(
                //       onPressed: () {},
                //       style: ElevatedButton.styleFrom(
                //         backgroundColor: Colors.green,
                //       ),
                //       child: const Text('Buy Seeds'),
                //     ),
                //     ElevatedButton(
                //       onPressed: () {},
                //       style: ElevatedButton.styleFrom(
                //         backgroundColor: Colors.green,
                //       ),
                //       child: const Text('Sell Crops'),
                //     ),
                //     ElevatedButton(
                //       onPressed: () {},
                //       style: ElevatedButton.styleFrom(
                //         backgroundColor: Colors.green,
                //       ),
                //       child: const Text('Contact Expert'),
                //     ),
                //   ],
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: FarmerHomePage(),
  ));
}
