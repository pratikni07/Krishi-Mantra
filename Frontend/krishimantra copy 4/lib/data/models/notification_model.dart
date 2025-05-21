// Notification model with manual JSON serialization
class NotificationModel {
  final String? id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String status;
  final String priority;
  final String category;
  final String scheduledFor;
  final String createdAt;
  final String updatedAt;
  final String? pushId;

  NotificationModel({
    this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.data,
    this.status = 'pending',
    this.priority = 'medium',
    this.category = 'system',
    required this.scheduledFor,
    required this.createdAt,
    required this.updatedAt,
    this.pushId,
  });

  // Manual fromJson implementation
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? json['_id'],
      userId: json['userId'],
      type: json['type'],
      title: json['title'],
      body: json['body'],
      data: json['data'],
      status: json['status'] ?? 'pending',
      priority: json['priority'] ?? 'medium',
      category: json['category'] ?? 'system',
      scheduledFor: json['scheduledFor'] ?? DateTime.now().toIso8601String(),
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      updatedAt: json['updatedAt'] ?? DateTime.now().toIso8601String(),
      pushId: json['pushId'],
    );
  }

  // Manual toJson implementation
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      if (data != null) 'data': data,
      'status': status,
      'priority': priority,
      'category': category,
      'scheduledFor': scheduledFor,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      if (pushId != null) 'pushId': pushId,
    };
  }
} 