import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class NewsItem {
  final String title;
  final String description;
  final String imageUrl;
  final String source;
  final DateTime date;

  NewsItem({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.source,
    required this.date,
  });
}

String formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
}

class NewsPage extends StatefulWidget {
  const NewsPage({Key? key}) : super(key: key);

  @override
  _NewsPageState createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final List<NewsItem> featuredNews = [
    NewsItem(
      title: 'Monsoon Crop Predictions',
      description: 'Experts forecast good rainfall and bumper harvest this season',
      imageUrl: 'https://via.placeholder.com/600',
      source: 'Farmer Today',
      date: DateTime.now(),
    ),
    NewsItem(
      title: 'New Organic Farming Techniques',
      description: 'Revolutionary methods to increase crop yield sustainably',
      imageUrl: 'https://via.placeholder.com/600',
      source: 'Agriculture Weekly',
      date: DateTime.now(),
    ),
    NewsItem(
      title: 'Government Announces Farmer Subsidies',
      description: 'New financial support schemes for small farmers',
      imageUrl: 'https://via.placeholder.com/600',
      source: 'Rural News Network',
      date: DateTime.now(),
    ),
  ];

  final List<NewsItem> regularNews = [
    NewsItem(
      title: 'Drought Resistant Crop Varieties',
      description: 'Scientists develop new seed types for challenging conditions',
      imageUrl: 'https://via.placeholder.com/600',
      source: 'Agricultural Science Today',
      date: DateTime.now().subtract(const Duration(days: 1)),
    ),
    NewsItem(
      title: 'Smart Farming Technology Trends',
      description: 'Latest innovations in agricultural technology',
      imageUrl: 'https://via.placeholder.com/600',
      source: 'Tech Farmer Magazine',
      date: DateTime.now().subtract(const Duration(days: 2)),
    ),
    NewsItem(
      title: 'Sustainable Agriculture Practices',
      description: 'How farmers can reduce environmental impact',
      imageUrl: 'https://via.placeholder.com/600',
      source: 'Green Farming Journal',
      date: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer News'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Image Slider
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: CarouselSlider(
              options: CarouselOptions(
                height: 200,
                autoPlay: true,
                enlargeCenterPage: true,
                aspectRatio: 16 / 9,
                autoPlayCurve: Curves.fastOutSlowIn,
                enableInfiniteScroll: true,
                autoPlayAnimationDuration: const Duration(milliseconds: 800),
                viewportFraction: 0.8,
              ),
              items: featuredNews.map((news) {
                return Builder(
                  builder: (BuildContext context) {
                    return Container(
                      width: MediaQuery.of(context).size.width,
                      margin: const EdgeInsets.symmetric(horizontal: 5.0),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        image: DecorationImage(
                          image: NetworkImage(news.imageUrl),
                          fit: BoxFit.cover,
                        ),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.all(10),
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          news.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          ),

          // Horizontal Ad Banner
          Container(
            height: 60,
            margin: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.grey[200],
            child: const Center(
              child: Text(
                'Advertisement',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),

          // News List
          Expanded(
            child: ListView.builder(
              itemCount: regularNews.length,
              itemBuilder: (context, index) {
                final news = regularNews[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => NewsDetailPage(news: news),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    child: ListTile(
                      leading: Image.network(
                        news.imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                      title: Text(
                        news.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            news.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${news.source} • ${formatDate(news.date)}',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class NewsDetailPage extends StatelessWidget {
  final NewsItem news;

  const NewsDetailPage({Key? key, required this.news}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(news.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              news.imageUrl,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 16),
            Text(
              news.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(news.description),
            const SizedBox(height: 16),
            Text(
              '${news.source} • ${_formatDate(news.date)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}