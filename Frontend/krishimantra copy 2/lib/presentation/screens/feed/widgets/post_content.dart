import 'package:flutter/material.dart';

class PostContent extends StatefulWidget {
  final Map<String, dynamic> feed;

  const PostContent({
    Key? key,
    required this.feed,
  }) : super(key: key);

  @override
  _PostContentState createState() => _PostContentState();
}

class _PostContentState extends State<PostContent> {
  bool _isExpanded = false;
  static const int _maxLength = 100; // Limit before truncating text

  @override
  Widget build(BuildContext context) {
    String content = widget.feed['content'];
    bool isLongText = content.length > _maxLength;

    String displayText = isLongText && !_isExpanded
        ? content.substring(0, _maxLength) + '...'
        : content;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRichText(displayText),
          if (isLongText)
            TextButton(
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Text(_isExpanded ? "Show Less" : "Show More"),
            ),
        ],
      ),
    );
  }

  Widget _buildRichText(String text) {
    List<TextSpan> spans = [];
    RegExp regex = RegExp(r"#\w+"); // Regex to find hashtags
    Iterable<RegExpMatch> matches = regex.allMatches(text);

    int lastIndex = 0;
    for (var match in matches) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style:
              const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 16, color: Colors.black),
        children: spans,
      ),
    );
  }
}
