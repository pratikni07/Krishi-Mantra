import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:carousel_slider/carousel_slider.dart';

// Crop Calendar Entry Model
class CropCalendarEntry {
  final int month;
  final String activity;
  final String description;
  final List<String> recommendations;

  CropCalendarEntry({
    required this.month,
    required this.activity,
    required this.description,
    required this.recommendations,
  });
}

// Updated Crop Model
class Crop {
  final String id;
  final String name;
  final String imageUrl;
  final String description;
  final List<CropCalendarEntry> cropCalendar;

  Crop({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.description,
    required this.cropCalendar,
  });
}

// Crop Data
class CropData {
  static List<Crop> getCrops() {
    return [
      Crop(
        id: '1',
        name: 'Tomato',
        imageUrl:
            'https://media.istockphoto.com/id/1132371208/photo/three-ripe-tomatoes-on-green-branch.jpg?s=612x612&w=0&k=20&c=qVjDb5Tk3-UccV-E9gqvoz97PTsP1QmBftw27qA9kEo=',
        description:
            'A versatile and nutritious fruit-vegetable that grows well in warm climates and is packed with vitamins and antioxidants.',
        cropCalendar: [
          CropCalendarEntry(
            month: 1,
            activity: 'Seed Preparation',
            description: 'Initial preparation for tomato cultivation',
            recommendations: [
              'Select high-quality seeds',
              'Prepare seed trays with nutrient-rich soil',
              'Maintain soil temperature around 70-80°F',
            ],
          ),
          CropCalendarEntry(
            month: 2,
            activity: 'Seeding & Nursery',
            description: 'Start seeds indoors or in a greenhouse',
            recommendations: [
              'Sow seeds in seed trays',
              'Provide adequate moisture',
              'Ensure 6-8 hours of indirect sunlight',
            ],
          ),
          CropCalendarEntry(
            month: 3,
            activity: 'Transplanting',
            description: 'Move seedlings to main field',
            recommendations: [
              'Harden off seedlings before transplanting',
              'Space plants 18-36 inches apart',
              'Use well-draining, fertile soil',
            ],
          ),
          CropCalendarEntry(
            month: 4,
            activity: 'Growth & Fertilization',
            description: 'Support plant growth and nutrition',
            recommendations: [
              'Apply balanced fertilizer (NPK 5-10-10)',
              'Install support stakes or cages',
              'Mulch around plants to retain moisture',
            ],
          ),
          CropCalendarEntry(
            month: 5,
            activity: 'Flowering & Pollination',
            description: 'Encourage flower and fruit formation',
            recommendations: [
              'Ensure consistent watering',
              'Remove any diseased or yellowing leaves',
              'Monitor for pest activity',
            ],
          ),
          CropCalendarEntry(
            month: 6,
            activity: 'Fruit Development',
            description: 'Support fruit growth and quality',
            recommendations: [
              'Continue regular fertilization',
              'Prune suckers for better air circulation',
              'Protect from extreme heat',
            ],
          ),
          CropCalendarEntry(
            month: 7,
            activity: 'Harvesting',
            description: 'Collect ripe tomatoes',
            recommendations: [
              'Harvest when fruits are fully colored',
              'Pick every 2-3 days',
              'Store in cool, dry place',
            ],
          ),
        ],
      )
    ];
  }
}

class CropCalendarScreen extends StatefulWidget {
  const CropCalendarScreen({super.key});

  @override
  _CropCalendarScreenState createState() => _CropCalendarScreenState();
}

class _CropCalendarScreenState extends State<CropCalendarScreen> {
  Crop currentCrop = CropData.getCrops().first;

  // List of additional crop images (you can replace with your actual crop images)
  final List<String> additionalCropImages = [
    'https://media.istockphoto.com/id/1132371208/photo/three-ripe-tomatoes-on-green-branch.jpg?s=612x612&w=0&k=20&c=qVjDb5Tk3-UccV-E9gqvoz97PTsP1QmBftw27qA9kEo=',
    'https://media.istockphoto.com/id/1132371208/photo/three-ripe-tomatoes-on-green-branch.jpg?s=612x612&w=0&k=20&c=qVjDb5Tk3-UccV-E9gqvoz97PTsP1QmBftw27qA9kEo=',
    'https://media.istockphoto.com/id/1132371208/photo/three-ripe-tomatoes-on-green-branch.jpg?s=612x612&w=0&k=20&c=qVjDb5Tk3-UccV-E9gqvoz97PTsP1QmBftw27qA9kEo=',
    'https://media.istockphoto.com/id/1132371208/photo/three-ripe-tomatoes-on-green-branch.jpg?s=612x612&w=0&k=20&c=qVjDb5Tk3-UccV-E9gqvoz97PTsP1QmBftw27qA9kEo=',
    'https://media.istockphoto.com/id/1132371208/photo/three-ripe-tomatoes-on-green-branch.jpg?s=612x612&w=0&k=20&c=qVjDb5Tk3-UccV-E9gqvoz97PTsP1QmBftw27qA9kEo=',
    'https://media.istockphoto.com/id/1132371208/photo/three-ripe-tomatoes-on-green-branch.jpg?s=612x612&w=0&k=20&c=qVjDb5Tk3-UccV-E9gqvoz97PTsP1QmBftw27qA9kEo=',
    'https://media.istockphoto.com/id/1132371208/photo/three-ripe-tomatoes-on-green-branch.jpg?s=612x612&w=0&k=20&c=qVjDb5Tk3-UccV-E9gqvoz97PTsP1QmBftw27qA9kEo=',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F4F4),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 30),

                // Main Crop Image
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(
                        image: NetworkImage(currentCrop.imageUrl),
                        fit: BoxFit.cover,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 10),
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Crop Name
                Text(
                  currentCrop.name,
                  style: GoogleFonts.montserrat(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),

                const SizedBox(height: 10),

                // Crop Description
                Text(
                  currentCrop.description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 30),

                // Crop Calendar
                _buildCropCalendar(),

                const SizedBox(height: 30),

                // Additional Crop Images Grid
                _buildCropImagesGrid(),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCropCalendar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Crop Calendar',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.teal[800],
          ),
        ),
        const SizedBox(height: 15),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: currentCrop.cropCalendar.length,
            separatorBuilder: (context, index) => Divider(
              color: Colors.grey[200],
              height: 1,
            ),
            itemBuilder: (context, index) {
              final entry = currentCrop.cropCalendar[index];
              return Theme(
                data: ThemeData(
                  dividerColor: Colors.transparent,
                  unselectedWidgetColor: Colors.teal[700],
                ),
                child: ExpansionTile(
                  title: Text(
                    'Month ${entry.month}: ${entry.activity}',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      color: Colors.teal[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    entry.description,
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: entry.recommendations.map((recommendation) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.teal[700],
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    recommendation,
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCropImagesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Explore More Crops',
          style: GoogleFonts.montserrat(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.teal[800],
          ),
        ),
        const SizedBox(height: 15),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1, // Ensures square images
          ),
          itemCount: additionalCropImages.length,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: NetworkImage(additionalCropImages[index]),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
