import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

enum MediaType {
  image,
  video,
  none
}

class KrishiMantraPost extends StatefulWidget {
  final String farmerName;
  final String profileImage;
  final String postTime;
  final String postContent;
  final List<String> mediaUrls;
  final MediaType mediaType;
  final int likes;
  final int comments;
  final int shares;
  final String location;
  final String cropType;

  const KrishiMantraPost({
    Key? key,
    required this.farmerName,
    required this.profileImage,
    required this.postTime,
    required this.postContent,
    this.mediaUrls = const [],
    this.mediaType = MediaType.none,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    required this.location,
    required this.cropType,
  }) : super(key: key);

  @override
  _KrishiMantraPostState createState() => _KrishiMantraPostState();
}

class _KrishiMantraPostState extends State<KrishiMantraPost> {
  bool _isLiked = false;
  bool _isSaved = false;
  int _currentLikes = 0;
  bool _isExpanded = false;
  static const int _maxLines = 3;
  late final TextPainter _textPainter;
  bool _hasOverflow = false;

  @override
  void initState() {
    super.initState();
    _currentLikes = widget.likes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTextOverflow();
    });
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

  void _navigateToDetailScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailScreen(
          post: widget,
        ),
      ),
    );
  }

  void _checkTextOverflow() {
    final TextSpan text = TextSpan(
      text: widget.postContent,
      style: const TextStyle(fontSize: 15),
    );
    
    _textPainter = TextPainter(
      text: text,
      maxLines: _maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: MediaQuery.of(context).size.width - 32);
    
    _hasOverflow = _textPainter.didExceedMaxLines;
    if (mounted) setState(() {});
  }

  Widget _buildImageCollage() {
    if (widget.mediaUrls.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _navigateToDetailScreen,
      child: SizedBox(
        height: _calculateCollageHeight(),
        child: _buildCollageLayout(),
      ),
    );
  }

  double _calculateCollageHeight() {
    if (widget.mediaUrls.length == 1) return 400;
    if (widget.mediaUrls.length == 2) return 300;
    if (widget.mediaUrls.length >= 3) return 360;
    return 0;
  }

  Widget _buildCollageLayout() {
    switch (widget.mediaUrls.length) {
      case 1:
        return _buildSingleImage();
      case 2:
        return _buildTwoImages();
      case 3:
        return _buildThreeImages();
      default:
        return _buildFourOrMoreImages();
    }
  }

  Widget _buildSingleImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        widget.mediaUrls[0],
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildMediaErrorWidget(),
      ),
    );
  }

  Widget _buildTwoImages() {
    return Row(
      children: [
        Expanded(
          child: _buildCollageItem(widget.mediaUrls[0], leftRadius: true),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: _buildCollageItem(widget.mediaUrls[1], rightRadius: true),
        ),
      ],
    );
  }

  Widget _buildThreeImages() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildCollageItem(widget.mediaUrls[0], leftRadius: true),
        ),
        const SizedBox(width: 2),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(
                child: _buildCollageItem(widget.mediaUrls[1], topRightRadius: true),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: _buildCollageItem(widget.mediaUrls[2], bottomRightRadius: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFourOrMoreImages() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: _buildCollageItem(widget.mediaUrls[0], topLeftRadius: true),
              ),
              const SizedBox(height: 2),
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildCollageItem(widget.mediaUrls[1], bottomLeftRadius: true),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: _buildCollageItem(widget.mediaUrls[2]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Stack(
            children: [
              _buildCollageItem(
                widget.mediaUrls[3], 
                rightRadius: true,
                height: double.infinity,
              ),
              if (widget.mediaUrls.length > 4)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '+${widget.mediaUrls.length - 4}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollageItem(
    String imageUrl, {
    bool leftRadius = false,
    bool rightRadius = false,
    bool topLeftRadius = false,
    bool topRightRadius = false,
    bool bottomLeftRadius = false,
    bool bottomRightRadius = false,
    double? height,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(
            leftRadius || topLeftRadius ? 12 : 0,
          ),
          topRight: Radius.circular(
            rightRadius || topRightRadius ? 12 : 0,
          ),
          bottomLeft: Radius.circular(
            leftRadius || bottomLeftRadius ? 12 : 0,
          ),
          bottomRight: Radius.circular(
            rightRadius || bottomRightRadius ? 12 : 0,
          ),
        ),
        color: Colors.grey[200],
      ),
      clipBehavior: Clip.hardEdge,
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildMediaErrorWidget(),
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
            Text('Image failed to load', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildPostContent() {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: parseTextWithHashtags(widget.postContent),
          ),
          maxLines: _isExpanded ? null : _maxLines,
          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
        ),
        if (_hasOverflow)
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _isExpanded ? 'See less' : 'See more...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
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
            backgroundImage: NetworkImage(widget.profileImage),
            radius: 25,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.farmerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                    Text(
                      widget.location,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.grass, size: 14, color: Colors.grey[600]),
                    Text(
                      widget.cropType,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
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
              // More options menu
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionsSection() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.thumb_up, color: Colors.green, size: 18),
              const SizedBox(width: 4),
              Text('$_currentLikes', style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              Text('${widget.comments} comments • ${widget.shares} shares',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        const Divider(),
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
              color: isActive ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildPostContent(),
          if (widget.mediaUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: _buildImageCollage(),
            ),
          _buildInteractionsSection(),
        ],
      ),
    );
  }
}

List<TextSpan> parseTextWithHashtags(String text) {
  final List<TextSpan> textSpans = [];
  final RegExp hashtagRegex = RegExp(r'\B#\w+');
  int lastIndex = 0;

  for (Match match in hashtagRegex.allMatches(text)) {
    // Add text before the hashtag in black color
    if (match.start > lastIndex) {
      textSpans.add(TextSpan(
        text: text.substring(lastIndex, match.start),
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black, // Regular text in black
        ),
      ));
    }

    // Add the hashtag in blue color
    textSpans.add(TextSpan(
      text: text.substring(match.start, match.end),
      style: const TextStyle(
        fontSize: 15,
        color: Colors.blue,
        fontWeight: FontWeight.w500,
      ),
    ));

    lastIndex = match.end;
  }

  // Add remaining text after the last hashtag in black color
  if (lastIndex < text.length) {
    textSpans.add(TextSpan(
      text: text.substring(lastIndex),
      style: const TextStyle(
        fontSize: 15,
        color: Colors.black, // Regular text in black
      ),
    ));
  }

  return textSpans;
}


class PostDetailScreen extends StatelessWidget {
  final KrishiMantraPost post;

  const PostDetailScreen({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Post by ${post.farmerName}'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: RichText(
                text: TextSpan(
                  children: parseTextWithHashtags(post.postContent),
                ),
              ),
            ),
            ...post.mediaUrls.map((url) => Image.network(
                  url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, color: Colors.red),
                          Text('Image failed to load', 
                               style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ),
                )),
            const SizedBox(height: 16),
            // Comments section (placeholder)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Comments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}