import 'package:flutter/material.dart';
import 'package:krishi_mantra/screens/features/videosScreen/VideoProfileScreen.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({Key? key}) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isAdPlaying = true;
  bool _isLiked = false;
  bool _isSaved = false;

  // Demo data
  final Map<String, dynamic> videoData = {
    'title': 'Modern Irrigation Techniques for Better Yield',
    'views': '45K views',
    'uploadDate': '2 weeks ago',
    'channelName': 'Modern Farming Tips',
    'subscribers': '120K subscribers',
    'description':
        'Learn about the latest irrigation techniques that can help improve your crop yield. This video covers drip irrigation, sprinkler systems, and smart irrigation controllers.',
    'likes': '2.5K',
    'comments': [
      {
        'user': 'John Smith',
        'comment': 'This helped me improve my farm\'s efficiency!',
        'time': '3 days ago',
        'likes': '45'
      },
      {
        'user': 'Maria Garcia',
        'comment':
            'Great tips! Would love to see more content on organic farming.',
        'time': '1 week ago',
        'likes': '32'
      }
    ]
  };

  final List<Map<String, String>> relatedVideos = [
    {
      'title': 'Organic Pest Control Methods',
      'views': '32K views',
      'time': '1 week ago',
      'thumbnail': 'assets/pest_control.jpg'
    },
    {
      'title': 'Soil Testing Guide for Farmers',
      'views': '28K views',
      'time': '3 days ago',
      'thumbnail': 'assets/soil_testing.jpg'
    }
  ];

  @override
  void initState() {
    super.initState();
    // Initialize video controller with a demo video URL
    _controller = VideoPlayerController.network(
      'http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    )..initialize().then((_) {
        setState(() {});
        // Start with ad
        Future.delayed(Duration(seconds: 5), () {
          setState(() {
            _isAdPlaying = false;
            _controller.play();
          });
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video Player Section
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    if (_isAdPlaying)
                      Container(
                        color: Colors.black54,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Advertisement',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20),
                            ),
                            Text(
                              'Skip in 5 seconds',
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Video Info Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      videoData['title'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '${videoData['views']} • ${videoData['uploadDate']}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(
                          icon: _isLiked
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          label: videoData['likes'],
                          onTap: () => setState(() => _isLiked = !_isLiked),
                          isSelected: _isLiked,
                        ),
                        _buildActionButton(
                          icon: Icons.comment_outlined,
                          label: '${videoData['comments'].length}',
                          onTap: () {},
                        ),
                        _buildActionButton(
                          icon: _isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          label: 'Save',
                          onTap: () => setState(() => _isSaved = !_isSaved),
                          isSelected: _isSaved,
                        ),
                        _buildActionButton(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: () {},
                        ),
                      ],
                    ),

                    Divider(thickness: 1),

                    // Channel Info
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.green[700],
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => VideoProfileScreen()),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  videoData['channelName'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  videoData['subscribers'],
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {},
                          child: Text('Subscribe'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.green[700],
                          ),
                        ),
                      ],
                    ),

                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        videoData['description'],
                        style: TextStyle(color: Colors.grey[800]),
                      ),
                    ),

                    Divider(thickness: 1),

                    // Comments Section
                    Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: videoData['comments'].length,
                      itemBuilder: (context, index) {
                        final comment = videoData['comments'][index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey[300],
                                child: Icon(Icons.person,
                                    size: 20, color: Colors.grey[600]),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          comment['user'],
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          comment['time'],
                                          style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    Text(comment['comment']),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.thumb_up_outlined, size: 16),
                                        SizedBox(width: 4),
                                        Text(comment['likes']),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    Divider(thickness: 1),

                    // Related Videos Section
                    Text(
                      'Related Videos',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: relatedVideos.length,
                      itemBuilder: (context, index) {
                        final video = relatedVideos[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 120,
                                height: 70,
                                color: Colors.grey[300],
                                child: Center(child: Icon(Icons.play_arrow)),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video['title']!,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      '${video['views']} • ${video['time']}',
                                      style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.green[700] : Colors.grey[700],
            ),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.green[700] : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
