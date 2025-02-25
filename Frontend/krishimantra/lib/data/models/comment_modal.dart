class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String profilePhoto;
  final String feedId;
  final String content;
  final String? parentComment;
  final List<ReplyModel> replies;
  final int depth;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LikesModel likes;
  final List<dynamic> reports;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.profilePhoto,
    required this.feedId,
    required this.content,
    this.parentComment,
    required this.replies,
    required this.depth,
    required this.isDeleted,
    required this.createdAt,
    required this.updatedAt,
    required this.likes,
    required this.reports,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      profilePhoto: json['profilePhoto'] ?? '',
      feedId: json['feed'] ?? '',
      content: json['content'] ?? '',
      parentComment: json['parentComment'],
      replies: (json['replies'] as List<dynamic>?)
              ?.map((reply) => ReplyModel.fromJson(reply))
              .toList() ??
          [],
      depth: json['depth'] ?? 0,
      isDeleted: json['isDeleted'] ?? false,
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      likes: LikesModel.fromJson(json['likes'] ?? {}),
      reports: json['reports'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'userName': userName,
      'profilePhoto': profilePhoto,
      'feed': feedId,
      'content': content,
      'parentComment': parentComment,
      'replies': replies.map((reply) => reply.toJson()).toList(),
      'depth': depth,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'likes': likes.toJson(),
      'reports': reports,
    };
  }
}

class ReplyModel {
  final String id;
  final String userName;
  final String content;
  final DateTime createdAt;

  String profilePhoto;

  ReplyModel({
    required this.id,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.profilePhoto = '',
  });

  factory ReplyModel.fromJson(Map<String, dynamic> json) {
    return ReplyModel(
      id: json['_id'] ?? '',
      userName: json['userName'] ?? '',
      content: json['content'] ?? '',
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      profilePhoto:
          json['profilePhoto'] ?? '', // Default to empty string if not provided
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userName': userName,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'profilePhoto': profilePhoto,
    };
  }
}

class LikesModel {
  final int count;
  final List<String> users;

  LikesModel({
    required this.count,
    required this.users,
  });

  factory LikesModel.fromJson(Map<String, dynamic> json) {
    return LikesModel(
      count: json['count'] ?? 0,
      users: List<String>.from(json['users'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'count': count,
      'users': users,
    };
  }
}
