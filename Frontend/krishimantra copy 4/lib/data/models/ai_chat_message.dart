// lib/data/models/ai_chat_message.dart
class AIChatMessage {
  final String role;
  final String content;
  final String? imageUrl;
  final DateTime timestamp;

  AIChatMessage({
    required this.role,
    required this.content,
    this.imageUrl,
    required this.timestamp,
  });

  factory AIChatMessage.fromJson(Map<String, dynamic> json) {
    return AIChatMessage(
      role: json['role'],
      content: json['content'],
      imageUrl: json['imageUrl'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
