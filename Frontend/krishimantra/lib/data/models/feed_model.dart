// // lib/data/models/feed_model.dart
// import 'package:flutter/material.dart';

// class FeedModel {
//   final String id;
//   final String userId;
//   final String userName;
//   final String profilePhoto;
//   final String description;
//   final String content;
//   final String? mediaUrl;
//   final Map<String, dynamic> like;
//   final Map<String, dynamic> comment;
//   final Map<String, dynamic>? location;
//   final DateTime date;
//   final List<dynamic> recentComments;
//   bool isLiked; // Added isLiked property

//   FeedModel({
//     required this.id,
//     required this.userId,
//     required this.userName,
//     required this.profilePhoto,
//     required this.description,
//     required this.content,
//     this.mediaUrl,
//     required this.like,
//     required this.comment,
//     this.location,
//     required this.date,
//     required this.recentComments,
//     this.isLiked = false, // Default value is false
//   });

//   factory FeedModel.fromJson(Map<String, dynamic> json) {
//     return FeedModel(
//       id: json['_id'],
//       userId: json['userId'],
//       userName: json['userName'],
//       profilePhoto: json['profilePhoto'],
//       description: json['description'],
//       content: json['content'],
//       mediaUrl: json['mediaUrl'],
//       like: json['like'],
//       comment: json['comment'],
//       location: json['location'],
//       date: DateTime.parse(json['date']),
//       recentComments: json['recentComments'] ?? [],
//       isLiked: json['isLiked'] ?? false, // Parse isLiked from JSON
//     );
//   }

//   // Method to toggle like status
//   void toggleLike() {
//     isLiked = !isLiked;
//     if (isLiked) {
//       like['count'] = (like['count'] as int) + 1;
//     } else {
//       like['count'] = (like['count'] as int) - 1;
//     }
//   }

//   // Clone method to create a new instance with updated values
//   FeedModel copyWith({
//     String? id,
//     String? userId,
//     String? userName,
//     String? profilePhoto,
//     String? description,
//     String? content,
//     String? mediaUrl,
//     Map<String, dynamic>? like,
//     Map<String, dynamic>? comment,
//     Map<String, dynamic>? location,
//     DateTime? date,
//     List<dynamic>? recentComments,
//     bool? isLiked,
//   }) {
//     return FeedModel(
//       id: id ?? this.id,
//       userId: userId ?? this.userId,
//       userName: userName ?? this.userName,
//       profilePhoto: profilePhoto ?? this.profilePhoto,
//       description: description ?? this.description,
//       content: content ?? this.content,
//       mediaUrl: mediaUrl ?? this.mediaUrl,
//       like: like ?? Map<String, dynamic>.from(this.like),
//       comment: comment ?? Map<String, dynamic>.from(this.comment),
//       location: location ?? this.location,
//       date: date ?? this.date,
//       recentComments: recentComments ?? List.from(this.recentComments),
//       isLiked: isLiked ?? this.isLiked,
//     );
//   }
// }

class FeedModel {
  final String id;
  final String userId;
  final String userName;
  final String profilePhoto;
  final String description;
  final String content;
  final String? mediaUrl;
  final Map<String, dynamic> like;
  final Map<String, dynamic> comment;
  final Map<String, dynamic>? location;
  final DateTime date;
  final List<dynamic> recentComments;
  bool isLiked;

  FeedModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.profilePhoto,
    required this.description,
    required this.content,
    this.mediaUrl,
    required this.like,
    required this.comment,
    this.location,
    required this.date,
    required this.recentComments,
    this.isLiked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'userName': userName,
      'profilePhoto': profilePhoto,
      'description': description,
      'content': content,
      'mediaUrl': mediaUrl,
      'like': like,
      'comment': comment,
      'location': location,
      'date': date.toIso8601String(),
      'recentComments': recentComments,
      'isLiked': isLiked,
    };
  }

  factory FeedModel.fromJson(Map<String, dynamic> json) {
    return FeedModel(
      id: json['_id'],
      userId: json['userId'],
      userName: json['userName'],
      profilePhoto: json['profilePhoto'],
      description: json['description'],
      content: json['content'],
      mediaUrl: json['mediaUrl'],
      like: json['like'],
      comment: json['comment'],
      location: json['location'],
      date: DateTime.parse(json['date']),
      recentComments: json['recentComments'] ?? [],
      isLiked: json['isLiked'] ?? false,
    );
  }

  void toggleLike() {
    isLiked = !isLiked;
    if (isLiked) {
      like['count'] = (like['count'] as int) + 1;
    } else {
      like['count'] = (like['count'] as int) - 1;
    }
  }

  FeedModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? profilePhoto,
    String? description,
    String? content,
    String? mediaUrl,
    Map<String, dynamic>? like,
    Map<String, dynamic>? comment,
    Map<String, dynamic>? location,
    DateTime? date,
    List<dynamic>? recentComments,
    bool? isLiked,
  }) {
    return FeedModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      description: description ?? this.description,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      like: like ?? Map<String, dynamic>.from(this.like),
      comment: comment ?? Map<String, dynamic>.from(this.comment),
      location: location ?? this.location,
      date: date ?? this.date,
      recentComments: recentComments ?? List.from(this.recentComments),
      isLiked: isLiked ?? this.isLiked,
    );
  }
}
