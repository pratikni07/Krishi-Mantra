import 'package:flutter/material.dart';
import '../../../../data/models/company_model.dart';
import '../../../../data/services/language_service.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/constants/colors.dart';

class ProductsSection extends StatefulWidget {
  final CompanyModel company;

  const ProductsSection({Key? key, required this.company}) : super(key: key);

  @override
  State<ProductsSection> createState() => _ProductsSectionState();
}

class _ProductsSectionState extends State<ProductsSection> {
  String productsText = "Products";
  String noProductsText = "No products available";
  String usageText = "Usage";
  String usedForText = "Used For";
  bool _translationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTranslations();
  }

  Future<void> _initializeTranslations() async {
    final languageService = await LanguageService.getInstance();

    final translations = await Future.wait([
      languageService.translate('Products'),
      languageService.translate('No products available'),
      languageService.translate('Usage'),
      languageService.translate('Used For'),
    ]);

    if (mounted) {
      setState(() {
        productsText = translations[0];
        noProductsText = translations[1];
        usageText = translations[2];
        usedForText = translations[3];
        _translationsInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final products = widget.company.products;

    return Card(
      elevation: 2,
      color: AppColors.scaffoldBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusL)),
      child: Padding(
        padding: RPadding.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productsText,
              style: TextStyle(
                fontSize: AppSizes.fontL,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(height: AppSizes.paddingXL),
            if (products == null || products.isEmpty)
              Center(
                child: Padding(
                  padding: RPadding.symmetric(vertical: 16),
                  child: Text(
                    noProductsText,
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontStyle: FontStyle.italic,
                      fontSize: AppSizes.fontM,
                    ),
                  ),
                ),
              )
            else
              ...products.map((product) => _buildProductItem(product)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductItem(Product product) {
    final imageSize = ResponsiveUtils.responsive(mobile: 80.0, tablet: 100.0);

    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSizes.radiusM),
                child: Image.network(
                  product.image,
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: imageSize,
                      height: imageSize,
                      color: Colors.grey[200],
                      child: Icon(Icons.image_not_supported, color: Colors.grey, size: AppSizes.iconM),
                    );
                  },
                ),
              ),
              SizedBox(width: AppSizes.paddingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String>(
                      future: product.getTranslatedName(),
                      builder: (context, snapshot) {
                        return Text(
                          snapshot.data ?? product.name,
                          style: TextStyle(
                            fontSize: AppSizes.fontL,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                    ),
                    SizedBox(height: AppSizes.paddingS),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$usageText: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: AppSizes.fontM,
                          ),
                        ),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: product.getTranslatedUsage(),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? product.usage,
                                style: TextStyle(fontSize: AppSizes.fontM),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSizes.paddingXS),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$usedForText: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: AppSizes.fontM,
                          ),
                        ),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: product.getTranslatedUsedFor(),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? product.usedFor,
                                style: TextStyle(fontSize: AppSizes.fontM),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (product != widget.company.products!.last) Divider(height: AppSizes.paddingXXL + AppSizes.paddingL),
        ],
      ),
    );
  }
} 