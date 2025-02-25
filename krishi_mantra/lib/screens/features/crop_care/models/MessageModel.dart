class MessageModel {
  final String id;
  final String content;
  final bool isSentByMe;
  final DateTime timestamp;
  final String? imageUrl;
  final String? mediaType;
  final String senderId;
  final List<String> readBy;
  final List<String> deliveredTo;

  MessageModel({
    required this.id,
    required this.content,
    required this.isSentByMe,
    required this.timestamp,
    this.imageUrl,
    this.mediaType,
    required this.senderId,
    required this.readBy,
    required this.deliveredTo,
  });

  factory MessageModel.fromJson(
      Map<String, dynamic> json, String currentUserId) {
    return MessageModel(
      id: json['_id'] ?? '',
      content: json['content'] ?? '',
      isSentByMe: json['sender'] == currentUserId,
      timestamp: DateTime.parse(json['createdAt']),
      imageUrl: json['mediaUrl'],
      mediaType: json['mediaType'],
      senderId: json['sender'] ?? '',
      readBy: (json['readBy'] as List?)
              ?.map((r) => r['userId'].toString())
              .toList() ??
          [],
      deliveredTo: (json['deliveredTo'] as List?)
              ?.map((d) => d['userId'].toString())
              .toList() ??
          [],
    );
  }

  bool get isRead => readBy.isNotEmpty;
  bool get isDelivered => deliveredTo.isNotEmpty;
}
