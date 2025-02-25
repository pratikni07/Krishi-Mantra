// feed_post.dart
import 'package:krishi_mantra/screens/components/PostCard.dart';

class FeedPost {
  final String id;
  final String userId;
  final String userName;
  final String profilePhoto;
  final String description;
  final String content;
  final String? mediaUrl;
  final LikeInfo like;
  final CommentInfo comment;
  final Location? location;
  final DateTime date;
  final List<Comment> recentComments;

  FeedPost({
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
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: json['_id'],
      userId: json['userId'],
      userName: json['userName'],
      profilePhoto: json['profilePhoto'],
      description: json['description'],
      content: json['content'],
      mediaUrl: json['mediaUrl'],
      like: LikeInfo.fromJson(json['like']),
      comment: CommentInfo.fromJson(json['comment']),
      location:
          json['location'] != null ? Location.fromJson(json['location']) : null,
      date: DateTime.parse(json['date']),
      recentComments: (json['recentComments'] as List?)
              ?.map((e) => Comment.fromJson(e))
              .toList() ??
          [],
    );
  }

  MediaType get mediaType {
    if (mediaUrl == null) return MediaType.none;
    if (mediaUrl!.toLowerCase().endsWith('.mp4')) return MediaType.video;
    return MediaType.image;
  }
}

class LikeInfo {
  final int count;

  LikeInfo({required this.count});

  factory LikeInfo.fromJson(Map<String, dynamic> json) {
    return LikeInfo(count: json['count'] ?? 0);
  }
}

class CommentInfo {
  final int count;

  CommentInfo({required this.count});

  factory CommentInfo.fromJson(Map<String, dynamic> json) {
    return CommentInfo(count: json['count'] ?? 0);
  }
}

class Location {
  final double latitude;
  final double longitude;

  Location({required this.latitude, required this.longitude});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
    );
  }
}

class Comment {
  final String id;
  final String userId;
  final String userName;
  final String profilePhoto;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.profilePhoto,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'],
      userId: json['userId'],
      userName: json['userName'],
      profilePhoto: json['profilePhoto'],
      content: json['content'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}
