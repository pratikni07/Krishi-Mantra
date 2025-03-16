import 'package:flutter/material.dart';
import '../../../../data/models/company_model.dart';
import '../../../../data/services/language_service.dart';

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
    final products = widget.company.products;
    
    return Card(
      elevation: 2,
      color: Colors.grey[50], // Light off-white shade
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productsText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(height: 24),
            if (products == null || products.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    noProductsText,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
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
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  product.image,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[200],
                      child: Icon(Icons.image_not_supported, color: Colors.grey),
                    );
                  },
                ),
              ),
              SizedBox(width: 16),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                    ),
                    SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$usageText: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: product.getTranslatedUsage(),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? product.usage,
                                style: TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              );
                            }
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$usedForText: ',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        Expanded(
                          child: FutureBuilder<String>(
                            future: product.getTranslatedUsedFor(),
                            builder: (context, snapshot) {
                              return Text(
                                snapshot.data ?? product.usedFor,
                                style: TextStyle(fontSize: 14),
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
          if (product != widget.company.products!.last) Divider(height: 40),
        ],
      ),
    );
  }
} 