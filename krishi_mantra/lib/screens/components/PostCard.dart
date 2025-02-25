import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:krishi_mantra/screens/features/feeds/FeedDetailScreen.dart';
import 'package:krishi_mantra/shared/widgets/ShareBottomSheet.dart';
import 'package:video_player/video_player.dart';

enum MediaType { image, video, none }

class FacebookPostCard extends StatefulWidget {
  final String username;
  final String profileImageUrl;
  final String postTime;
  final String postContent;
  final List<String>? mediaUrls; // Changed to List<String>?
  final MediaType mediaType;
  final int likes;
  final int comments;
  final int shares;
  final String postId;

  const FacebookPostCard({
    Key? key,
    required this.username,
    required this.profileImageUrl,
    required this.postTime,
    required this.postContent,
    this.mediaUrls, // Now accepts multiple URLs
    this.mediaType = MediaType.none,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    required this.postId,
    Future<void> Function(dynamic isLiked)? onLiked,
  }) : super(key: key);

  @override
  _FacebookPostCardState createState() => _FacebookPostCardState();
}

class _FacebookPostCardState extends State<FacebookPostCard> {
  bool _isLiked = false;
  bool _isSaved = false;
  int _currentLikes = 0;
  VideoPlayerController? _videoController;
  bool _videoInitError = false;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentLikes = widget.likes;
    _initializeMedia();
  }

  void _initializeMedia() {
    if (widget.mediaType == MediaType.video &&
        widget.mediaUrls?.isNotEmpty == true) {
      _initializeVideoPlayer(widget.mediaUrls!.first);
    }
  }

  void _initializeVideoPlayer(String videoUrl) {
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..setLooping(true)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
          }
        }).catchError((error) {
          // print('Video initialization error: $error');
          if (mounted) {
            setState(() {
              _videoInitError = true;
            });
          }
        });
    } catch (e) {
      // print('Error setting up video controller: $e');
      if (mounted) {
        setState(() {
          _videoInitError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _currentLikes += _isLiked ? 1 : -1;
    });
  }

  void _toggleSave() {
    setState(() {
      _isSaved = !_isSaved;
    });
  }

  Widget _buildMediaContent() {
    if (widget.mediaUrls == null || widget.mediaUrls!.isEmpty) {
      return const SizedBox.shrink();
    }

    switch (widget.mediaType) {
      case MediaType.image:
        return _buildImageCarousel();
      case MediaType.video:
        return _buildVideoMedia();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImageCarousel() {
    if (widget.mediaUrls == null || widget.mediaUrls!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 300,
            viewportFraction: 1.0,
            enableInfiniteScroll: widget.mediaUrls!.length > 1,
            onPageChanged: (index, reason) {
              setState(() {
                _currentImageIndex = index;
              });
            },
          ),
          items: widget.mediaUrls!.map((imageUrl) {
            return Builder(
              builder: (BuildContext context) {
                return Container(
                  width: MediaQuery.of(context).size.width,
                  color: Colors.grey[300],
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildMediaErrorWidget(),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return _buildMediaLoadingWidget(loadingProgress);
                    },
                  ),
                );
              },
            );
          }).toList(),
        ),
        if (widget.mediaUrls!.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.mediaUrls!.asMap().entries.map((entry) {
              return Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 4.0,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(
                    _currentImageIndex == entry.key ? 0.9 : 0.4,
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  // Widget _buildImageMedia() {
  //   return widget.mediaUrl == null
  //       ? const SizedBox.shrink()
  //       : Container(
  //           width: double.infinity,
  //           height: 300, // Set a default height, you can adjust as needed
  //           color: _isVerticalImage(widget.mediaUrl!)
  //               ? Colors.grey[300] // Background for vertical images
  //               : Colors.transparent, // No background for horizontal images
  //           child: Image.network(
  //             widget.mediaUrls!,
  //             fit: _isVerticalImage(widget.mediaUrl!)
  //                 ? BoxFit.contain // Ensure the full vertical image is visible
  //                 : BoxFit.cover, // Keep horizontal images as they are
  //             errorBuilder: (context, error, stackTrace) =>
  //                 _buildMediaErrorWidget(),
  //             loadingBuilder: (context, child, loadingProgress) {
  //               if (loadingProgress == null) return child;
  //               return _buildMediaLoadingWidget(loadingProgress);
  //             },
  //           ),
  //         );
  // }

// Helper method to check if the image is vertical
  bool _isVerticalImage(String imageUrl) {
    // You can use a package like 'image' to get the image dimensions or hard-code it
    // For simplicity, let's assume vertical images have a higher height than width
    final image = NetworkImage(imageUrl);
    return true; // Placeholder, add your logic here to check if the image is vertical.
  }

  Widget _buildVideoMedia() {
    if (_videoInitError) return _buildMediaErrorWidget();

    if (_videoController == null || !_videoController!.value.isInitialized) {
      return _buildMediaLoadingWidget(null);
    }

    return AspectRatio(
      aspectRatio: _videoController!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          VideoPlayer(_videoController!),
          VideoProgressIndicator(
            _videoController!,
            allowScrubbing: true,
          ),
          Positioned(
            bottom: 10,
            child: FloatingActionButton(
              mini: true,
              onPressed: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
              child: Icon(
                _videoController!.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaErrorWidget() {
    return Container(
      height: 200,
      color: Colors.grey[300],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            Text('Media failed to load', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaLoadingWidget(ImageChunkEvent? progress) {
    return Container(
      height: 200,
      color: Colors.grey[300],
      child: Center(
        child: progress != null
            ? CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!
                    : null,
              )
            : const CircularProgressIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildPostContent(),
          _buildMediaContent(),
          _buildInteractionsSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(widget.profileImageUrl),
            radius: 25,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.username,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  widget.postTime,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // More options
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPostContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: RichText(
        text: TextSpan(
          children: _highlightTags(widget.postContent),
          style: const TextStyle(color: Colors.black, fontSize: 15),
        ),
      ),
    );
  }

  List<TextSpan> _highlightTags(String content) {
    final hashtagRegExp = RegExp(r'\B#\w\w+'); // Matches words starting with #
    final spans = <TextSpan>[];

    int lastIndex = 0;
    final matches = hashtagRegExp.allMatches(content);

    for (final match in matches) {
      if (match.start > lastIndex) {
        // Add text before the hashtag
        spans.add(TextSpan(text: content.substring(lastIndex, match.start)));
      }

      // Add the hashtag
      spans.add(
        TextSpan(
          text: match.group(0),
          style: const TextStyle(color: Colors.blue),
        ),
      );

      lastIndex = match.end;
    }

    // Add remaining text after the last hashtag
    if (lastIndex < content.length) {
      spans.add(TextSpan(text: content.substring(lastIndex)));
    }

    return spans;
  }

  Widget _buildInteractionsSection() {
    return Column(
      children: [
        // Like Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.thumb_up, color: Colors.blue, size: 18),
              const SizedBox(width: 4),
              Text('$_currentLikes',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildActionButton(
              icon: Icons.thumb_up_outlined,
              label: 'Like',
              isActive: _isLiked,
              onTap: _toggleLike,
            ),
            _buildActionButton(
              icon: Icons.comment_outlined,
              label: 'Comment',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FeedDetailScreen(
                      username: widget.username,
                      profileImageUrl: widget.profileImageUrl,
                      postTime: widget.postTime,
                      postContent: widget.postContent,
                      mediaUrls: widget.mediaUrls,
                      mediaType: widget.mediaType,
                      likes: widget.likes,
                      comments: widget.comments,
                      feedId: widget
                          .postId, // Make sure to add postId to FacebookPostCard parameters
                    ),
                  ),
                );
              },
            ),
            _buildActionButton(
              icon: Icons.share_outlined,
              label: 'Share',
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => ShareBottomSheet(
                    postId: widget.postId,
                    shareUrl:
                        'https://krishimantra.com/post/${widget.postId}', // Replace with your actual sharing URL
                  ),
                );
              },
            ),
            _buildActionButton(
              icon: _isSaved ? Icons.bookmark : Icons.bookmark_border,
              label: 'Save',
              isActive: _isSaved,
              onTap: _toggleSave,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: isActive ? Colors.blue : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
