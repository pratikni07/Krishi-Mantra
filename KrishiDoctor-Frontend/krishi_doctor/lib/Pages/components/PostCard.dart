import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum MediaType {
  image,
  video,
  none
}

class FacebookPostCard extends StatefulWidget {
  final String username;
  final String profileImageUrl;
  final String postTime;
  final String postContent;
  final String? mediaUrl;
  final MediaType mediaType;
  final int likes;
  final int comments;
  final int shares;

  const FacebookPostCard({
    Key? key,
    required this.username,
    required this.profileImageUrl,
    required this.postTime,
    required this.postContent,
    this.mediaUrl,
    this.mediaType = MediaType.none,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
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

  @override
  void initState() {
    super.initState();
    _currentLikes = widget.likes;
    _initializeMedia();
  }

  void _initializeMedia() {
    if (widget.mediaType == MediaType.video && widget.mediaUrl != null) {
      _initializeVideoPlayer(widget.mediaUrl!);
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
          print('Video initialization error: $error');
          if (mounted) {
            setState(() {
              _videoInitError = true;
            });
          }
        });
    } catch (e) {
      print('Error setting up video controller: $e');
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
    if (widget.mediaUrl == null) return const SizedBox.shrink();

    switch (widget.mediaType) {
      case MediaType.image:
        return _buildImageMedia();
      case MediaType.video:
        return _buildVideoMedia();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImageMedia() {
    return Image.network(
      widget.mediaUrl!,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildMediaErrorWidget(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return _buildMediaLoadingWidget(loadingProgress);
      },
    );
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
                _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
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
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
              )
            : const CircularProgressIndicator(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white, // Set background to white
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section (User Profile)
          _buildHeader(),
          
          // Post Content
          _buildPostContent(),
          
          // Media Content
          _buildMediaContent(),
          
          // Interactions Section
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
      child: Text(
        widget.postContent,
        style: const TextStyle(fontSize: 15),
      ),
    );
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
              Text('$_currentLikes', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        
        // Action Buttons
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
              onTap: () {},
            ),
            _buildActionButton(
              icon: Icons.share_outlined,
              label: 'Share',
              onTap: () {},
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