import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishi_doctor/Pages/components/VideoUploadPage.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
      ),
      home: ReelsPage(),
    );
  }
}

class ReelsPage extends StatefulWidget {
  @override
  _ReelsPageState createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final List<Map<String, String>> reelsData = [
    {
      'videoUrl': 'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      'caption': 'Exploring innovative farming techniques that revolutionize agricultural productivity and sustainability. Learn how modern technology and traditional knowledge can work together to create more efficient and eco-friendly farming practices. 🚜🌱 #ModernFarming #Sustainability #AgriculturalInnovation',
      'username': 'Pratik Nikat',
      'location': 'Baramati',
      'profileImage': 'https://randomuser.me/api/portraits/men/1.jpg',
      'likes': '1.2k',
      'comments': '256',
      'reelUrl': 'https://example.com/reel/farmer1'
    },
    {
      'videoUrl': 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
      'caption': 'Organic farming in progress! Discover the secrets of sustainable agriculture and how we can protect our environment while producing nutritious food. 🌾 Follow our journey towards a greener future! #OrganicFarming #Sustainability #EcoAgriculture',
      'username': 'Anish Patil',
      'location': 'Satara',
      'profileImage': 'https://randomuser.me/api/portraits/men/2.jpg',
      'likes': '890',
      'comments': '124',
      'reelUrl': 'https://example.com/reel/farmer2'
    }
  ];

  late PageController _pageController;
  VideoPlayerController? _videoController;
  int currentPage = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _isFullCaptionVisible = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeVideoPlayer(reelsData[0]['videoUrl']!);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _initializeVideoPlayer(String url) {
    _videoController?.dispose();

    _videoController = VideoPlayerController.network(url)
      ..initialize().then((_) {
        setState(() {});
        _videoController?.play();
        _videoController?.setLooping(true);
      }).catchError((error) {
        print('Video initialization error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load video. Check your internet connection.')),
        );
      });
  }

  void _onPageChanged(int index) {
    setState(() {
      currentPage = index;
      _videoController?.pause();
      _initializeVideoPlayer(reelsData[index]['videoUrl']!);
      _isFullCaptionVisible = false;
    });
  }

  void _showFullCaptionModal(String caption) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Caption',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Text(
              caption,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showCommentsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Comments',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Omkar Pawar'),
                      subtitle: Text('छान माहिती दिली आहे! माझ्या शेतीसाठी खूप उपयोगी ठरेल.'),
                    ),
                    ListTile(
                      leading: CircleAvatar(child: Icon(Icons.person)),
                      title: Text('Anish Patil'),
                      subtitle: Text('हे औषध फवारणीसाठी कोणत्या प्रमाणात वापरायचं?'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.send),
                      onPressed: () {
                        if (_commentController.text.isNotEmpty) {
                          // Implement comment sending logic
                          print('Sending comment: ${_commentController.text}');
                          _commentController.clear();
                        }
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

  void _showShareModal(Map<String, String> reel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share Reel',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      reel['reelUrl']!,
                      style: TextStyle(color: Colors.green[900]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.copy, color: Colors.green[800]),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: reel['reelUrl']!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Reel URL copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSharePlatformButton(
                  icon: Icons.facebook,
                  color: Colors.green,
                  label: 'WhatsApp',
                ),
                _buildSharePlatformButton(
                  icon: Icons.facebook,
                  color: Colors.blue,
                  label: 'Facebook',
                ),
                _buildSharePlatformButton(
                  icon: Icons.camera_alt,
                  color: Colors.pink,
                  label: 'Instagram',
                ),
                _buildSharePlatformButton(
                  icon: Icons.sms,
                  color: Colors.purple,
                  label: 'SMS',
                ),
              ],
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSharePlatformButton({
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: IconButton(
            icon: Icon(icon, color: color),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sharing via $label')),
              );
            },
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }

@override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: reelsData.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final reel = reelsData[index];
          return Stack(
            fit: StackFit.expand,
            children: [
              _videoController?.value.isInitialized ?? false
                  ? VideoPlayer(_videoController!)
                  : Center(child: CircularProgressIndicator()),
              
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black12.withOpacity(0.3),
                        Colors.black45.withOpacity(0.6),
                      ],
                    ),
                  ),
                ),
              ),

              // Top Right Upload Reel Icon
              Positioned(
                top: 40,
                right: 16,
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.camera_alt_outlined, color: Colors.white, size: 28),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => VideoUploadPage()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile section 
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundImage: NetworkImage(reel['profileImage']!),
                          ),
                          SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reel['username']!,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                reel['location']!,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      // Caption with See More
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final textPainter = TextPainter(
                            text: TextSpan(
                              text: reel['caption']!,
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            maxLines: 2,
                            textDirection: TextDirection.ltr,
                          )..layout(maxWidth: constraints.maxWidth);

                          final isTextOverflowing = textPainter.didExceedMaxLines;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reel['caption']!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              if (isTextOverflowing)
                                GestureDetector(
                                  onTap: () => _showFullCaptionModal(reel['caption']!),
                                  child: Text(
                                    'See More',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border, 
                            color: _isLiked ? Colors.red : Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _isLiked = !_isLiked;
                            });
                          },
                        ),
                      ),
                      Text(reel['likes']!, style: TextStyle(color: Colors.white)),
                      SizedBox(height: 16),
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: Icon(Icons.comment, color: Colors.white),
                          onPressed: _showCommentsModal,
                        ),
                      ),
                      Text(reel['comments']!, style: TextStyle(color: Colors.white)),
                      SizedBox(height: 16),
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: Icon(Icons.share, color: Colors.white),
                          onPressed: () => _showShareModal(reel),
                        ),
                      ),
                      SizedBox(height: 16),
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: Icon(
                            _isBookmarked ? Icons.bookmark : Icons.bookmark_border, 
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() {
                              _isBookmarked = !_isBookmarked;
                            });
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      // Additional icons
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: Icon(Icons.not_interested, color: Colors.white),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Not Interested')),
                            );
                          },
                        ),
                      ),
                      SizedBox(height: 16),
                      CircleAvatar(
                        backgroundColor: Colors.black45,
                        child: IconButton(
                          icon: Icon(Icons.report_problem_outlined, color: Colors.white),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Report Reel')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}