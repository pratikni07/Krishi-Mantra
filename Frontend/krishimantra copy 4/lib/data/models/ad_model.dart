class Ad {
  final String id;
  final String title;
  final String content;
  final String dirURL;
  final int priority;
  final DateTime createdAt;

  Ad({
    required this.id,
    required this.title,
    required this.content,
    required this.dirURL,
    required this.priority,
    required this.createdAt,
  });

  factory Ad.fromJson(Map<String, dynamic> json) {
    return Ad(
      id: json['_id'],
      title: json['title'],
      content: json['content'],
      dirURL: json['dirURL'],
      priority: json['prority'], // Note: keeping the typo from API
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
} 