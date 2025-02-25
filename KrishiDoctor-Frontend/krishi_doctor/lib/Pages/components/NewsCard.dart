import 'package:flutter/material.dart';

class NewsCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final String content;
  final DateTime publishedDate;

  const NewsCard({
    Key? key,
    required this.title,
    required this.imageUrl,
    required this.content,
    required this.publishedDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRoundedImage(
            imageUrl: imageUrl,
            height: 200,
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8.0),
                Text(
                  content,
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8.0),
                Text(
                  '${publishedDate.day} ${_getMonthName(publishedDate.month)}, ${publishedDate.year}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    final monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return monthNames[month - 1];
  }
}

class ClipRoundedImage extends StatelessWidget {
  final String imageUrl;
  final double height;

  const ClipRoundedImage({
    Key? key,
    required this.imageUrl,
    required this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRoundedCorners(
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        height: height,
        width: double.infinity,
      ),
    );
  }
}

class ClipRoundedCorners extends StatelessWidget {
  final Widget child;

  const ClipRoundedCorners({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: child,
    );
  }
}

// Demo data
final demoNewsArticles = [
  NewsCard(
    title: 'Major Breakthrough in Renewable Energy Research',
    imageUrl: 'https://example.com/renewable-energy.jpg',
    content: 'Scientists at the University of Technology have developed a new type of solar panel that is 20% more efficient than traditional designs. This breakthrough could significantly reduce the cost of solar power and accelerate the transition to renewable energy.',
    publishedDate: DateTime(2023, 5, 15),
  ),
  NewsCard(
    title: 'Historic Summit Leads to Groundbreaking Climate Accord',
    imageUrl: 'https://example.com/climate-summit.jpg',
    content: 'World leaders gathered for a landmark climate summit, resulting in a comprehensive agreement to reduce global greenhouse gas emissions by 45% by 2030. This landmark deal is a significant step forward in the fight against climate change.',
    publishedDate: DateTime(2023, 6, 30),
  ),
  NewsCard(
    title: 'New Medical Breakthrough Offers Hope for Cancer Patients',
    imageUrl: 'https://example.com/cancer-research.jpg',
    content: 'Researchers at the renowned Medical Institute have developed a novel treatment that has shown promising results in clinical trials for certain types of cancer. This breakthrough could revolutionize cancer treatment and improve outcomes for patients.',
    publishedDate: DateTime(2023, 7, 20),
  ),
];