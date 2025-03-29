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
import '../../widgets/comment_section.dart';

class MarketPlaceProductDetailScreen extends StatefulWidget {
  final String productId;

  const MarketPlaceProductDetailScreen({Key? key, required this.productId}) : super(key: key);

  @override
  _MarketPlaceProductDetailScreenState createState() => _MarketPlaceProductDetailScreenState();
}

class _MarketPlaceProductDetailScreenState extends State<MarketPlaceProductDetailScreen> {
  final MarketplaceController _controller = Get.find<MarketplaceController>();
  int _currentImageIndex = 0;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.fetchProductById(widget.productId);
      _controller.fetchComments(widget.productId, refresh: true);
    });
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
      body: Obx(() {
        if (_controller.isLoading.value) {
          return Center(child: CircularProgressIndicator());
        }

        final product = _controller.productDetails.value;
        if (product.isEmpty) {
          return Center(child: Text('Product not found'));
        }

        return ListView(
          children: [
            _buildProductDetails(product),
            Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comments',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  CommentSection(
                    productId: widget.productId,
                    comments: _controller.comments,
                    isLoading: _controller.isLoadingComments.value,
                    hasMore: _controller.hasMoreComments.value,
                    onLoadMore: () => _controller.fetchComments(widget.productId),
                    onAddComment: (text) => _controller.addComment(widget.productId, text),
                    onAddReply: (commentId, text) => 
                        _controller.addReply(widget.productId, commentId, text),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildProductDetails(Map<String, dynamic> product) {
    final media = (product['media'] as List?) ?? [];
    final images = media.where((m) => m['type'] == 'image').map((m) => m['url'] as String).toList();
    final videos = media.where((m) => m['type'] == 'video').map((m) => m['url'] as String).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image Carousel
        AspectRatio(
          aspectRatio: 4/3,
          child: Stack(
            children: [
              CarouselSlider(
                options: CarouselOptions(
                  height: double.infinity,
                  viewportFraction: 1.0,
                  onPageChanged: (index, reason) {
                    setState(() => _currentImageIndex = index);
                  },
                ),
                items: images.map((url) => CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                )).toList(),
              ),
              if (images.isNotEmpty) Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedSmoothIndicator(
                    activeIndex: _currentImageIndex,
                    count: images.length,
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
          ),
        ),

        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product['title'] ?? '',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '₹${product['priceRange']['min']} - ₹${product['priceRange']['max']}',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              
              // Seller Info
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(product['sellerInfo']['profilePhoto']),
                  ),
                  title: Text(product['sellerInfo']['userName']),
                  subtitle: Text(product['location']),
                  trailing: IconButton(
                    icon: Icon(Icons.phone),
                    onPressed: () {
                      launch("tel:${product['sellerInfo']['contactNumber']}");
                    },
                  ),
                ),
              ),
              
              SizedBox(height: 16),
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(product['detailedDescription'] ?? ''),
              
              if (videos.isNotEmpty) ...[
                SizedBox(height: 16),
                Text(
                  'Videos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                // Add YouTube video player here
              ],
              
              SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  for (final tag in (product['tags'] as List? ?? []))
                    Chip(
                      label: Text(tag),
                      backgroundColor: Colors.grey[200],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}