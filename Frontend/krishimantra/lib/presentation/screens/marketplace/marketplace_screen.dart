import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/presentation/controllers/marketplace_controller.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/data/services/language_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:krishimantra/core/utils/error_handler.dart';

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
  
  // Add new variables for search and filters
  bool _showFilters = false;
  RangeValues _priceRange = RangeValues(0, 1000000);
  
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
    updateController(); // Check and update products if empty
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.green,
        title: Text(
          marketplaceTitle,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildProductGrid(),
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
      padding: EdgeInsets.fromLTRB(16, 8, 16, _showFilters ? 16 : 24),
      child: Column(
        children: [
          Container(
            height: 48, // Fixed height
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center( // Center the TextField
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: searchHint,
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.green),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
                      color: AppColors.green,
                    ),
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  alignLabelWithHint: true, // Align hint text
                ),
                textAlignVertical: TextAlignVertical.center, // Center text vertically
                onChanged: _controller.onSearchChanged,
              ),
            ),
          ),
          if (_showFilters) _buildFilters(),
        ],
      ),
    );
  }
  
  Widget _buildFilters() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price Range',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000000,
            divisions: 100,
            activeColor: AppColors.green,
            labels: RangeLabels(
              '₹${_priceRange.start.round()}',
              '₹${_priceRange.end.round()}',
            ),
            onChanged: (values) {
              setState(() => _priceRange = values);
              _controller.minPrice.value = values.start;
              _controller.maxPrice.value = values.end;
              _controller.searchProducts();
            },
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip('New', 'new'),
              _filterChip('Used', 'used'),
              _filterChip('Tools', 'tools'),
              _filterChip('Seeds', 'seeds'),
              _filterChip('Fertilizers', 'fertilizers'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _controller.selectedTags.contains(value);
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.green.withOpacity(0.2),
      checkmarkColor: AppColors.green,
      onSelected: (selected) {
        if (selected) {
          _controller.selectedTags.add(value);
        } else {
          _controller.selectedTags.remove(value);
        }
        _controller.searchProducts();
      },
    );
  }
  
  Widget _buildProductGrid() {
    return Obx(() {
      if (_controller.isLoading) {
        return Expanded(
          child: Center(
            child: CircularProgressIndicator(color: AppColors.green),
          ),
        );
      }

      if (_controller.hasError) {
        return Expanded(
          child: ErrorHandler.getErrorWidget(
            errorType: _controller.errorType ?? ErrorType.unknown,
            onRetry: () => _controller.fetchMarketplaceProducts(),
            showRetry: true,
          ),
        );
      }

      if (_controller.marketplaceProducts.isEmpty) {
        return Expanded(
          child: Center(
            child: Text(
              'No products found',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
        );
      }

      // Modified calculation for better responsiveness
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth = (screenWidth - 48) / 2;
      // Adjusted aspect ratio to prevent overflow
      final itemHeight = itemWidth * 1.6; // Increased height ratio

      return Expanded(
        child: GridView.builder(
          padding: EdgeInsets.all(16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: itemWidth / itemHeight,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _controller.marketplaceProducts.length,
          itemBuilder: (context, index) {
            final product = _controller.marketplaceProducts[index];
            return _buildProductCard(product);
          },
        ),
      );
    });
  }

  Widget _buildProductCard(dynamic product) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = (screenWidth - 48) / 2;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    
    return Container(
      width: cardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            spreadRadius: 1,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              Get.toNamed('/marketplace-detail', arguments: product['_id']);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Added to prevent expansion
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: (product['images'] as List).isNotEmpty 
                        ? product['images'][0] 
                        : 'placeholder_url',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Center(
                      child: CircularProgressIndicator(color: AppColors.green),
                    ),
                    errorWidget: (context, url, error) => Icon(Icons.error),
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, // Prevent expansion
                      children: [
                        Text(
                          product['title'] ?? '',
                          style: TextStyle(
                            fontSize: 13 / textScaleFactor,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          product['shortDescription'] ?? '',
                          style: TextStyle(
                            fontSize: 11 / textScaleFactor,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4), // Fixed spacing instead of Spacer
                        Container(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Flexible(
                                child: Text(
                                  '₹${_formatPrice(product['priceRange']['min'])} - ₹${_formatPrice(product['priceRange']['max'])}',
                                  style: TextStyle(
                                    fontSize: 11 / textScaleFactor,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.green,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (product['rating'] != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.star,
                                      color: Colors.amber,
                                      size: 12,
                                    ),
                                    SizedBox(width: 2),
                                    Text(
                                      '${product['rating']}',
                                      style: TextStyle(
                                        fontSize: 11 / textScaleFactor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},'
    );
  }
  
  void updateController() {
    if (_controller.marketplaceProducts.isEmpty) {
      _controller.fetchMarketplaceProducts();
    }
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
} 