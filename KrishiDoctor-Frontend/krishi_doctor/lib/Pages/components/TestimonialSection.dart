import 'package:flutter/material.dart';

class TestimonialSection extends StatefulWidget {
  @override
  _TestimonialSectionState createState() => _TestimonialSectionState();
}

class _TestimonialSectionState extends State<TestimonialSection> {
  final List<Map<String, String>> _testimonials = [
    {
      'text': 'फार्मर केअर अपुणले माझ्या पिकाची निगा राखणे खूप सोपे झाले आहे. हवामानाचा अचूक अंदाज आणि काठीनिर्यक्षणाचे उपाय वेळेवर मिळाल्यामुळे मोठा नुकसान टळला.',
      'author': '- संतोष जगताप, शेतारा'
    },
    {
      'text': 'फार्मर केअरने माझ्या पिकांची काळजी घेतली आणि त्यांच्या विकासाला चालना दिली. यामुळे माझ्या उत्पादनात वाढ झाली आणि मला चांगला परतावा मिळाला.',
      'author': '- राजेश कुलकर्णी, शेतकरी'
    },
    {
      'text': 'फार्मर केअरच्या सेवांमुळे माझ्या फळबागेची निगा राखण्यास मला मोठी मदत झाली. त्यांच्या तज्ञ सल्ल्यांनुसार करण्यात आलेल्या उपक्रमांमुळे माझ्या पिकांचा उत्कृष्ट दर्जा राखला गेला.',
      'author': '- विजय पाटील, बागायतदार'
    },
    {
      'text': 'फार्मर केअरच्या माध्यमातून मला माझ्या पिकांच्या समस्यांचे उत्तम निराकरण मिळाले. त्यांच्या नियमित सल्ल्यांमुळे मी माझी शेती उत्तम रीतीने चालवू शकलो.',
      'author': '- अनिल देशमुख, शेतकरी'
    },
    {
      'text': 'फार्मर केअर अपुणले माझ्या पिकाची निगा राखणे खूप सोपे झाले आहे. हवामानाचा अचूक अंदाज आणि काठीनिर्यक्षणाचे उपाय वेळेवर मिळाल्यामुळे मोठा नुकसान टळला.',
      'author': '- संतोष जगताप, शेतारा'
    },
  ];

  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Center(
              child: Text(
              'यशोगाथा',
              style: TextStyle(
                fontSize: 22.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C6758),
              ),
            ),
            )
            
          ),
          SizedBox(height: 10.0),
          SizedBox(
            height: 150.0,
            child: PageView.builder(
              itemCount: _testimonials.length,
              controller: PageController(viewportFraction: 0.9),
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return TestimonialCard(
                  testimonial: _testimonials[index],
                  isActive: index == _currentIndex,
                );
              },
            ),
          ),
          SizedBox(height: 15.0),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                _testimonials.length,
                (index) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4.0),
                  child: Icon(
                    Icons.fiber_manual_record,
                    color: index == _currentIndex
                        ? Color(0xFF1C6758)
                        : Color(0xFFCCCCCC),
                    size: 12.0,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TestimonialCard extends StatelessWidget {
  final Map<String, String> testimonial;
  final bool isActive;

  TestimonialCard({required this.testimonial, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: isActive ? 10.0 : 10.0),
      child: Container(
        width: 300.0,
        padding: EdgeInsets.all(13.0),
        decoration: BoxDecoration(
          color: Colors.white, // Set background to white
          borderRadius: BorderRadius.circular(10.0),
          border: Border.all(color: const Color(0xFF008336)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                testimonial['text']!,
                style: const TextStyle(
                  fontSize: 16.0,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            Text(
              testimonial['author']!,
              style: const TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1C6758),
              ),
            ),
          ],
        ),
      ),
    );
  }
}