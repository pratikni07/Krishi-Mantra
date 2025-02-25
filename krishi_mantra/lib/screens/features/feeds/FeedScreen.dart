import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:krishi_mantra/API/FeedScreenAPI.dart';
import 'package:krishi_mantra/screens/components/PostCard.dart';
import 'package:krishi_mantra/screens/features/feeds/FeedUploadModal.dart';
import 'package:krishi_mantra/screens/features/feeds/model/feed_post.dart';
import 'package:krishi_mantra/services/storage_service.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  _FeedPageState createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  final List<FeedPost> _posts = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;
  String? _userId;
  String? _userName;
  String? _userProfilePhoto;
  String? _userRole;
  bool _canCreatePost = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _setupScrollController();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final accountType = await StorageService.getAccountType();
    setState(() {
      _canCreatePost = accountType == 'consultant' || accountType == 'admin';
    });
  }

  void _showUploadModal() {
    if (!_canCreatePost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only consultants and admins can create posts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FeedUploadModal(
        onUpload: _handleFeedUpload,
      ),
    );
  }

  Future<void> _handleFeedUpload(Map<String, dynamic> postData) async {
    try {
      final response = await _apiService.createFeed(postData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post uploaded successfully!')),
        );
        _loadInitialPosts(); // Refresh the feed
      } else {
        throw Exception('Failed to upload post');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading post: $e')),
      );
    }
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await StorageService.getUserData();
      if (userData != null) {
        setState(() {
          _userId = userData['_id'] as String?;
          _userName = userData['name'] as String?;
          _userProfilePhoto = userData['image'] as String?;
        });
        await _loadInitialPosts();
      } else {
        _showErrorSnackbar('User data not found');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load user data');
    }
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMorePosts();
      }
    });
  }

  Future<void> _loadInitialPosts() async {
    if (_isLoading || _userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getRecommendedFeeds(
        _userId!,
        1,
        10,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> feedsData = data['feeds'];
        final List<FeedPost> posts =
            feedsData.map((post) => FeedPost.fromJson(post)).toList();

        setState(() {
          _posts.clear();
          _posts.addAll(posts);
          _hasMore = data['pagination']['hasMore'] ?? false;
          _currentPage = data['pagination']['currentPage'] ?? 1;
        });

        for (var post in posts) {
          _recordInteraction(post.id, 'view');
        }
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load posts');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore || _userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getRecommendedFeeds(
        _userId!,
        _currentPage + 1,
        10,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> feedsData = data['feeds'];
        final List<FeedPost> newPosts =
            feedsData.map((post) => FeedPost.fromJson(post)).toList();

        setState(() {
          _posts.addAll(newPosts);
          _hasMore = data['pagination']['hasMore'] ?? false;
          _currentPage = data['pagination']['currentPage'] ?? _currentPage + 1;
        });

        for (var post in newPosts) {
          _recordInteraction(post.id, 'view');
        }
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load more posts');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLike(String postId, bool isLiked) async {
    if (_userId == null || _userName == null || _userProfilePhoto == null)
      return;

    try {
      final response = await _apiService.likeFeed(
        postId,
        {
          'userId': _userId,
          'userName': _userName,
          'profilePhoto': _userProfilePhoto,
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          final postIndex = _posts.indexWhere((post) => post.id == postId);
          if (postIndex != -1) {
            final post = _posts[postIndex];
            final newLikeCount =
                isLiked ? post.like.count + 1 : post.like.count - 1;
            _posts[postIndex] = FeedPost(
              id: post.id,
              userId: post.userId,
              userName: post.userName,
              profilePhoto: post.profilePhoto,
              description: post.description,
              content: post.content,
              mediaUrl: post.mediaUrl,
              like: LikeInfo(count: newLikeCount),
              comment: post.comment,
              location: post.location,
              date: post.date,
              recentComments: post.recentComments,
            );
          }
        });

        _recordInteraction(postId, 'like');
      } else {
        _showErrorSnackbar('Failed to update like');
      }
    } catch (e) {
      _showErrorSnackbar('Failed to update like');
    }
  }

  Future<void> _recordInteraction(String postId, String interactionType) async {
    try {
      await _apiService.postUserInteraction({
        'postId': postId,
        'interactionType': interactionType,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // print('Error recording interaction: $e');
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Farm Feed',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialPosts,
        child: _posts.isEmpty && !_isLoading
            ? _buildEmptyState()
            : _buildFeedList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.feed_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No posts available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadInitialPosts,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedList() {
    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _posts.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _posts.length) {
          return _buildLoadingIndicator();
        }

        final post = _posts[index];

        List<String>? mediaUrls;
        if (post.mediaUrl != null && post.mediaUrl!.isNotEmpty) {
          mediaUrls = [post.mediaUrl!];
        }
        return FacebookPostCard(
          username: post.userName,
          profileImageUrl: post.profilePhoto,
          postTime: _formatPostTime(post.date),
          postContent: post.content,
          mediaUrls: mediaUrls,
          mediaType: post.mediaType,
          likes: post.like.count,
          comments: post.comment.count,
          shares: 0, // Not included in your API response
          key: ValueKey(post.id),
          postId: post.id,
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32.0),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
        ),
      ),
    );
  }

  String _formatPostTime(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);

    if (difference.inDays > 7) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
