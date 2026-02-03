/// Video URLs for different formats/quality levels
class VideoUrls {
  final String? hls;  // HLS streaming (adaptive bitrate) - PRIMARY
  final String? mp4;  // Direct MP4 fallback
  final String? webm; // WebM format

  VideoUrls({this.hls, this.mp4, this.webm});

  factory VideoUrls.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VideoUrls();
    return VideoUrls(
      hls: json['hls'],
      mp4: json['mp4'],
      webm: json['webm'],
    );
  }

  Map<String, dynamic> toJson() => {
    'hls': hls,
    'mp4': mp4,
    'webm': webm,
  };
}

/// Video metadata (duration, dimensions, etc.)
class VideoMeta {
  final int? duration;  // Duration in seconds
  final int? width;
  final int? height;
  final int? size;      // File size in bytes
  final String? format;

  VideoMeta({this.duration, this.width, this.height, this.size, this.format});

  factory VideoMeta.fromJson(Map<String, dynamic>? json) {
    if (json == null) return VideoMeta();
    return VideoMeta(
      duration: json['duration'],
      width: json['width'],
      height: json['height'],
      size: json['size'],
      format: json['format'],
    );
  }

  Map<String, dynamic> toJson() => {
    'duration': duration,
    'width': width,
    'height': height,
    'size': size,
    'format': format,
  };
}

class ReelModel {
  final String id;
  final String userId;
  final String userName;
  final String profilePhoto;
  final String description;
  final String mediaUrl;      // Primary video URL (HLS preferred)
  final VideoUrls? videoUrls; // Alternative formats for fallback
  final String? cloudinaryId; // For video management
  final String thumbnail;
  final String? preview;      // Animated preview (like Instagram)
  final VideoMeta? videoMeta; // Video metadata
  final Map<String, dynamic> like;
  final Map<String, dynamic> comment;
  final Map<String, dynamic> location;
  final List<String> tags;
  final String? category;
  final int viewCount;
  final double? recommendationScore;
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
    this.videoUrls,
    this.cloudinaryId,
    required this.thumbnail,
    this.preview,
    this.videoMeta,
    required this.like,
    required this.comment,
    required this.location,
    this.tags = const [],
    this.category,
    this.viewCount = 0,
    this.recommendationScore,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get the best video URL based on format support
  /// Prefers HLS for adaptive streaming, falls back to MP4
  String get bestVideoUrl {
    // If we have videoUrls, prefer HLS for streaming
    if (videoUrls != null) {
      if (videoUrls!.hls != null && videoUrls!.hls!.isNotEmpty) {
        return videoUrls!.hls!;
      }
      if (videoUrls!.mp4 != null && videoUrls!.mp4!.isNotEmpty) {
        return videoUrls!.mp4!;
      }
    }
    // Fallback to mediaUrl
    return mediaUrl;
  }

  /// Check if this reel uses HLS streaming
  bool get isHlsStreaming {
    return mediaUrl.endsWith('.m3u8') ||
           (videoUrls?.hls != null && videoUrls!.hls!.endsWith('.m3u8'));
  }

  /// Get video duration in formatted string (MM:SS)
  String get formattedDuration {
    final duration = videoMeta?.duration ?? 0;
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory ReelModel.fromJson(Map<String, dynamic> json) {
    // Ensure the like field has the correct structure with isLiked
    final likeData = json['like'] ?? {};
    if (likeData is Map<String, dynamic>) {
      // Make sure isLiked is properly handled
      likeData['isLiked'] = likeData['isLiked'] ?? false;
      likeData['count'] = likeData['count'] ?? 0;
    }

    // Parse tags array
    List<String> tags = [];
    if (json['tags'] != null && json['tags'] is List) {
      tags = List<String>.from(json['tags']);
    }

    return ReelModel(
      id: json['_id'],
      userId: json['userId'],
      userName: json['userName'],
      profilePhoto: json['profilePhoto'] ?? '',
      description: json['description'] ?? '',
      mediaUrl: json['mediaUrl'],
      videoUrls: VideoUrls.fromJson(json['videoUrls']),
      cloudinaryId: json['cloudinaryId'],
      thumbnail: json['thumbnail'] ?? '',
      preview: json['preview'],
      videoMeta: VideoMeta.fromJson(json['videoMeta']),
      like: likeData,
      comment: json['comment'] ?? {'count': 0},
      location: json['location'] ?? {},
      tags: tags,
      category: json['category'],
      viewCount: json['viewCount'] ?? 0,
      recommendationScore: json['finalScore']?.toDouble() ?? json['recommendationScore']?.toDouble(),
      date: DateTime.parse(json['date'] ?? json['createdAt']),
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
    VideoUrls? videoUrls,
    String? cloudinaryId,
    String? thumbnail,
    String? preview,
    VideoMeta? videoMeta,
    Map<String, dynamic>? like,
    Map<String, dynamic>? comment,
    Map<String, dynamic>? location,
    List<String>? tags,
    String? category,
    int? viewCount,
    double? recommendationScore,
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
      videoUrls: videoUrls ?? this.videoUrls,
      cloudinaryId: cloudinaryId ?? this.cloudinaryId,
      thumbnail: thumbnail ?? this.thumbnail,
      preview: preview ?? this.preview,
      videoMeta: videoMeta ?? this.videoMeta,
      like: like ?? this.like,
      comment: comment ?? this.comment,
      location: location ?? this.location,
      tags: tags ?? this.tags,
      category: category ?? this.category,
      viewCount: viewCount ?? this.viewCount,
      recommendationScore: recommendationScore ?? this.recommendationScore,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Model for user interest data
class UserInterestModel {
  final List<InterestTag> interests;
  final String engagementLevel;
  final InteractionCounts interactionCounts;
  final DateTime? lastActive;

  UserInterestModel({
    required this.interests,
    required this.engagementLevel,
    required this.interactionCounts,
    this.lastActive,
  });

  factory UserInterestModel.fromJson(Map<String, dynamic> json) {
    return UserInterestModel(
      interests: (json['interests'] as List?)
              ?.map((e) => InterestTag.fromJson(e))
              .toList() ??
          [],
      engagementLevel: json['engagementLevel'] ?? 'low',
      interactionCounts:
          InteractionCounts.fromJson(json['interactionCounts'] ?? {}),
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'])
          : null,
    );
  }
}

class InterestTag {
  final String tag;
  final double score;
  final DateTime? lastInteraction;

  InterestTag({
    required this.tag,
    required this.score,
    this.lastInteraction,
  });

  factory InterestTag.fromJson(Map<String, dynamic> json) {
    return InterestTag(
      tag: json['tag'] ?? '',
      score: (json['score'] ?? 0).toDouble(),
      lastInteraction: json['lastInteraction'] != null
          ? DateTime.parse(json['lastInteraction'])
          : null,
    );
  }
}

class InteractionCounts {
  final int views;
  final int likes;
  final int comments;
  final int shares;

  InteractionCounts({
    required this.views,
    required this.likes,
    required this.comments,
    required this.shares,
  });

  factory InteractionCounts.fromJson(Map<String, dynamic> json) {
    return InteractionCounts(
      views: json['views'] ?? 0,
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      shares: json['shares'] ?? 0,
    );
  }
}