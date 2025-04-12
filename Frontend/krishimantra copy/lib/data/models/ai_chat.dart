import 'ai_chat_message.dart';

class AIChat {
  final String id;
  final String userId;
  final String userName;
  final String userProfilePhoto;
  final String title;
  final List<AIChatMessage> messages;
  final AIMetadata metadata;
  final AIContext context;
  final DateTime lastMessageAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  AIChat({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userProfilePhoto,
    required this.title,
    required this.messages,
    required this.metadata,
    required this.context,
    required this.lastMessageAt,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  AIChat copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userProfilePhoto,
    String? title,
    List<AIChatMessage>? messages,
    AIMetadata? metadata,
    AIContext? context,
    DateTime? lastMessageAt,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AIChat(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userProfilePhoto: userProfilePhoto ?? this.userProfilePhoto,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      metadata: metadata ?? this.metadata,
      context: context ?? this.context,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AIChat.fromJson(Map<String, dynamic> json) {
    return AIChat(
      id: json['_id'],
      userId: json['userId'],
      userName: json['userName'],
      userProfilePhoto: json['userProfilePhoto'],
      title: json['title'],
      messages: (json['messages'] as List)
          .map((msg) => AIChatMessage.fromJson(msg))
          .toList(),
      metadata: AIMetadata.fromJson(json['metadata']),
      context: AIContext.fromJson(json['context']),
      lastMessageAt: DateTime.parse(json['lastMessageAt']),
      isActive: json['isActive'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}

class AIMetadata {
  final String preferredLanguage;
  final Location? location;
  final Weather? weather;

  AIMetadata({
    required this.preferredLanguage,
    this.location,
    this.weather,
  });

  factory AIMetadata.fromJson(Map<String, dynamic> json) {
    return AIMetadata(
      preferredLanguage: json['preferredLanguage'],
      location:
          json['location'] != null ? Location.fromJson(json['location']) : null,
      weather:
          json['weather'] != null ? Weather.fromJson(json['weather']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'preferredLanguage': preferredLanguage,
      if (location != null) 'location': location!.toJson(),
      if (weather != null) 'weather': weather!.toJson(),
    };
  }
}

class Location {
  final double lat;
  final double lon;

  Location({required this.lat, required this.lon});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      lat: json['lat'].toDouble(),
      lon: json['lon'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
    };
  }
}

class Weather {
  final double temperature;
  final double humidity;

  Weather({required this.temperature, required this.humidity});

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      temperature: json['temperature'].toDouble(),
      humidity: json['humidity'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
    };
  }
}

class AIContext {
  final String currentTopic;
  final String lastContext;
  final List<String> identifiedIssues;
  final List<String> suggestedSolutions;

  AIContext({
    required this.currentTopic,
    required this.lastContext,
    required this.identifiedIssues,
    required this.suggestedSolutions,
  });

  factory AIContext.fromJson(Map<String, dynamic> json) {
    return AIContext(
      currentTopic: json['currentTopic'] ?? '',
      lastContext: json['lastContext'] ?? '',
      identifiedIssues: List<String>.from(json['identifiedIssues'] ?? []),
      suggestedSolutions: List<String>.from(json['suggestedSolutions'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentTopic': currentTopic,
      'lastContext': lastContext,
      'identifiedIssues': identifiedIssues,
      'suggestedSolutions': suggestedSolutions,
    };
  }
}
