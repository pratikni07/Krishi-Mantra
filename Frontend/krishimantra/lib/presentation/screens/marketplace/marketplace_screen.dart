import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/presentation/controllers/marketplace_controller.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/presentation/widgets/app_header.dart';
import 'package:krishimantra/data/services/language_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'add_product_screen.dart';
import 'marketplace_product_detail_screen.dart';


class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({Key? key}) : super(key: key);

  @override
  _MarketplaceScreenState createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final MarketplaceController _controller = Get.find<MarketplaceController>();
  final TextEditingController _searchController = TextEditingController();
  late LanguageService _languageService;
  String marketplaceTitle = "Marketplace";
  String searchHint = "Search products...";
  bool _canAddProducts = false;
  
  final double a8 = 8.0; // Spacing constant
  Map<String, int> _currentImageIndices = {}; // Track current image index for each product
  
  @override
  void initState() {
    super.initState();
    _controller.fetchMarketplaceProducts();
    _initializeLanguage();
    _checkUserPermissions();
  }
  
  Future<void> _initializeLanguage() async {
    _languageService = await LanguageService.getInstance();
    await _updateTranslations();
  }
  
  Future<void> _updateTranslations() async {
    final translations = await Future.wait([
      _languageService.translate('Marketplace'),
      _languageService.translate('Search products...'),
    ]);
    
    setState(() {
      marketplaceTitle = translations[0];
      searchHint = translations[1];
    });
  }
  
  Future<void> _checkUserPermissions() async {
    final canAdd = await _controller.isUserAllowedToAddProducts();
    setState(() {
      _canAddProducts = canAdd;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        title: AppHeader(),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Obx(() {
              if (_controller.isLoading.value && _controller.marketplaceProducts.isEmpty) {
                return Center(child: CircularProgressIndicator(color: AppColors.green));
              }
              
              if (_controller.marketplaceProducts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No products available',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return RefreshIndicator(
                onRefresh: () => _controller.fetchMarketplaceProducts(),
                color: AppColors.green,
                child: ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: _controller.marketplaceProducts.length,
                  itemBuilder: (context, index) {
                    final product = _controller.marketplaceProducts[index];
                    return _buildProductCard(product);
                  },
                ),
              );
            }),
          ),
        ],
      ),
      floatingActionButton: _canAddProducts 
          ? FloatingActionButton(
              onPressed: () {
                Get.to(() => AddProductScreen());
              },
              backgroundColor: AppColors.green,
              child: Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      color: AppColors.green,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: searchHint,
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.white, width: 2),
          ),
        ),
        style: TextStyle(fontSize: 16),
        onChanged: (value) {
          // Implement search functionality
        },
      ),
    );
  }
  
  Widget _buildProductCard(dynamic product) {
    if (!_currentImageIndices.containsKey(product['_id'])) {
      _currentImageIndices[product['_id']] = 0;
    }

    return GestureDetector(
      onTap: () {
        Get.toNamed('/marketplace-detail', arguments: product['_id']);
      },
      child: Card(
        elevation: 2,
        margin: EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: SizedBox(
          height: 140,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left side - Image
              ClipRRect(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: SizedBox(
                  width: 140,
                  child: StatefulBuilder(
                    builder: (context, setState) {
                      final imageList = product['images'] as List<dynamic>? ?? [];
                      return Stack(
                        children: [
                          if (imageList.isNotEmpty)
                            CarouselSlider(
                              options: CarouselOptions(
                                height: double.infinity,
                                viewportFraction: 1.0,
                                initialPage: 0,
                                enableInfiniteScroll: imageList.length > 1,
                                autoPlay: imageList.length > 1,
                                autoPlayInterval: Duration(seconds: 3),
                                onPageChanged: (index, reason) {
                                  setState(() {
                                    _currentImageIndices[product['_id']] = index;
                                  });
                                },
                              ),
                              items: imageList.map((imageUrl) {
                                return CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.green,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => 
                                      Icon(Icons.error),
                                );
                              }).toList(),
                            )
                          else
                            Container(
                              color: Colors.grey[200],
                              child: Center(
                                child: Icon(Icons.image_not_supported, 
                                  color: Colors.grey[400],
                                  size: 40,
                                ),
                              ),
                            ),
                          if (imageList.length > 1)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: AnimatedSmoothIndicator(
                                  activeIndex: _currentImageIndices[product['_id']] ?? 0,
                                  count: imageList.length,
                                  effect: WormEffect(
                                    dotHeight: 6,
                                    dotWidth: 6,
                                    activeDotColor: AppColors.green,
                                    dotColor: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              
              // Right side - Product details
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product['title'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            product['shortDescription'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (product['priceRange'] != null)
                            Text(
                              '₹${_formatPrice(product['priceRange']['min'])} - ₹${_formatPrice(product['priceRange']['max'])}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.green,
                              ),
                            ),
                          if (product['rating'] != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 16,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  '${product['rating']}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Helper method to ensure price values are displayed correctly
  String _formatPrice(dynamic price) {
    if (price is int) {
      return price.toString();
    } else if (price is String) {
      return price;
    } else if (price is double) {
      return price.toStringAsFixed(0);
    }
    return '0';
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
} 