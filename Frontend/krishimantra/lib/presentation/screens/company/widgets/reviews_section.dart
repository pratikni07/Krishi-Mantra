import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/company_model.dart';
import '../../../../data/services/language_service.dart';

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
    final reviews = widget.company.reviews;
    
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
              reviewsText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Divider(height: 24),
            if (reviews == null || reviews.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    noReviewsText,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
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
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
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
                    size: 18,
                  );
                }),
              ),
              Text(
                DateFormat('MMM dd, yyyy').format(review.createdAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          FutureBuilder<String>(
            future: review.getTranslatedComment(),
            builder: (context, snapshot) {
              return Text(
                snapshot.data ?? review.comment,
                style: TextStyle(fontSize: 14),
              );
            }
          ),
          if (review != widget.company.reviews!.last) Divider(height: 32),
        ],
      ),
    );
  }
} 