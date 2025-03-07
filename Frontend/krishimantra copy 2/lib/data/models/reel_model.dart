class ReelModel {
  final String id;
  final String userId;
  final String userName;
  final String profilePhoto;
  final String description;
  final String mediaUrl;
  final Map<String, dynamic> like;
  final Map<String, dynamic> comment;
  final Map<String, dynamic> location;
  final DateTime date;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReelModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.profilePhoto,
    required this.description,
    required this.mediaUrl,
    required this.like,
    required this.comment,
    required this.location,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    return ReelModel(
      id: json['_id'],
      userId: json['userId'],
      userName: json['userName'],
      profilePhoto: json['profilePhoto'],
      description: json['description'],
      mediaUrl: json['mediaUrl'],
      like: json['like'],
      comment: json['comment'],
      location: json['location'],
      date: DateTime.parse(json['date']),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  ReelModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? profilePhoto,
    String? description,
    String? mediaUrl,
    Map<String, dynamic>? like,
    Map<String, dynamic>? comment,
    Map<String, dynamic>? location,
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReelModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      description: description ?? this.description,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      like: like ?? this.like,
      comment: comment ?? this.comment,
      location: location ?? this.location,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}