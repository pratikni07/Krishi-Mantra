// feed_details_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/language_service.dart';
import 'widgets/media_content.dart';
import 'widgets/post_header.dart';
import 'widgets/post_content.dart';
import 'widgets/post_actions.dart';
import 'widgets/comments_section.dart';
import 'widgets/comment_input.dart';
import '../../../data/models/comment_modal.dart';
import '../../controllers/feed_controller.dart';
import '../../widgets/video_player_widget.dart';
import '../../../core/utils/error_handler.dart';

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
  late LanguageService _languageService;
  bool _isReplying = false;
  String? _replyingToUsername;
  String? _replyingToCommentId;

  // Translatable text
  String postDetailsText = 'Post Details';
  String errorText = 'Error';
  String loadCommentsErrorText = 'Unable to load comments: Invalid feed ID';
  String failedLoadCommentsText = 'Failed to load comments: ';
  String addCommentErrorText = 'Unable to add comment: Invalid feed ID';
  String failedAddCommentText = 'Failed to add comment: ';

  @override
  void initState() {
    super.initState();
    _initializeLanguage();
    if (widget.feed['id'] != null || widget.feed['_id'] != null) {
      _loadComments();
    }
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }

  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('Post Details'),
      _languageService.translate('Error'),
      _languageService.translate('Unable to load comments: Invalid feed ID'),
      _languageService.translate('Failed to load comments: '),
      _languageService.translate('Unable to add comment: Invalid feed ID'),
      _languageService.translate('Failed to add comment: '),
    ]);

    setState(() {
      postDetailsText = translations[0];
      errorText = translations[1];
      loadCommentsErrorText = translations[2];
      failedLoadCommentsText = translations[3];
      addCommentErrorText = translations[4];
      failedAddCommentText = translations[5];
    });

    // Translate feed content
    if (widget.feed['description'] != null) {
      widget.feed['description'] =
          await _languageService.translate(widget.feed['description']);
    }
    if (widget.feed['content'] != null) {
      widget.feed['content'] =
          await _languageService.translate(widget.feed['content']);
    }

    // Translate existing comments
    if (widget.feed['comments'] != null) {
      for (var comment in widget.feed['comments']) {
        if (comment['content'] != null) {
          comment['content'] =
              await _languageService.translate(comment['content']);
        }
      }
    }
  }

  Future<void> _loadComments() async {
    try {
      final feedId = widget.feed['id'] ?? widget.feed['_id'];
      if (feedId != null) {
        await _feedController.getComments(feedId, refresh: true);
      } else {
        Get.snackbar(
          errorText,
          loadCommentsErrorText,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        errorText,
        '$failedLoadCommentsText${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _onScroll() {
    // Trigger loading next page when user scrolls to 80% of the list
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
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
        errorText,
        addCommentErrorText,
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
        errorText,
        '$failedAddCommentText${e.toString()}',
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
        title: Text(
          postDetailsText,
          style: const TextStyle(color: Colors.black),
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
                _buildCommentsSection(),
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

  Widget _buildCommentsSection() {
    return Obx(() {
      if (_feedController.isLoadingComments.value && _feedController.comments.isEmpty) {
        return Center(child: CircularProgressIndicator(color: Colors.green));
      }

      if (_feedController.hasError && _feedController.comments.isEmpty) {
        return ErrorHandler.getErrorWidget(
          errorType: _feedController.errorType ?? ErrorType.unknown,
          onRetry: () {
            final feedId = widget.feed['id'] ?? widget.feed['_id'];
            if (feedId != null) {
              _feedController.getComments(feedId, refresh: true);
            }
          },
          showRetry: true,
        );
      }

      return CommentsSection(
        feedController: _feedController,
        onReply: _initiateReply,
      );
    });
  }
}

class MediaContent extends StatelessWidget {
  final String? mediaUrl;

  const MediaContent({super.key, this.mediaUrl});

  @override
  Widget build(BuildContext context) {
    if (mediaUrl == null ||
        mediaUrl!.isEmpty ||
        mediaUrl == "file:///" ||
        !Uri.parse(mediaUrl!).isAbsolute) {
      return Container(
        width: double.infinity,
        height: 200,
        color: Colors.grey.withOpacity(0.2),
        child: const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.grey,
            size: 48,
          ),
        ),
      );
    }

    // Check if the URL is a video
    bool isVideo = mediaUrl!.toLowerCase().endsWith('.mp4') ||
        mediaUrl!.toLowerCase().endsWith('.mov') ||
        mediaUrl!.toLowerCase().endsWith('.avi') ||
        mediaUrl!
            .contains('commondatastorage.googleapis.com/gtv-videos-bucket');

    if (isVideo) {
      return VideoPlayerWidget(
        videoUrl: mediaUrl!,
        autoPlay: false,
      );
    } else {
      // For images
      return Image.network(
        mediaUrl!,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey.withOpacity(0.2),
            child: const Center(
              child: Icon(
                Icons.broken_image,
                color: Colors.grey,
                size: 48,
              ),
            ),
          );
        },
      );
    }
  }
}
