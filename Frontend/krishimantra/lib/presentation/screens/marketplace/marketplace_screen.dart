import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:krishimantra/presentation/controllers/marketplace_controller.dart';
import 'package:krishimantra/core/constants/colors.dart';
import 'package:krishimantra/core/utils/language_helper.dart';
import 'package:krishimantra/core/utils/error_with_translation.dart';
import 'package:krishimantra/core/utils/responsive_utils.dart';
import 'package:krishimantra/presentation/widgets/error_widgets.dart';
import 'package:krishimantra/presentation/widgets/skeleton/skeleton_widgets.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'add_product_screen.dart';
import 'marketplace_product_detail_screen.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/loading_state_widget.dart';
import '../../widgets/error_state_widget.dart';

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

  Map<String, int> _currentImageIndices = {};

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
      debugPrint('Error checking permissions: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        title: Text(
          getTranslation(KEY_MARKETPLACE),
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: AppSizes.fontXXL,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.white, size: AppSizes.iconM),
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
              child: Icon(Icons.add, color: AppColors.white, size: AppSizes.iconM),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppColors.green,
      padding: RPadding.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: _showFilters ? 16 : 24,
      ),
      child: Column(
        children: [
          Container(
            height: AppSizes.buttonHeight,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSizes.radiusRound),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowLight,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: AppSizes.fontL,
                ),
                decoration: InputDecoration(
                  hintText: getTranslation(KEY_SEARCH_HINT),
                  hintStyle: TextStyle(
                    color: AppColors.textLight,
                    fontSize: AppSizes.fontL,
                  ),
                  prefixIcon: Icon(Icons.search, color: AppColors.green, size: AppSizes.iconM),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showFilters
                          ? Icons.filter_list
                          : Icons.filter_list_outlined,
                      color: AppColors.green,
                      size: AppSizes.iconM,
                    ),
                    onPressed: () =>
                        setState(() => _showFilters = !_showFilters),
                  ),
                  border: InputBorder.none,
                  contentPadding: RPadding.symmetric(horizontal: 16),
                  alignLabelWithHint: true,
                ),
                textAlignVertical: TextAlignVertical.center,
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
      margin: RPadding.only(top: 16),
      padding: RPadding.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
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
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              fontSize: AppSizes.fontM,
            ),
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
          SizedBox(height: AppSizes.paddingL),
          Text(
            getTranslation(KEY_CATEGORIES),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
              fontSize: AppSizes.fontM,
            ),
          ),
          SizedBox(height: AppSizes.paddingS),
          Wrap(
            spacing: AppSizes.paddingS,
            runSpacing: AppSizes.paddingS,
            children: _buildCategoryChips(),
          ),
          SizedBox(height: AppSizes.paddingL),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: _clearFilters,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.green,
                  side: BorderSide(color: AppColors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                  ),
                ),
                child: Text(
                  getTranslation(KEY_CLEAR_FILTERS),
                  style: TextStyle(fontSize: AppSizes.fontM),
                ),
              ),
              SizedBox(width: AppSizes.paddingS),
              ElevatedButton(
                onPressed: () {
                  _controller.searchProducts();
                  setState(() => _showFilters = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.radiusRound),
                  ),
                ),
                child: Text(
                  getTranslation(KEY_APPLY_FILTERS),
                  style: TextStyle(fontSize: AppSizes.fontM),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price == null) return '0';
    return price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
  }

  String _formatPriceRange(Map<String, dynamic> product) {
    // Backend sends priceRange: {min, max} instead of minPrice/maxPrice
    final priceRange = product['priceRange'];
    if (priceRange != null && priceRange is Map) {
      final minPrice = priceRange['min'] ?? 0;
      final maxPrice = priceRange['max'] ?? 0;
      return "₹$minPrice - ₹$maxPrice";
    }
    // Fallback for older format
    return "₹${product['minPrice'] ?? 0} - ₹${product['maxPrice'] ?? 0}";
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
    // Server-driven list with a defensive fallback so the chip row still
    // renders something while the first request is in flight or if the
    // categories endpoint is unreachable.
    final fromServer = _controller.categories;
    final categories = fromServer.isNotEmpty
        ? fromServer.toList()
        : <String>[
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
              color: isSelected ? AppColors.white : AppColors.textDark,
              fontSize: AppSizes.fontS,
            ),
          ),
          backgroundColor: isSelected ? AppColors.green : AppColors.scaffoldBackground,
          padding: RPadding.symmetric(horizontal: 8),
        ),
      );
    }).toList();
  }

  Widget _buildProductGrid() {
    return Expanded(
      child: Obx(() {
        if (_controller.isLoading) {
          return const LoadingStateWidget(
            message: 'Loading marketplace products...',
          );
        }

        if (_controller.errorMessage.isNotEmpty) {
          return const ErrorStateWidget(
            title: 'Unable to Load Products',
            subtitle: 'The tractor is stuck on the way to the marketplace. Please check your connection! 🛒',
          );
        }

        final products = _controller.marketplaceProducts;

        if (products.isEmpty) {
          return EmptyStateWidget(
            title: 'No Products in the Market',
            subtitle: 'The tractor is heading to the market to bring fresh products for you! 🛒',
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _controller.fetchMarketplaceProducts(forceRefresh: true);
          },
          color: AppColors.green,
          child: GridView.builder(
            padding: RPadding.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.gridCrossAxisCount,
              childAspectRatio: ResponsiveUtils.gridAspectRatio,
              crossAxisSpacing: AppSizes.paddingL,
              mainAxisSpacing: AppSizes.paddingL,
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

    // Backend returns 'images' as array of URL strings, not 'media' with {type, url}
    final imagesList = product['images'];
    final List<String> images = imagesList is List
        ? List<String>.from(imagesList.map((e) => e?.toString() ?? ''))
        : <String>[];
    final currentIndex = _currentImageIndices[productId] ?? 0;

    String imageUrl = '';
    if (images.isNotEmpty && currentIndex < images.length) {
      imageUrl = images[currentIndex];
    }

    return GestureDetector(
      onTap: () {
        Get.to(() => MarketPlaceProductDetailScreen(
            productId: product['_id'].toString()));
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
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
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(AppSizes.radiusL),
                ),
                child: Stack(
                  children: [
                    if (images.length > 1)
                      CarouselSlider(
                        options: CarouselOptions(
                          aspectRatio: 1,
                          viewportFraction: 1.0,
                          enableInfiniteScroll: false,
                          onPageChanged: (pageIndex, _) {
                            setState(() {
                              _currentImageIndices[productId] = pageIndex;
                            });
                          },
                        ),
                        items: images.map((url) {
                          return _buildProductImage(url);
                        }).toList(),
                      )
                    else
                      _buildProductImage(imageUrl),

                    if (images.length > 1)
                      Positioned(
                        bottom: AppSizes.paddingS,
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

            Expanded(
              flex: 3,
              child: Padding(
                padding: RPadding.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (product['title'] ?? 'Unknown Product').toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.fontM,
                        color: AppColors.textDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: AppSizes.paddingXS),
                    Text(
                      _formatPriceRange(product),
                      style: TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: AppSizes.fontS,
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
      color: AppColors.shimmerBase,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.green),
          ),
        ),
        errorWidget: (context, url, error) => Center(
          child: Icon(Icons.image_not_supported, color: AppColors.textLight, size: AppSizes.iconL),
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
