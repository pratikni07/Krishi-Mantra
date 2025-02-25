import 'package:flutter/material.dart';
import 'package:krishi_doctor/Pages/components/KrishiMantraPost.dart';

class KrishiMantraFeed extends StatefulWidget {
  const KrishiMantraFeed({Key? key}) : super(key: key);

  @override
  _KrishiMantraFeedState createState() => _KrishiMantraFeedState();
}

class _KrishiMantraFeedState extends State<KrishiMantraFeed> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _posts = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPosts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _loadMorePosts();
    }
  }

  Future<void> _loadPosts() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate API call with delay
    await Future.delayed(const Duration(seconds: 2));

    // Demo data
    final List<Map<String, dynamic>> demoData = [
      {
        'farmerName': 'Ramesh Patel',
        'profileImage': 'https://randomuser.me/api/portraits/men/1.jpg',
        'postTime': '2 hours ago',
        'postContent': 'My wheat crop is showing great progress this season. The recent rainfall has really helped with the growth. Looking forward to a good harvest! #Farming #Wheat #Agriculture',
        'mediaUrls': [
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ2G-NiMZHWfE0Tmn5H7-dpnG0c84rrANXWRA&s',
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ2G-NiMZHWfE0Tmn5H7-dpnG0c84rrANXWRA&s',
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcQ2G-NiMZHWfE0Tmn5H7-dpnG0c84rrANXWRA&s',
        ],
        'location': 'Pune, Maharashtra',
        'cropType': 'Wheat',
        'likes': 45,
        'comments': 12,
        'shares': 5,
      },
      {
        'farmerName': 'Anita Sharma',
        'profileImage': 'https://randomuser.me/api/portraits/women/2.jpg',
        'postTime': '5 hours ago',
        'postContent': 'Successfully implemented drip irrigation in my sugarcane field. This has helped reduce water consumption by 40%. Happy to share my experience with fellow farmers! #WaterConservation #Sugarcane',
        'mediaUrls': [
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR2rmfZjvadVIf3vUQdt3hRazwDq-MKEpkbXQ&s',
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR2rmfZjvadVIf3vUQdt3hRazwDq-MKEpkbXQ&s',
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR2rmfZjvadVIf3vUQdt3hRazwDq-MKEpkbXQ&s',
           'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR2rmfZjvadVIf3vUQdt3hRazwDq-MKEpkbXQ&s',
            'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR2rmfZjvadVIf3vUQdt3hRazwDq-MKEpkbXQ&s',
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR2rmfZjvadVIf3vUQdt3hRazwDq-MKEpkbXQ&s',
          'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcR2rmfZjvadVIf3vUQdt3hRazwDq-MKEpkbXQ&s',
        ],
        'location': 'Kolhapur, Maharashtra',
        'cropType': 'Sugarcane',
        'likes': 78,
        'comments': 23,
        'shares': 15,
      },
      {
        'farmerName': 'Rajesh Kumar',
        'profileImage': 'https://randomuser.me/api/portraits/men/3.jpg',
        'postTime': '1 day ago',
        'postContent': 'Organic farming workshop today! Learning new techniques for pest control without chemicals. Great turnout from local farmers. Contact me if you want to know more about organic farming methods.',
        'mediaUrls': [
          'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
        ],
        'location': 'Nashik, Maharashtra',
        'cropType': 'Mixed ',
        'likes': 156,
        'comments': 45,
        'shares': 32,
      },
    ];

    setState(() {
      _posts = demoData;
      _isLoading = false;
    });
  }

  Future<void> _loadMorePosts() async {
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call with delay
      await Future.delayed(const Duration(seconds: 2));

      // Add more demo posts
      final List<Map<String, dynamic>> morePosts = [
        {
          'farmerName': 'Priya Desai',
          'profileImage': 'https://randomuser.me/api/portraits/women/4.jpg',
          'postTime': '2 days ago',
          'postContent': 'First time trying vertical farming for vegetables. Amazing space utilization and better yield! #VerticalFarming #Innovation',
          'mediaUrls': [
            'https://example.com/vertical1.jpg',
            'https://example.com/vertical2.jpg',
          ],
          'location': 'Thane, Maharashtra',
          'cropType': 'Vegetables',
          'likes': 92,
          'comments': 28,
          'shares': 12,
        },
      ];

      setState(() {
        _posts.addAll(morePosts);
        _isLoading = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Krishi Mantra Feed',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Implement search functionality
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {
              // Implement filter functionality
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _isLoading && _posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                controller: _scrollController,
                itemCount: _posts.length + 1,
                itemBuilder: (context, index) {
                  if (index == _posts.length) {
                    return _isLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : const SizedBox.shrink();
                  }

                  final post = _posts[index];
                  return KrishiMantraPost(
                    farmerName: post['farmerName'],
                    profileImage: post['profileImage'],
                    postTime: post['postTime'],
                    postContent: post['postContent'],
                    mediaUrls: List<String>.from(post['mediaUrls']),
                    location: post['location'],
                    cropType: post['cropType'],
                    likes: post['likes'],
                    comments: post['comments'],
                    shares: post['shares'],
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to create post screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        backgroundColor: Colors.green,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({Key? key}) : super(key: key);

  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final List<String> _selectedImages = [];
  String _selectedCropType = '';
  String _location = '';

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    // Implement image picking functionality
  }

  Future<void> _submitPost() async {
    // Implement post submission
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: Colors.green,
        actions: [
          TextButton(
            onPressed: _submitPost,
            child: const Text(
              'Post',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Share your farming experience...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.image),
              label: const Text('Add Photos'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedImages
                    .map((image) => Image.network(
                          image,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}