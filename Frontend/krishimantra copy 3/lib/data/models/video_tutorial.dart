class VideoTutorial {
  final String id;
  final String userId;
  final String userName;
  final String? profilePhoto;
  final String title;
  final String? description;
  final String thumbnail;
  final String videoUrl;
  final String videoType;
  final int? duration;
  final List<String> tags;
  final String category;
  final String visibility;
  final VideoStats likes;
  final VideoStats views;
  final VideoStats comments;
  final DateTime createdAt;
  final DateTime updatedAt;

  VideoTutorial({
    required this.id,
    required this.userId,
    required this.userName,
    this.profilePhoto,
    required this.title,
    this.description,
    required this.thumbnail,
    required this.videoUrl,
    required this.videoType,
    this.duration,
    required this.tags,
    required this.category,
    required this.visibility,
    required this.likes,
    required this.views,
    required this.comments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VideoTutorial.fromJson(Map<String, dynamic> json) {
    // Handle potential null or missing values in the JSON
    final likes =
        json['likes'] is Map ? json['likes'] : {'count': 0, 'users': []};
    final views =
        json['views'] is Map ? json['views'] : {'count': 0, 'unique': []};
    final comments = json['comments'] is Map ? json['comments'] : {'count': 0};

    return VideoTutorial(
      id: json['_id'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Unknown',
      profilePhoto: json['profilePhoto'],
      title: json['title'] ?? 'Untitled',
      description: json['description'],
      thumbnail: json['thumbnail'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      videoType: json['videoType'] ?? 'unknown',
      duration: json['duration'],
      tags: List<String>.from(json['tags'] ?? []),
      category: json['category'] ?? 'Uncategorized',
      visibility: json['visibility'] ?? 'public',
      likes: VideoStats.fromJson({
        'count': likes['count'] ?? 0,
        'users': likes['users'] ?? [],
      }),
      views: VideoStats.fromJson({
        'count': views['count'] ?? 0,
        'unique': views['unique'] ?? [],
      }),
      comments: VideoStats.fromJson({
        'count': comments['count'] ?? 0,
        'users': [],
      }),
      createdAt:
          DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class VideoStats {
  final int count;
  final List<String> users;

  VideoStats({
    required this.count,
    required this.users,
  });

  factory VideoStats.fromJson(Map<String, dynamic> json) {
    // Handle count that might come as either int, double, or String
    final dynamic rawCount = json['count'] ?? 0;
    int count;

    if (rawCount is int) {
      count = rawCount;
    } else if (rawCount is double) {
      count = rawCount.toInt();
    } else if (rawCount is String) {
      count = int.tryParse(rawCount) ?? 0;
    } else {
      count = 0;
    }

    return VideoStats(
      count: count,
      users: List<String>.from(json['users'] ?? json['unique'] ?? []),
    );
  }
}

class Comment {
  final String id;
  final String videoId;
  final String userId;
  final String userName;
  final String? profilePhoto;
  final String content;
  final VideoStats likes;
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
      likes: VideoStats.fromJson(json['likes']),
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
