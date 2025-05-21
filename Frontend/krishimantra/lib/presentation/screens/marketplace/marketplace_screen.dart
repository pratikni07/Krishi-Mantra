import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/presentation/controllers/marketplace_controller.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/core/utils/language_helper.dart';
import 'package:krishimantra/core/utils/error_with_translation.dart';
import 'package:krishimantra/presentation/widgets/error_widgets.dart';
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

class _MarketplaceScreenState extends State<MarketplaceScreen>
    with TranslationMixin {
  final MarketplaceController _controller = Get.find<MarketplaceController>();
  final TextEditingController _searchController = TextEditingController();
  bool _canAddProducts = false;

  final double a8 = 8.0; // Spacing constant
  Map<String, int> _currentImageIndices =
      {}; // Track current image index for each product

  // Add new variables for search and filters
  bool _showFilters = false;
  RangeValues _priceRange = RangeValues(0, 1000000);

  // Translation keys
  static const String KEY_MARKETPLACE = 'marketplace';
  static const String KEY_SEARCH_HINT = 'search_products';
  static const String KEY_PRICE_RANGE = 'price_range';
  static const String KEY_CATEGORIES = 'categories';
  static const String KEY_CLEAR_FILTERS = 'clear_filters';
  static const String KEY_APPLY_FILTERS = 'apply_filters';
  static const String KEY_NO_PRODUCTS = 'no_products';
  static const String KEY_LOADING = 'loading_products';
  static const String KEY_ERROR = 'error_loading_products';
  static const String KEY_TRY_AGAIN = 'try_again';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    _loadMarketplaceData();
    _checkUserPermissions();
  }

  void _registerTranslations() {
    registerTranslation(KEY_MARKETPLACE, 'Marketplace');
    registerTranslation(KEY_SEARCH_HINT, 'Search products...');
    registerTranslation(KEY_PRICE_RANGE, 'Price Range');
    registerTranslation(KEY_CATEGORIES, 'Categories');
    registerTranslation(KEY_CLEAR_FILTERS, 'Clear Filters');
    registerTranslation(KEY_APPLY_FILTERS, 'Apply Filters');
    registerTranslation(
        KEY_NO_PRODUCTS, 'No products found. Try different search criteria.');
    registerTranslation(KEY_LOADING, 'Loading products...');
    registerTranslation(KEY_ERROR, 'Error loading products');
    registerTranslation(KEY_TRY_AGAIN, 'Try Again');
  }

  Future<void> _loadMarketplaceData() async {
    try {
      await _controller.fetchMarketplaceProducts();
    } catch (e) {
      // Error is handled in the controller and displayed in the UI
      await TranslatedErrorHandler.showError(e, context: context);
    }
  }

  Future<void> _checkUserPermissions() async {
    try {
      final canAdd = await _controller.isUserAllowedToAddProducts();
      setState(() {
        _canAddProducts = canAdd;
      });
    } catch (e) {
      // Just log the error but don't show to user as this is not critical
      debugPrint('Error checking permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.green,
        title: Text(
          getTranslation(KEY_MARKETPLACE),
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
              child: const Icon(Icons.add, color: Colors.white),
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
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              // Center the TextField
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: getTranslation(KEY_SEARCH_HINT),
                  hintStyle: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.green),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showFilters
                          ? Icons.filter_list
                          : Icons.filter_list_outlined,
                      color: AppColors.green,
                    ),
                    onPressed: () =>
                        setState(() => _showFilters = !_showFilters),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  alignLabelWithHint: true, // Align hint text
                ),
                textAlignVertical:
                    TextAlignVertical.center, // Center text vertically
                onChanged: (value) {
                  _controller.searchTerm.value = value;
                  _controller.searchProducts();
                },
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
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            getTranslation(KEY_PRICE_RANGE),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000000,
            divisions: 100,
            activeColor: AppColors.green,
            labels: RangeLabels(
              '₹${_formatPrice(_priceRange.start)}',
              '₹${_formatPrice(_priceRange.end)}',
            ),
            onChanged: (values) {
              setState(() => _priceRange = values);
              _controller.minPrice.value = values.start;
              _controller.maxPrice.value = values.end;
              _controller.searchProducts();
            },
          ),
          const SizedBox(height: 16),
          Text(
            getTranslation(KEY_CATEGORIES),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildCategoryChips(),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _clearFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: BorderSide(color: AppColors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(getTranslation(KEY_CLEAR_FILTERS)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  _controller.searchProducts();
                  setState(() => _showFilters = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(getTranslation(KEY_APPLY_FILTERS)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    // Format price with commas (e.g., 1,000,000)
    if (price == null) return '0';
    return price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  void _clearFilters() {
    setState(() {
      _priceRange = const RangeValues(0, 1000000);
      _controller.minPrice.value = 0;
      _controller.maxPrice.value = 1000000;
      _controller.selectedCategory.value = '';
      _searchController.clear();
      _controller.searchTerm.value = '';
    });
    _controller.searchProducts();
  }

  List<Widget> _buildCategoryChips() {
    final categories = [
      'Farm Equipment',
      'Seeds',
      'Fertilizers',
      'Pesticides',
      'Irrigation',
      'Harvesting Tools',
      'Storage',
      'Livestock',
    ];

    return categories.map((category) {
      final isSelected = _controller.selectedCategory.value == category;

      return GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              _controller.selectedCategory.value = '';
            } else {
              _controller.selectedCategory.value = category;
            }
          });
        },
        child: Chip(
          label: Text(
            category,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontSize: 12,
            ),
          ),
          backgroundColor: isSelected ? AppColors.green : Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    }).toList();
  }

  Widget _buildProductGrid() {
    return Expanded(
      child: Obx(() {
        if (_controller.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
                ),
                const SizedBox(height: 16),
                Text(
                  getTranslation(KEY_LOADING),
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          );
        }

        if (_controller.errorMessage.isNotEmpty) {
          return ErrorWidgets.genericError(
            onRetry: _loadMarketplaceData,
            message: getTranslation(KEY_ERROR),
          );
        }

        final products = _controller.marketplaceProducts;

        if (products.isEmpty) {
          return ErrorWidgets.emptyState(
            message: getTranslation(KEY_NO_PRODUCTS),
            icon: Icons.search_off,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _controller.fetchMarketplaceProducts(forceRefresh: true);
          },
          color: AppColors.green,
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final productId = product['_id'].toString();
              if (!_currentImageIndices.containsKey(productId)) {
                _currentImageIndices[productId] = 0;
              }

              return _buildProductCard(product, index);
            },
          ),
        );
      }),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, int index) {
    final productId = product['_id'].toString();
    final media = List<Map<String, dynamic>>.from(product['media'] ?? []);
    final images = media.where((m) => m['type'] == 'image').toList();
    final currentIndex = _currentImageIndices[productId] ?? 0;

    // Safely get image URL
    String imageUrl = '';
    if (images.isNotEmpty && currentIndex < images.length) {
      imageUrl = images[currentIndex]['url'] ?? '';
    }

    return GestureDetector(
      onTap: () {
        Get.to(() => MarketPlaceProductDetailScreen(
            productId: product['_id'].toString()));
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  children: [
                    // Product image with carousel functionality
                    if (images.length > 1)
                      CarouselSlider(
                        options: CarouselOptions(
                          aspectRatio: 1, // Square aspect ratio
                          viewportFraction: 1.0,
                          enableInfiniteScroll: false,
                          onPageChanged: (pageIndex, _) {
                            setState(() {
                              _currentImageIndices[productId] = pageIndex;
                            });
                          },
                        ),
                        items: images.map((imageData) {
                          final url = imageData['url'] ?? '';
                          return _buildProductImage(url);
                        }).toList(),
                      )
                    else
                      _buildProductImage(imageUrl),

                    // Only show indicator if more than one image
                    if (images.length > 1)
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SmoothPageIndicator(
                            controller:
                                PageController(initialPage: currentIndex),
                            count: images.length,
                            effect: WormEffect(
                              dotHeight: 6,
                              dotWidth: 6,
                              spacing: 4,
                              activeDotColor: AppColors.green,
                              dotColor: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Product info
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (product['title'] ?? 'Unknown Product').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₹${product['minPrice'] ?? 0} - ₹${product['maxPrice'] ?? 0}",
                      style: TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage(String imageUrl) {
    return Container(
      color: Colors.grey[200],
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
          ),
        ),
        errorWidget: (context, url, error) => const Center(
          child: Icon(Icons.image_not_supported, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
