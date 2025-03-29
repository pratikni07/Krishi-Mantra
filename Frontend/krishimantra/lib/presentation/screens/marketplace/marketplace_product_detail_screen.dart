import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/presentation/controllers/marketplace_controller.dart';
import 'package:krishimantra/data/services/language_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:expandable_text/expandable_text.dart';

class MarketPlaceProductDetailScreen extends StatefulWidget {
  final String productId;

  const MarketPlaceProductDetailScreen({Key? key, required this.productId})
      : super(key: key);

  @override
  _MarketPlaceProductDetailScreenState createState() =>
      _MarketPlaceProductDetailScreenState();
}

class _MarketPlaceProductDetailScreenState
    extends State<MarketPlaceProductDetailScreen> {
  final MarketplaceController _controller = Get.find<MarketplaceController>();
  int _currentImageIndex = 0;
  final TextEditingController _commentController = TextEditingController();
  Map<String, YoutubePlayerController> _youtubeControllers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.fetchProductById(widget.productId);
      _controller.fetchComments(widget.productId, refresh: true);
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _youtubeControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Widget _buildMediaCarousel(List<dynamic> media) {
    final items = media.map((m) {
      if (m['type'] == 'video' && m['isYoutubeVideo']) {
        final videoId = YoutubePlayer.convertUrlToId(m['url']);
        if (videoId != null) {
          _youtubeControllers[videoId] = YoutubePlayerController(
            initialVideoId: videoId,
            flags: YoutubePlayerFlags(
              autoPlay: false,
              mute: false,
              showLiveFullscreenButton: false,
            ),
          );
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: YoutubePlayer(
              controller: _youtubeControllers[videoId]!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: AppColors.green,
              progressColors: ProgressBarColors(
                playedColor: AppColors.green,
                handleColor: AppColors.green,
              ),
            ),
          );
        }
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: m['url'],
          fit: BoxFit.cover,
          width: double.infinity,
          placeholder: (context, url) => Center(
            child: CircularProgressIndicator(color: AppColors.green),
          ),
          errorWidget: (context, url, error) => Icon(Icons.error),
        ),
      );
    }).toList();

    return Stack(
      children: [
        CarouselSlider(
          options: CarouselOptions(
            height: 300,
            viewportFraction: 1.0,
            onPageChanged: (index, reason) {
              setState(() {
                _currentImageIndex = index;
                // Pause all videos when sliding
                _youtubeControllers.values.forEach((controller) {
                  controller.pause();
                });
              });
            },
          ),
          items: items,
        ),
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSmoothIndicator(
              activeIndex: _currentImageIndex,
              count: items.length,
              effect: WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                activeDotColor: AppColors.green,
                dotColor: Colors.white.withOpacity(0.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoSection(List<dynamic> media) {
    final videos = media
        .where((m) => m['type'] == 'video' && m['isYoutubeVideo'])
        .toList();
    if (videos.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Product Videos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ...videos.map((video) {
          final videoId = YoutubePlayer.convertUrlToId(video['url']);
          if (videoId == null) return SizedBox.shrink();

          if (!_youtubeControllers.containsKey(videoId)) {
            _youtubeControllers[videoId] = YoutubePlayerController(
              initialVideoId: videoId,
              flags: YoutubePlayerFlags(
                autoPlay: false,
                mute: false,
                showLiveFullscreenButton: false,
              ),
            );
          }

          return Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: YoutubePlayer(
                controller: _youtubeControllers[videoId]!,
                showVideoProgressIndicator: true,
                progressIndicatorColor: AppColors.green,
                progressColors: ProgressBarColors(
                  playedColor: AppColors.green,
                  handleColor: AppColors.green,
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        title: Text('Product Details'),
        elevation: 0,
      ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () => launch("tel:${_controller.productDetails['sellerInfo']['contactNumber']}"),
          backgroundColor: AppColors.green,
          icon: Icon(Icons.phone, color: Colors.white),
          label: Text(
            'Call Now',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      body: Obx(() {
        if (_controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        final product = _controller.productDetails.value;
        if (product.isEmpty) {
          return Center(child: Text('Product not found'));
        }

        return SingleChildScrollView(
          controller: _controller.scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Media Carousel
              _buildMediaCarousel(product['media']),

              // Product Title and Price
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['title'] ?? '',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '${product['priceRange']['currency']} ${product['priceRange']['min']} - ${product['priceRange']['max']}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.green,
                      ),
                    ),
                  ],
                ),
              ),

              // Tags with # prefix
              if ((product['tags'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (product['tags'] as List).map((tag) => Text(
                      '#$tag',
                      style: TextStyle(
                        color: AppColors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    )).toList(),
                  ),
                ),

              // Product Details
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem('Condition', product['condition']),
                    _buildDetailItem('Location', product['location']),
                    _buildDetailItem('Category', product['category']),
                    _buildDetailItem('Rating', '${product['rating']} ★'),
                    _buildDetailItem('Views', '${product['views']}'),
                  ],
                ),
              ),

              // Divider before Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                child: Divider(thickness: 1, color: Colors.grey[300]),
              ),

              // Description with Show More/Less
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    ExpandableText(
                      product['detailedDescription'] ?? '',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                      maxLines: 2,
                      expandText: 'show more',
                      collapseText: 'show less',
                      linkColor: AppColors.green,
                      animation: true,
                      animationDuration: Duration(milliseconds: 300),
                    ),
                  ],
                ),
              ),

              // Seller Info with white text button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seller Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(product['sellerInfo']['profilePhoto']),
                          onBackgroundImageError: (_, __) {},
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product['sellerInfo']['userName'],
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                product['sellerInfo']['contactNumber'],
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => launch("tel:${product['sellerInfo']['contactNumber']}"),
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.green,
                            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: Text(
                            'Contact',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Divider(thickness: 8, color: Colors.grey[200]),

              // Enhanced Comments Section
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comments',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    // Enhanced comment input
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              decoration: InputDecoration(
                                hintText: 'Write a comment...',
                                hintStyle: TextStyle(color: Colors.grey[500]),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ),
                          Container(
                            margin: EdgeInsets.only(right: 4),
                            child: IconButton(
                              icon: Icon(Icons.send_rounded, color: AppColors.green),
                              onPressed: () async {
                                if (_commentController.text.isNotEmpty) {
                                  await _controller.addComment(widget.productId, _commentController.text);
                                  _commentController.clear();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Comments List
              Obx(() {
                if (_controller.isLoadingComments.value && _controller.comments.isEmpty) {
                  return Center(child: CircularProgressIndicator(color: AppColors.green));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: _controller.comments.length + (_controller.hasMoreComments.value ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _controller.comments.length) {
                      return Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                      );
                    }

                    final comment = _controller.comments[index];
                    return _buildCommentItem(comment);
                  },
                );
              }),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    if (value == null || value.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage(comment['userProfilePhoto'] ?? ''),
                onBackgroundImageError: (_, __) {},
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            comment['userName'] ?? '',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(comment['text'] ?? ''),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Row(
                        children: [
                          Text(
                            timeago.format(DateTime.parse(comment['createdAt'])),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(width: 16),
                          GestureDetector(
                            onTap: () => _showReplyInput(context, comment['_id']),
                            child: Text(
                              'Reply',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((comment['replies'] as List).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 24.0, top: 8.0),
                        child: Column(
                          children: (comment['replies'] as List)
                              .map((reply) => _buildReply(reply))
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1),
      ],
    );
  }

  Widget _buildReply(Map<String, dynamic> reply) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundImage: NetworkImage(reply['userProfilePhoto'] ?? ''),
            onBackgroundImageError: (_, __) {},
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reply['userName'] ?? '',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        reply['text'] ?? '',
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    timeago.format(DateTime.parse(reply['createdAt'])),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showReplyInput(BuildContext context, String commentId) {
    final replyController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Write a reply...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (value) async {
                          if (value.isNotEmpty) {
                            await _controller.addReply(widget.productId, commentId, value);
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                    Container(
                      margin: EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: Icon(Icons.send_rounded, color: AppColors.green),
                        onPressed: () async {
                          if (replyController.text.isNotEmpty) {
                            await _controller.addReply(
                              widget.productId,
                              commentId,
                              replyController.text,
                            );
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
