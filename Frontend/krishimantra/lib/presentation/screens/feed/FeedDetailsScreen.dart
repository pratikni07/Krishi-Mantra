// feed_details_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'widgets/media_content.dart';
import 'widgets/post_header.dart';
import 'widgets/post_content.dart';
import 'widgets/post_actions.dart';
import 'widgets/comments_section.dart';
import 'widgets/comment_input.dart';
import '../../../data/models/comment_modal.dart';
import '../../controllers/feed_controller.dart';

class FeedDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> feed;

  const FeedDetailsScreen({
    Key? key,
    required this.feed,
  }) : super(key: key);

  @override
  State<FeedDetailsScreen> createState() => _FeedDetailsScreenState();
}

class _FeedDetailsScreenState extends State<FeedDetailsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FeedController _feedController = Get.find<FeedController>();
  bool _isReplying = false;
  String? _replyingToUsername;
  String? _replyingToCommentId;

  @override
  void initState() {
    super.initState();
    if (widget.feed['id'] != null || widget.feed['_id'] != null) {
      _loadComments();
    }
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadComments() async {
    try {
      final feedId = widget.feed['id'] ?? widget.feed['_id'];
      if (feedId != null) {
        await _feedController.getComments(feedId, refresh: true);
      } else {
        Get.snackbar(
          'Error',
          'Unable to load comments: Invalid feed ID',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load comments: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      final feedId = widget.feed['id'] ?? widget.feed['_id'];
      if (feedId != null &&
          !_feedController.isLoadingComments.value &&
          _feedController.hasMoreComments.value) {
        _feedController.getComments(feedId);
      }
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final content = _commentController.text;
    final feedId = widget.feed['id'] ?? widget.feed['_id'];

    if (feedId == null) {
      Get.snackbar(
        'Error',
        'Unable to add comment: Invalid feed ID',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    _commentController.clear();

    try {
      await _feedController.addComment(
        feedId,
        content,
        parentCommentId: _isReplying ? _replyingToCommentId : null,
      );

      if (_isReplying) {
        _cancelReply();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to add comment: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _initiateReply(CommentModel comment) {
    setState(() {
      _isReplying = true;
      _replyingToUsername = comment.userName;
      _replyingToCommentId = comment.id;
    });
    _commentController.text = '@${comment.userName} ';
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
        title: const Text(
          'Post Details',
          style: TextStyle(color: Colors.black),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              controller: _scrollController,
              children: [
                PostHeader(feed: widget.feed),
                PostContent(feed: widget.feed),
                if (widget.feed['mediaUrl'] != null)
                  MediaContent(mediaUrl: widget.feed['mediaUrl']),
                PostActions(feed: widget.feed),
                CommentsSection(
                  feedController: _feedController,
                  onReply: _initiateReply,
                ),
              ],
            ),
          ),
          CommentInput(
            commentController: _commentController,
            isReplying: _isReplying,
            replyingToUsername: _replyingToUsername,
            onSubmit: _submitComment,
            onCancelReply: _cancelReply,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
