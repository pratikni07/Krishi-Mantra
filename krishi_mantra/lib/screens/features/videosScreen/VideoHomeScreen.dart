import 'package:flutter/material.dart';

class VideoHomeScreen extends StatefulWidget {
  const VideoHomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<VideoHomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showAppBar = true;
  bool _showCategories = true;
  double _lastOffset = 0;

  final List<Map<String, dynamic>> categories = [
    {
      'icon': Icons.agriculture,
      'name': 'Crop Tips',
      'color': Colors.green[700]
    },
    {'icon': Icons.water_drop, 'name': 'Irrigation', 'color': Colors.blue[700]},
    {
      'icon': Icons.pest_control,
      'name': 'Pest Control',
      'color': Colors.orange[700]
    },
    {'icon': Icons.grass, 'name': 'Organic', 'color': Colors.teal[700]},
    {
      'icon': Icons.device_thermostat,
      'name': 'Weather',
      'color': Colors.purple[700]
    },
    {'icon': Icons.shopping_cart, 'name': 'Market', 'color': Colors.red[700]},
  ];

  final List<Map<String, dynamic>> videos = [
    {
      'thumbnail': 'assets/video1.jpg',
      'title': 'Modern Irrigation Techniques for Better Yield',
      'channel': 'Modern Farming Tips',
      'views': '45K views',
      'time': '2 weeks ago',
      'duration': '10:25',
      'verified': true
    },
    {
      'thumbnail': 'assets/video2.jpg',
      'title': 'Organic Pest Control Methods That Actually Work',
      'channel': 'Organic Farming Guide',
      'views': '32K views',
      'time': '1 week ago',
      'duration': '15:30',
      'verified': true
    },
    {
      'thumbnail': 'assets/video3.jpg',
      'title': 'Best Practices for Rice Cultivation',
      'channel': 'Rice Farming Expert',
      'views': '28K views',
      'time': '3 days ago',
      'duration': '12:45',
      'verified': false
    },
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    double currentOffset = _scrollController.offset;
    if (currentOffset > _lastOffset && currentOffset > 10) {
      // Scrolling down
      if (_showAppBar || _showCategories) {
        setState(() {
          _showAppBar = false;
          _showCategories = false;
        });
      }
    } else if (currentOffset < _lastOffset) {
      // Scrolling up
      if (!_showAppBar || !_showCategories) {
        setState(() {
          _showAppBar = true;
          _showCategories = true;
        });
      }
    }
    _lastOffset = currentOffset;
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Animated App Bar
            AnimatedContainer(
              duration: Duration(milliseconds: 200),
              height: _showAppBar ? kToolbarHeight : 0,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 200),
                opacity: _showAppBar ? 1.0 : 0.0,
                child: AppBar(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  title: Row(
                    children: [
                      Icon(Icons.agriculture,
                          color: Colors.green[700], size: 32),
                      SizedBox(width: 8),
                      Text(
                        'FarmTube',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.cast, color: Colors.grey[700]),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Icons.notifications_outlined,
                          color: Colors.grey[700]),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),

            // Search Bar (Always visible)
            Container(
              color: Colors.white,
              padding: EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search farming videos...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  suffixIcon: Icon(Icons.mic, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                ),
              ),
            ),

            // Animated Categories
            AnimatedContainer(
              duration: Duration(milliseconds: 200),
              height: _showCategories ? 120 : 0,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 200),
                opacity: _showCategories ? 1.0 : 0.0,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: category['color']?.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Icon(
                                category['icon'],
                                color: category['color'],
                                size: 30,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              category['name'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Videos List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(8),
                itemBuilder: (context, index) {
                  final video = videos[index % videos.length];
                  return InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, '/video-player');
                    },
                    child: Card(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          // Thumbnail
                          Stack(
                            children: [
                              Container(
                                height: 200,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(12),
                                  ),
                                ),
                                child: Center(
                                  child: Icon(Icons.play_arrow,
                                      size: 50, color: Colors.white),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    video['duration'],
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Video Info
                          Padding(
                            padding: EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.green[700],
                                  child:
                                      Icon(Icons.person, color: Colors.white),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        video['title'],
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            video['channel'],
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          if (video['verified'])
                                            Padding(
                                              padding: EdgeInsets.only(left: 4),
                                              child: Icon(
                                                Icons.check_circle,
                                                size: 14,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                        ],
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        '${video['views']} • ${video['time']}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.more_vert),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
          _buildNavItem(1, Icons.grid_view_outlined, Icons.grid_view, 'Feed'),
          _buildNavItem(2, Icons.eco_outlined, Icons.eco, 'Crop Care'),
          _buildNavItem(
              3, Icons.play_circle_outline, Icons.play_circle, 'Reels'),
          _buildNavItem(4, Icons.person_outline, Icons.person, 'Profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(
      int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = currentIndex == index;
    return InkWell(
      onTap: () => onTap(index),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? Colors.green[700] : Colors.grey[600],
              size: 24,
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.green[700] : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
