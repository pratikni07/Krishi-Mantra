// feed_details_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../data/services/language_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import 'widgets/media_content.dart';
import 'widgets/post_header.dart';
import 'widgets/post_content.dart';
import 'widgets/post_actions.dart';
import 'widgets/comments_section.dart';
import 'widgets/comment_input.dart';
import '../../../data/models/comment_model.dart';
import '../../controllers/feed_controller.dart';
import '../../widgets/video_player_widget.dart';
import '../../../core/utils/error_handler.dart';
import '../../../utils/image_utils.dart';

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
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark, size: AppSizes.iconM),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          postDetailsText,
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: AppSizes.fontL,
            fontWeight: FontWeight.w600,
          ),
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
                if (_getAllMediaUrls().length > 1)
                  _MediaCarousel(urls: _getAllMediaUrls())
                else if (widget.feed['mediaUrl'] != null)
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
        return const Center(child: CircularProgressIndicator(color: AppColors.green));
      }

      // Only show error screen for actual errors, not for the "no comments" case
      if (_feedController.hasError && _feedController.comments.isEmpty) {
        // Check if the error is specifically about invalid response format with missing docs
        // which is likely happening when there are no comments
        if (_feedController.errorMessage.contains('Invalid response format: missing docs')) {
          // Return the CommentsSection which will show "No comments yet" 
          return CommentsSection(
            feedController: _feedController,
            onReply: _initiateReply,
          );
        }
        
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

  List<String> _getAllMediaUrls() {
    final urls = <String>{};
    if (widget.feed['mediaUrl'] != null && widget.feed['mediaUrl'].toString().isNotEmpty) {
      urls.add(widget.feed['mediaUrl'].toString());
    }
    if (widget.feed['mediaUrls'] != null && widget.feed['mediaUrls'] is List) {
      for (final url in widget.feed['mediaUrls']) {
        if (url != null && url.toString().isNotEmpty) urls.add(url.toString());
      }
    }
    return urls.toList();
  }
}

class MediaContent extends StatelessWidget {
  final String? mediaUrl;

  const MediaContent({super.key, this.mediaUrl});

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    // Validate the URL first
    final String validatedUrl = ImageUtils.validateUrl(mediaUrl);
    final mediaHeight = ResponsiveUtils.hp(25);

    if (validatedUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: mediaHeight,
        color: AppColors.shimmerBase.withOpacity(0.2),
        child: Center(
          child: Icon(
            Icons.broken_image,
            color: AppColors.textLight,
            size: AppSizes.iconXL,
          ),
        ),
      );
    }

    // Check if the URL is a video
    bool isVideo = validatedUrl.toLowerCase().endsWith('.mp4') ||
        validatedUrl.toLowerCase().endsWith('.mov') ||
        validatedUrl.toLowerCase().endsWith('.avi') ||
        validatedUrl.contains('commondatastorage.googleapis.com/gtv-videos-bucket');

    if (isVideo) {
      return VideoPlayerWidget(
        videoUrl: validatedUrl,
        autoPlay: false,
      );
    } else {
      // For images
      return Image.network(
        validatedUrl,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          logger.e('Error loading post image', tag: 'FeedDetailsScreen', error: error);
          return Container(
            width: double.infinity,
            height: mediaHeight,
            color: AppColors.shimmerBase.withOpacity(0.2),
            child: Center(
              child: Icon(
                Icons.broken_image,
                color: AppColors.textLight,
                size: AppSizes.iconXL,
              ),
            ),
          );
        },
      );
    }
  }
}

class _MediaCarousel extends StatefulWidget {
  final List<String> urls;
  const _MediaCarousel({required this.urls});

  @override
  State<_MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<_MediaCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final mediaHeight = ResponsiveUtils.hp(30);

    return Column(
      children: [
        SizedBox(
          height: mediaHeight,
          child: PageView.builder(
            itemCount: widget.urls.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final validatedUrl = ImageUtils.validateUrl(widget.urls[index]);
              if (validatedUrl.isEmpty) {
                return Container(
                  color: Colors.grey.withOpacity(0.2),
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                  ),
                );
              }
              return Image.network(
                validatedUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.withOpacity(0.2),
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey, size: 48),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.urls.length, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentPage == index ? 10 : 7,
              height: _currentPage == index ? 10 : 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPage == index
                    ? AppColors.green
                    : Colors.grey.shade400,
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}
