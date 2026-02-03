import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/company_model.dart';
import '../../../../data/services/language_service.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/constants/colors.dart';

class ReviewsSection extends StatefulWidget {
  final CompanyModel company;

  const ReviewsSection({Key? key, required this.company}) : super(key: key);

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  String reviewsText = "Reviews";
  String noReviewsText = "No reviews yet";
  bool _translationsInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeTranslations();
  }

  Future<void> _initializeTranslations() async {
    final languageService = await LanguageService.getInstance();

    final translations = await Future.wait([
      languageService.translate('Reviews'),
      languageService.translate('No reviews yet'),
    ]);

    if (mounted) {
      setState(() {
        reviewsText = translations[0];
        noReviewsText = translations[1];
        _translationsInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);
    final reviews = widget.company.reviews;

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
              reviewsText,
              style: TextStyle(
                fontSize: AppSizes.fontL,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(height: AppSizes.paddingXL),
            if (reviews == null || reviews.isEmpty)
              Center(
                child: Padding(
                  padding: RPadding.symmetric(vertical: 16),
                  child: Text(
                    noReviewsText,
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontStyle: FontStyle.italic,
                      fontSize: AppSizes.fontM,
                    ),
                  ),
                ),
              )
            else
              ...reviews.map((review) => _buildReviewItem(review)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewItem(Review review) {
    final starSize = ResponsiveUtils.responsive(mobile: 18.0, tablet: 22.0);

    return Padding(
      padding: EdgeInsets.only(bottom: AppSizes.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: starSize,
                  );
                }),
              ),
              Text(
                DateFormat('MMM dd, yyyy').format(review.createdAt),
                style: TextStyle(
                  fontSize: AppSizes.fontS,
                  color: AppColors.textGrey,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSizes.paddingS),
          FutureBuilder<String>(
            future: review.getTranslatedComment(),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? review.comment,
                style: TextStyle(fontSize: AppSizes.fontM),
              );
            }
          ),
          if (review != widget.company.reviews!.last) Divider(height: AppSizes.paddingXXL),
        ],
      ),
    );
  }
} 