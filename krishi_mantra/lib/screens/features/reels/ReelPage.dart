import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishi_mantra/API/ReelScreenAPI.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  _ReelsPageState createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  late PageController _pageController;
  VideoPlayerController? _videoController;
  final TextEditingController _commentController = TextEditingController();
  bool _isLiked = false;
  bool _isBookmarked = false;
  bool _isLoading = false;
  bool _hasMoreReels = true;
  int _currentPage = 1;
  Timer? _throttleTimer;
  List<dynamic> reels = [];
  List<dynamic> trendingTags = [];
  String? selectedTag;
  bool _showFullDescription = false;
  List<dynamic> comments = [];
  bool isLoadingComments = false;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadInitialData();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent),
    );
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchReels(),
      _fetchTrendingTags(),
    ]);
  }

  Future<void> _fetchReels({bool refresh = false}) async {
    if (_isLoading || (!_hasMoreReels && !refresh)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getReels(
        page: refresh ? 1 : _currentPage,
        limit: 10,
      );

      final jsonResponse = json.decode(response.body);
      if (jsonResponse['status'] == 'success') {
        final data = jsonResponse['data']['data'] as List;
        final pagination = jsonResponse['data']['pagination'];

        setState(() {
          if (refresh) {
            reels = data;
            _currentPage = 1;
          } else {
            reels.addAll(data);
            _currentPage++;
          }

          _hasMoreReels = pagination['hasNextPage'];

          if (reels.isNotEmpty && _videoController == null) {
            _initializeVideoPlayer(reels[0]['mediaUrl']);
          }
        });
      }
    } catch (e) {
      print('Error fetching reels: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTrendingTags() async {
    try {
      final response = await _apiService.getTrendingTags();
      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (jsonResponse['status'] == 'success') {
        setState(() {
          trendingTags = jsonResponse['data'] as List;
        });
      }
    } catch (e) {
      print('Error fetching trending tags: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load trending tags'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _fetchReelsByTag(String tagName) async {
    setState(() {
      _isLoading = true;
      selectedTag = tagName;
    });

    try {
      final response = await _apiService.getReelsByTag(tagName);
      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (jsonResponse['status'] == 'success') {
        setState(() {
          reels = jsonResponse['data'] as List;
          if (reels.isNotEmpty) {
            _pageController.jumpToPage(0);
            _initializeVideoPlayer(reels[0]['mediaUrl']);
          }
        });
      }
    } catch (e) {
      print('Error fetching reels by tag: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load reels for this tag'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _shareReel(String reelId) {
    Share.share(
        'Check out this amazing reel! http://yourapp.com/reels/$reelId');
  }

  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
          child: Text(
            'Trending',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: trendingTags.length,
            itemBuilder: (context, index) {
              final tag = trendingTags[index];
              final isSelected = selectedTag == tag['name'];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Material(
                  color: isSelected ? Colors.blue : Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      if (!isSelected) {
                        _fetchReelsByTag(tag['name']);
                      } else {
                        setState(() {
                          selectedTag = null;
                        });
                        _fetchReels(refresh: true);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Text(
                        '#${tag['name']}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReelDescription(Map<String, dynamic> reel) {
    final description = reel['description'] as String;
    final hashtags = RegExp(r'#\w+').allMatches(description);
    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (var hashtag in hashtags) {
      if (hashtag.start > lastIndex) {
        spans.add(TextSpan(
          text: description.substring(lastIndex, hashtag.start),
          style: const TextStyle(color: Colors.white),
        ));
      }
      spans.add(TextSpan(
        text: description.substring(hashtag.start, hashtag.end),
        style: const TextStyle(color: Colors.blue),
      ));
      lastIndex = hashtag.end;
    }

    if (lastIndex < description.length) {
      spans.add(TextSpan(
        text: description.substring(lastIndex),
        style: const TextStyle(color: Colors.white),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(children: spans),
          maxLines: _showFullDescription ? null : 2,
          overflow: _showFullDescription
              ? TextOverflow.visible
              : TextOverflow.ellipsis,
        ),
        if (description.length > 100)
          GestureDetector(
            onTap: () {
              setState(() {
                _showFullDescription = !_showFullDescription;
              });
            },
            child: Text(
              _showFullDescription ? 'Show less' : 'Show more',
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInteractionButtons(Map<String, dynamic> reel) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildInteractionButton(
          icon: _isLiked ? Icons.favorite : Icons.favorite_border,
          color: _isLiked ? Colors.red : Colors.white,
          count: reel['like']['count'],
          onTap: () {
            setState(() => _isLiked = !_isLiked);
          },
        ),
        const SizedBox(height: 16),
        _buildInteractionButton(
          icon: Icons.comment,
          color: Colors.white,
          count: reel['comment']['count'],
          onTap: () => _showCommentsModal(reel),
        ),
        const SizedBox(height: 16),
        _buildInteractionButton(
          icon: Icons.share,
          color: Colors.white,
          count: null,
          onTap: () => _shareReel(reel['_id']),
        ),
        const SizedBox(height: 16),
        _buildInteractionButton(
          icon: _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: Colors.white,
          count: null,
          onTap: () {
            setState(() => _isBookmarked = !_isBookmarked);
          },
        ),
      ],
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    int? count,
  }) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black45,
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 5,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: color),
            onPressed: onTap,
          ),
        ),
        if (count != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SafeArea(
            child: _buildTrendingSection(),
          ),
          Expanded(
            child: reels.isEmpty && _isLoading
                ? const Center(child: CircularProgressIndicator())
                : PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: reels.length + (_hasMoreReels ? 1 : 0),
                    onPageChanged: (index) {
                      if (index == reels.length - 2) {
                        _fetchReels();
                      }
                      if (index < reels.length) {
                        _videoController?.pause();
                        _initializeVideoPlayer(reels[index]['mediaUrl']);
                      }
                    },
                    itemBuilder: (context, index) {
                      if (index == reels.length) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final reel = reels[index];
                      return GestureDetector(
                        onDoubleTap: () {
                          setState(() => _isLiked = true);
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _videoController?.value.isInitialized ?? false
                                ? GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (_videoController!.value.isPlaying) {
                                          _videoController!.pause();
                                        } else {
                                          _videoController!.play();
                                        }
                                      });
                                    },
                                    child: VideoPlayer(_videoController!),
                                  )
                                : const Center(
                                    child: CircularProgressIndicator()),

                            // Gradient overlay
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // User profile and description
                            Positioned(
                              left: 16,
                              right: 80,
                              bottom: 16,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 24,
                                          backgroundImage: NetworkImage(
                                              reel['profilePhoto']),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              reel['userName'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            if (reel['location'] != null)
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.location_on,
                                                    color: Colors.white70,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${reel['location']['latitude']}, ${reel['location']['longitude']}',
                                                    style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildReelDescription(reel),
                                ],
                              ),
                            ),

                            // Interaction buttons
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: _buildInteractionButtons(reel),
                            ),

                            // Play/Pause indicator
                            if (!(_videoController?.value.isPlaying ?? true))
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 50,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showCommentsModal(Map<String, dynamic> reel) {
    _fetchComments(reel['_id']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isLoadingComments)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: isLoadingComments
                  ? const Center(child: CircularProgressIndicator())
                  : comments.isEmpty
                      ? const Center(
                          child: Text(
                            'No comments yet. Be the first to comment!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundImage: NetworkImage(
                                      comment['profilePhoto'],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              comment['userName'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _getTimeAgo(DateTime.parse(
                                                  comment['createdAt'])),
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          comment['content'],
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            TextButton.icon(
                                              onPressed: () {},
                                              icon: const Icon(
                                                Icons.favorite_border,
                                                size: 16,
                                              ),
                                              label: Text(
                                                comment['likes']['count']
                                                    .toString(),
                                                style: const TextStyle(
                                                    fontSize: 12),
                                              ),
                                            ),
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
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, 8 + MediaQuery.of(context).viewInsets.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage:
                        NetworkImage(defaultUserData['profilePhoto']!),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          _addComment(reel['_id'], value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      if (_commentController.text.isNotEmpty) {
                        _addComment(reel['_id'], _commentController.text);
                      }
                    },
                    child: const Text('Post'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'just now';
    }
  }

  Future<void> _addComment(String reelId, String content) async {
    if (_throttleTimer?.isActive ?? false) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.addComment(reelId, content);
      final jsonResponse = json.decode(response.body);

      if (jsonResponse['status'] == 'success') {
        _commentController.clear();
        await _fetchComments(reelId);

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment added successfully'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error adding comment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to add comment'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeVideoPlayer(String url) {
    _videoController?.dispose();
    setState(() {
      _isLoading = true;
    });

    _videoController = VideoPlayerController.network(
      url,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    )..initialize().then((_) {
        setState(() {
          _isLoading = false;
        });
        _videoController?.play();
        _videoController?.setLooping(true);
      }).catchError((error) {
        print('Video initialization error: $error');
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Unable to play video. Please try again later.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _initializeVideoPlayer(url),
            ),
          ),
        );
      });
  }

  Future<void> _fetchComments(String reelId) async {
    setState(() {
      isLoadingComments = true;
      comments = [];
    });

    try {
      final response = await _apiService.getComments(reelId);
      final Map<String, dynamic> jsonResponse = json.decode(response.body);

      if (jsonResponse['status'] == 'success') {
        setState(() {
          comments = jsonResponse['data'] as List;
          isLoadingComments = false;
        });
      }
    } catch (e) {
      print('Error fetching comments: $e');
      setState(() {
        isLoadingComments = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load comments'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _videoController?.dispose();
    _commentController.dispose();
    _throttleTimer?.cancel();
    super.dispose();
  }
}

final Map<String, String> defaultUserData = {
  "userId": "67554c6e9fd16ef80ae96828",
  "userName": "John Doe",
  "profilePhoto":
      "https://images.ctfassets.net/h6goo9gw1hh6/2sNZtFAWOdP1lmQ33VwRN3/24e953b920a9cd0ff2e1d587742a2472/1-intro-photo-final.jpg",
};
