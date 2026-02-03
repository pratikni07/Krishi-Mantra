// lib/data/models/ai_chat_message.dart
class AIChatMessage {
  final String role;
  final String content;
  final String? imageUrl;
  final List<String>? localImagePaths; // Local file paths for images not yet uploaded or for display
  final DateTime timestamp;

  AIChatMessage({
    required this.role,
    required this.content,
    this.imageUrl,
    this.localImagePaths,
    required this.timestamp,
  });

  /// Check if this message has images (either local or remote)
  bool get hasImages =>
      (localImagePaths != null && localImagePaths!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  /// Get the first image path (local or remote) for display
  String? get firstImagePath {
    if (localImagePaths != null && localImagePaths!.isNotEmpty) {
      return localImagePaths!.first;
    }
    return imageUrl;
  }

  /// Check if images are local files
  bool get hasLocalImages =>
      localImagePaths != null && localImagePaths!.isNotEmpty;

  factory AIChatMessage.fromJson(Map<String, dynamic> json) {
    return AIChatMessage(
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'],
      localImagePaths: json['localImagePaths'] != null
          ? List<String>.from(json['localImagePaths'])
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (localImagePaths != null) 'localImagePaths': localImagePaths,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
