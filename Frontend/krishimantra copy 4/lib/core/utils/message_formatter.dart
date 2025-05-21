import 'package:flutter/material.dart';

class MessageFormatter {
  static String formatBoldText(String text) {
    // Replace **text** with styled text
    final boldPattern = RegExp(r'\*\*(.*?)\*\*');
    return text.replaceAllMapped(boldPattern, (match) {
      return '${match[1]}'; // We'll handle the styling in the widget
    });
  }

  static List<TextSpan> parseMessage(String message,
      {required Color textColor}) {
    List<TextSpan> spans = [];
    List<String> lines = message.split('\n');

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];

      // Handle bullet points and sub-points
      if (line.trim().startsWith('- ')) {
        // Main bullet point
        spans.add(const TextSpan(text: '\n• '));
        line = line.replaceFirst('- ', '');
      } else if (line.trim().startsWith('+ ')) {
        // Sub bullet point
        spans.add(const TextSpan(text: '\n  ○ '));
        line = line.replaceFirst('+ ', '');
      }

      // Handle bold text
      List<TextSpan> lineSpans = _parseBoldText(line, textColor);
      spans.addAll(lineSpans);

      // Add newline if not the last line
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return spans;
  }

  static List<TextSpan> _parseBoldText(String text, Color textColor) {
    List<TextSpan> spans = [];
    RegExp boldPattern = RegExp(r'\*\*(.*?)\*\*');
    int lastIndex = 0;

    // Find all bold text matches
    for (Match match in boldPattern.allMatches(text)) {
      // Add text before bold
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(color: textColor),
        ));
      }

      // Add bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ));

      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(color: textColor),
      ));
    }

    return spans;
  }
}
