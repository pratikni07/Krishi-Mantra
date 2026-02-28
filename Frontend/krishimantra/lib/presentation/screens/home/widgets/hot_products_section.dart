import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/utils/home_localizations.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/language_helper.dart';
import '../../../../core/utils/translation_manager.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../data/services/language_service.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../data/models/product_model.dart';
import '../../../../routes/app_routes.dart';
import '../../../widgets/cached_image.dart';
import '../../../widgets/skeleton/skeleton_widgets.dart';
import '../../../controllers/product_controller.dart';
import '../../products/product_detail_screen.dart';

class HotProductsSection extends StatefulWidget {
  const HotProductsSection({super.key});

  @override
  State<HotProductsSection> createState() => _HotProductsSectionState();
}

class _HotProductsSectionState extends State<HotProductsSection>
    with TranslationMixin {
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String _languageCode = '';

  // Translation keys
  static const String KEY_HOT_PRODUCTS = 'hot_products';
  static const String KEY_VIEW_ALL = 'view_all';
  static const String KEY_NEW = 'new';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    _initializeTranslations();
    _syncLanguageCode();
    TranslationManager.instance.addLanguageChangeListener(_onLanguageChanged);
    _fetchProducts();
  }

  Future<void> _initializeTranslations() async {
    if (!mounted) return;
  }

  Future<void> _onLanguageChanged() async {
    await _syncLanguageCode();
  }

  Future<void> _syncLanguageCode() async {
    final languageService = await LanguageService.getInstance();
    if (!mounted) return;
    setState(() {
      _languageCode = languageService.getLanguageCode();
    });
  }

  void _registerTranslations() {
    registerTranslation(KEY_HOT_PRODUCTS, 'Hot Products');
    registerTranslation(KEY_VIEW_ALL, 'View All');
    registerTranslation(KEY_NEW, 'NEW');
  }

  Future<void> _fetchProducts() async {
    try {
      final productRepository = Get.find<ProductRepository>();
      final products = await productRepository.getAllProducts();
      if (mounted) {
        setState(() {
          _products = products.take(6).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching hot products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingL,
            vertical: AppSizes.paddingM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tr(KEY_HOT_PRODUCTS),
                style: TextStyle(
                  fontSize: AppSizes.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green,
                ),
              ),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.FERTILIZERS),
                child: Row(
                  children: [
                    Text(
                      _tr(KEY_VIEW_ALL),
                      style: TextStyle(
                        fontSize: AppSizes.fontM,
                        color: AppColors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: AppSizes.iconS,
                      color: AppColors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: ResponsiveUtils.responsive(mobile: 200.0, tablet: 240.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(_products[index], index);
            },
          ),
        ),
        // Bottom margin
        SizedBox(height: AppSizes.paddingL),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingL,
            vertical: AppSizes.paddingM,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _tr(KEY_HOT_PRODUCTS),
                style: TextStyle(
                  fontSize: AppSizes.fontXL,
                  fontWeight: FontWeight.bold,
                  color: AppColors.green,
                ),
              ),
              SkeletonContainer(
                width: 60,
                height: 16,
                borderRadius: 4,
              ),
            ],
          ),
        ),
        SizedBox(
          height: ResponsiveUtils.responsive(mobile: 200.0, tablet: 240.0),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
            itemCount: 4,
            itemBuilder: (context, index) {
              return const SkeletonProductCard();
            },
          ),
        ),
        // Bottom margin
        SizedBox(height: AppSizes.paddingL),
      ],
    );
  }

  Widget _buildProductCard(ProductModel product, int index) {
    // Use image URL directly - it should already be a complete URL from the API
    final String imageUrl = product.image;
    final isNew = index < 2; // Mark first 2 as new
    final cardWidth = ResponsiveUtils.responsive(mobile: 140.0, tablet: 170.0);
    final imageHeight =
        ResponsiveUtils.responsive(mobile: 120.0, tablet: 150.0);

    return GestureDetector(
      onTap: () {
        final productController = Get.find<ProductController>();
        productController.selectedProduct.value = product;
        Get.to(() => const ProductDetailScreen());
      },
      child: Container(
        width: cardWidth,
        margin: EdgeInsets.only(right: AppSizes.paddingM),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusL),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Product image with NEW badge - fixed height
            SizedBox(
              height: imageHeight,
              width: cardWidth,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppSizes.radiusL),
                    ),
                    child: CachedImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: cardWidth,
                      height: imageHeight,
                      placeholderColor: AppColors.faintGreen,
                      errorWidget: Container(
                        width: cardWidth,
                        height: imageHeight,
                        color: AppColors.faintGreen,
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.textGrey,
                          size: AppSizes.iconL,
                        ),
                      ),
                    ),
                  ),
                  if (isNew)
                    Positioned(
                      top: AppSizes.paddingS,
                      left: AppSizes.paddingS,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSizes.paddingS,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(AppSizes.radiusS),
                        ),
                        child: Text(
                          _tr(KEY_NEW),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: AppSizes.fontXS,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product info - fixed padding
            Padding(
              padding: EdgeInsets.all(AppSizes.paddingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontSize: AppSizes.fontM,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    product.company.name,
                    style: TextStyle(
                      fontSize: AppSizes.fontS,
                      color: AppColors.textGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    TranslationManager.instance
        .removeLanguageChangeListener(_onLanguageChanged);
    super.dispose();
  }

  String _tr(String key) {
    if (_languageCode.isEmpty) {
      return '';
    }
    return HomeLocalizations.text(key, _languageCode);
  }
}
