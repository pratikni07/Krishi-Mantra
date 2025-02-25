// feed_detail_screen.dart
import 'dart:convert';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:krishi_mantra/API/FeedScreenAPI.dart';
import 'package:krishi_mantra/screens/components/PostCard.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:krishi_mantra/services/storage_service.dart';

class FeedDetailScreen extends StatefulWidget {
  final String username;
  final String profileImageUrl;
  final String postTime;
  final String postContent;
  final List<String>? mediaUrls;
  final MediaType mediaType;
  final int likes;
  final int comments;
  final String feedId;

  const FeedDetailScreen({
    Key? key,
    required this.username,
    required this.profileImageUrl,
    required this.postTime,
    required this.postContent,
    this.mediaUrls,
    required this.mediaType,
    required this.likes,
    required this.comments,
    required this.feedId,
  }) : super(key: key);

  @override
  _FeedDetailScreenState createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends State<FeedDetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ApiService _apiService = ApiService();
  final List<Comment> _comments = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();
  int _currentImageIndex = 0;
  bool _isReplying = false;
  String? _replyingToUsername;
  String? _replyingToCommentId;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _setupScrollController();
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMoreComments();
      }
    });
  }

  Future<void> _loadComments() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getComments(widget.feedId, 1, 10);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> commentsData = data['docs'] ?? [];

        // Don't show error if there are no comments
        if (commentsData.isEmpty) {
          setState(() {
            _comments.clear();
            _hasMore = false;
            _currentPage = 1;
          });
          return;
        }

        final List<Comment> comments =
            commentsData.map((comment) => Comment.fromJson(comment)).toList();

        setState(() {
          _comments.clear();
          _comments.addAll(comments);
          _hasMore = data['hasNextPage'] ?? false;
          _currentPage = data['page'] ?? 1;
        });
      }
    } catch (e) {
      print('Error loading comments: $e');
      // Only show error if it's not an empty response
      if (_comments.isNotEmpty) {
        _showErrorSnackbar('Failed to load comments');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreComments() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response =
          await _apiService.getComments(widget.feedId, _currentPage + 1, 10);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> commentsData = data['docs'];
        final List<Comment> newComments =
            commentsData.map((comment) => Comment.fromJson(comment)).toList();

        setState(() {
          _comments.addAll(newComments);
          _hasMore = data['hasNextPage'] ?? false;
          _currentPage = data['page'] ?? 1;
        });
      }
    } catch (e) {
      print('Error loading more comments: $e'); // Add this for debugging
      _showErrorSnackbar('Failed to load more comments');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final userData = await StorageService.getUserData();

      if (userData == null) {
        print('Error: User data is null');
        _showErrorSnackbar('User data not found');
        return;
      }

      // Debug: Log comment data being prepared
      final commentData = {
        'userId': userData['_id'],
        'userName': userData['name'],
        'profilePhoto': userData['image'] ?? 'default_profile_image_url',
        'content': _commentController.text,
      };

      final response =
          await _apiService.commentOnFeed(widget.feedId, commentData);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _commentController.clear();
        await _loadComments();
      } else {
        print('Failed to post comment. Status code: ${response.statusCode}');
        print('Error response: ${response.body}');
        _showErrorSnackbar('Failed to post comment');
      }
    } catch (e, stackTrace) {
      // Debug: Log detailed error information
      print('Error posting comment: $e');
      print('Stack trace: $stackTrace');
      _showErrorSnackbar('Failed to post comment');
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title:
            const Text('Post Details', style: TextStyle(color: Colors.black)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              children: [
                _buildPostHeader(),
                _buildPostContent(),
                if (widget.mediaUrls != null && widget.mediaUrls!.isNotEmpty)
                  _buildMediaCarousel(),
                _buildPostActions(),
                _buildCommentsSection(),
              ],
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(widget.profileImageUrl),
            radius: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      widget.username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Text(
                        'FOLLOW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.postTime,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Text(
        widget.postContent,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }

  Widget _buildMediaCarousel() {
    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 250,
            viewportFraction: 1.0,
            enableInfiniteScroll: false,
            onPageChanged: (index, reason) {
              setState(() {
                _currentImageIndex = index;
              });
            },
          ),
          items: widget.mediaUrls!.map((url) {
            return Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: Image.network(
                url,
                fit: BoxFit.cover,
              ),
            );
          }).toList(),
        ),
        if (widget.mediaUrls!.length > 1)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DotsIndicator(
              dotsCount: widget.mediaUrls!.length,
              position: _currentImageIndex,
              decorator: DotsDecorator(
                activeColor: Theme.of(context).primaryColor,
                size: const Size.square(8.0),
                activeSize: const Size(20.0, 8.0),
                activeShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5.0),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPostActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Icon(Icons.favorite_border, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            widget.likes.toString(),
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(width: 16),
          Icon(Icons.bookmark_border, color: Colors.grey[600]),
          const SizedBox(width: 16),
          Icon(Icons.share, color: Colors.grey[600]),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '(${_comments.length})',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No comments yet. Be the first to comment!',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ..._comments.map((comment) => _buildCommentTile(comment)),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentTile(Comment comment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundImage: NetworkImage(comment.userProfilePhoto),
                radius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      comment.content,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _formatCommentTime(comment.timestamp),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _initiateReply(comment),
                          child: Text(
                            'Reply',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.replies.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildRepliesSection(comment),
          ],
        ],
      ),
    );
  }

  Widget _buildRepliesSection(Comment comment) {
    final displayedReplies = comment.replies.take(2).toList();
    final hasMoreReplies = comment.replies.length > 2;

    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 2,
                  height: 24,
                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  'Replies (${comment.replies.length})',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ...displayedReplies.map((reply) => _buildReplyTile(reply)),
          if (hasMoreReplies)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: GestureDetector(
                onTap: () {
                  // Implement view more replies logic
                  // You can navigate to a new screen or expand the list
                },
                child: Text(
                  'View ${comment.replies.length - 2} more replies',
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_isReplying)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to @${_replyingToUsername}',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _cancelReply,
                    child: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText:
                        _isReplying ? 'Write a reply...' : 'Write a comment...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _isReplying ? _postReply : _postComment,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _initiateReply(Comment comment) {
    setState(() {
      _isReplying = true;
      _replyingToUsername = comment.userName;
      _replyingToCommentId = comment.id;
      _commentController.text = '@${comment.userName} ';
    });
    // Focus on the text field
    FocusScope.of(context).requestFocus(FocusNode());
  }

  void _cancelReply() {
    setState(() {
      _isReplying = false;
      _replyingToUsername = null;
      _replyingToCommentId = null;
      _commentController.clear();
    });
  }

  Future<void> _postReply() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      final userData = await StorageService.getUserData();

      if (userData == null) {
        _showErrorSnackbar('User data not found');
        return;
      }

      final replyData = {
        'userId': userData['_id'],
        'userName': userData['name'],
        'profilePhoto': userData['image'] ?? 'default_profile_image_url',
        'content': _commentController.text,
        'parentCommentId': _replyingToCommentId,
      };

      final response =
          await _apiService.commentOnFeed(widget.feedId, replyData);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _commentController.clear();
        _cancelReply();
        await _loadComments();
      } else {
        _showErrorSnackbar('Failed to post reply');
      }
    } catch (e, stackTrace) {
      print('Error posting reply: $e');
      print('Stack trace: $stackTrace');
      _showErrorSnackbar('Failed to post reply');
    }
  }

  Widget _buildReplyTile(Reply reply) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 2,
            height: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reply.userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reply.content,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCommentTime(reply.timestamp),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCommentTime(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
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
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String userProfilePhoto;
  final String content;
  final DateTime timestamp;
  final List<Reply> replies; // Add this

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userProfilePhoto,
    required this.content,
    required this.timestamp,
    required this.replies, // Add this
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // Handle replies
    List<Reply> repliesList = [];
    if (json['replies'] != null) {
      repliesList = (json['replies'] as List)
          .map((reply) => Reply.fromJson(reply))
          .toList();
    }

    return Comment(
      id: json['_id'],
      userId: json['userId'],
      userName: json['userName'],
      userProfilePhoto: json['profilePhoto'],
      content: json['content'],
      timestamp: DateTime.parse(json['createdAt']),
      replies: repliesList,
    );
  }
}

// Add Reply model
class Reply {
  final String id;
  final String userName;
  final String content;
  final DateTime timestamp;

  Reply({
    required this.id,
    required this.userName,
    required this.content,
    required this.timestamp,
  });

  factory Reply.fromJson(Map<String, dynamic> json) {
    return Reply(
      id: json['_id'],
      userName: json['userName'],
      content: json['content'],
      timestamp: DateTime.parse(json['createdAt']),
    );
  }
}
