class Comment {
  final String id;
  final String videoId;
  final String userId;
  final String userName;
  final String? profilePhoto;
  final String content;
  final CommentLikes likes;
  final String? parentComment;
  final List<Comment> replies;
  final int depth;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  Comment({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.userName,
    this.profilePhoto,
    required this.content,
    required this.likes,
    this.parentComment,
    required this.replies,
    required this.depth,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'],
      videoId: json['videoId'],
      userId: json['userId'],
      userName: json['userName'],
      profilePhoto: json['profilePhoto'],
      content: json['content'],
      likes: CommentLikes.fromJson(json['likes']),
      parentComment: json['parentComment'],
      replies: (json['replies'] as List?)
              ?.map((reply) => Comment.fromJson(reply))
              .toList() ??
          [],
      depth: json['depth'] ?? 0,
      isDeleted: json['isDeleted'] ?? false,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class CommentLikes {
  final int count;
  final List<String> users;

  CommentLikes({
    required this.count,
    required this.users,
  });

  factory CommentLikes.fromJson(Map<String, dynamic> json) {
    return CommentLikes(
      count: json['count'] ?? 0,
      users: List<String>.from(json['users'] ?? []),
    );
  }
}
