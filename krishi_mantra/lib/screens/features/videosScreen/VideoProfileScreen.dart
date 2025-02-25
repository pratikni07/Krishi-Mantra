import 'package:flutter/material.dart';

class VideoProfileScreen extends StatefulWidget {
  const VideoProfileScreen({Key? key}) : super(key: key);

  @override
  _VideoProfileScreenState createState() => _VideoProfileScreenState();
}

class _VideoProfileScreenState extends State<VideoProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isSubscribed = false;

  // Demo data for the profile
  final Map<String, dynamic> profileData = {
    'channelName': 'Modern Farming Tips',
    'subscriberCount': '120K',
    'videoCount': '156',
    'totalViews': '2.5M',
    'joinDate': 'Joined Jan 2022',
    'description':
        'Welcome to Modern Farming Tips! We share the latest agricultural techniques, sustainable farming practices, and expert advice to help farmers improve their yield and efficiency. Join our community of modern farmers!',
    'location': 'California, USA',
    'email': 'contact@modernfarmingtips.com',
    'links': {
      'Website': 'www.modernfarmingtips.com',
      'Instagram': '@modernfarmingtips',
      'Twitter': '@modernfarming'
    },
    'videos': [
      {
        'title': 'Modern Irrigation Techniques',
        'views': '45K views',
        'time': '2 weeks ago',
        'duration': '15:24'
      },
      {
        'title': 'Organic Pest Control Methods',
        'views': '32K views',
        'time': '1 week ago',
        'duration': '12:18'
      },
      {
        'title': 'Soil Testing Guide',
        'views': '28K views',
        'time': '3 days ago',
        'duration': '18:45'
      }
    ]
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 200.0,
              floating: false,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  children: [
                    // Banner Image
                    Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.green.shade800,
                            Colors.green.shade500
                          ],
                        ),
                      ),
                    ),
                    // Profile Image Overlay
                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.green[700],
                          child:
                              Icon(Icons.person, size: 40, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profileData['channelName'],
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${profileData['subscriberCount']} subscribers • ${profileData['videoCount']} videos',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _isSubscribed = !_isSubscribed;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isSubscribed
                                ? Colors.grey[300]
                                : Colors.green[700],
                            foregroundColor:
                                _isSubscribed ? Colors.black : Colors.white,
                          ),
                          child:
                              Text(_isSubscribed ? 'Subscribed' : 'Subscribe'),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat('Videos', profileData['videoCount']),
                        _buildStat(
                            'Subscribers', profileData['subscriberCount']),
                        _buildStat('Views', profileData['totalViews']),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.green[700],
                  unselectedLabelColor: Colors.grey[600],
                  tabs: [
                    Tab(text: 'VIDEOS'),
                    Tab(text: 'ABOUT'),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildVideosTab(),
            _buildAboutTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildVideosTab() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: profileData['videos'].length,
      itemBuilder: (context, index) {
        final video = profileData['videos'][index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(child: Icon(Icons.play_arrow)),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    margin: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      video['duration'],
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video['title'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${video['views']} • ${video['time']}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAboutTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(profileData['description']),
          SizedBox(height: 24),
          Text(
            'Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          _buildDetailItem(Icons.location_on, profileData['location']),
          _buildDetailItem(Icons.email, profileData['email']),
          _buildDetailItem(Icons.calendar_today, profileData['joinDate']),
          SizedBox(height: 24),
          Text(
            'Links',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          ...profileData['links']
              .entries
              .map((entry) => _buildLinkItem(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildLinkItem(String platform, String link) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.link, size: 20, color: Colors.blue),
          SizedBox(width: 8),
          Text(
            '$platform: ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            link,
            style: TextStyle(color: Colors.blue),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
