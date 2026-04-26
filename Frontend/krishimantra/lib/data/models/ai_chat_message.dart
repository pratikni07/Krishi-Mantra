// lib/data/models/ai_chat_message.dart

/// Voice metadata attached to a chat message. Mirrors the server-side
/// `AIChat.messages[].voice` block.
class VoiceMeta {
  final String kind; // "user_voice" | "assistant_voice"
  final String? transcript;       // user side
  final String? language;
  final double? confidence;
  final double? durationSec;
  final String? messageId;        // assistant side, for /replay
  final String? voiceName;
  final String? audioMime;
  final bool transcribing;        // user side: STT in flight
  final bool transcribingFailed;
  final double? sttCostUsd;
  final double? ttsCostUsd;

  const VoiceMeta({
    required this.kind,
    this.transcript,
    this.language,
    this.confidence,
    this.durationSec,
    this.messageId,
    this.voiceName,
    this.audioMime,
    this.transcribing = false,
    this.transcribingFailed = false,
    this.sttCostUsd,
    this.ttsCostUsd,
  });

  factory VoiceMeta.userPlaceholder() => const VoiceMeta(
        kind: 'user_voice',
        transcribing: true,
      );

  factory VoiceMeta.assistantPlaceholder() => const VoiceMeta(
        kind: 'assistant_voice',
      );

  factory VoiceMeta.fromJson(Map<String, dynamic> json) => VoiceMeta(
        kind: json['kind']?.toString() ?? 'user_voice',
        transcript: json['transcript']?.toString(),
        language: json['language']?.toString(),
        confidence: (json['confidence'] as num?)?.toDouble(),
        durationSec: (json['durationSec'] as num?)?.toDouble(),
        messageId: json['messageId']?.toString(),
        voiceName: json['voiceName']?.toString(),
        audioMime: json['audioMime']?.toString(),
        transcribing: json['transcribing'] == true,
        transcribingFailed: json['transcribingFailed'] == true,
        sttCostUsd: (json['sttCostUsd'] as num?)?.toDouble(),
        ttsCostUsd: (json['ttsCostUsd'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (transcript != null) 'transcript': transcript,
        if (language != null) 'language': language,
        if (confidence != null) 'confidence': confidence,
        if (durationSec != null) 'durationSec': durationSec,
        if (messageId != null) 'messageId': messageId,
        if (voiceName != null) 'voiceName': voiceName,
        if (audioMime != null) 'audioMime': audioMime,
        if (transcribing) 'transcribing': true,
        if (transcribingFailed) 'transcribingFailed': true,
      };

  VoiceMeta copyWith({
    String? transcript,
    String? language,
    double? confidence,
    double? durationSec,
    String? messageId,
    String? voiceName,
    String? audioMime,
    bool? transcribing,
    bool? transcribingFailed,
    double? sttCostUsd,
    double? ttsCostUsd,
  }) =>
      VoiceMeta(
        kind: kind,
        transcript: transcript ?? this.transcript,
        language: language ?? this.language,
        confidence: confidence ?? this.confidence,
        durationSec: durationSec ?? this.durationSec,
        messageId: messageId ?? this.messageId,
        voiceName: voiceName ?? this.voiceName,
        audioMime: audioMime ?? this.audioMime,
        transcribing: transcribing ?? this.transcribing,
        transcribingFailed: transcribingFailed ?? this.transcribingFailed,
        sttCostUsd: sttCostUsd ?? this.sttCostUsd,
        ttsCostUsd: ttsCostUsd ?? this.ttsCostUsd,
      );

  bool get hasLowConfidence =>
      confidence != null && confidence! > 0 && confidence! < 0.6;
}

class AIChatMessage {
  final String role;
  final String content;
  final String? imageUrl;
  final List<String>? localImagePaths;
  final DateTime timestamp;
  final VoiceMeta? voice;

  AIChatMessage({
    required this.role,
    required this.content,
    this.imageUrl,
    this.localImagePaths,
    required this.timestamp,
    this.voice,
  });

  bool get hasImages =>
      (localImagePaths != null && localImagePaths!.isNotEmpty) ||
      (imageUrl != null && imageUrl!.isNotEmpty);

  String? get firstImagePath {
    if (localImagePaths != null && localImagePaths!.isNotEmpty) {
      return localImagePaths!.first;
    }
    return imageUrl;
  }

  bool get hasLocalImages =>
      localImagePaths != null && localImagePaths!.isNotEmpty;

  bool get isVoice => voice != null;
  bool get isVoiceTranscribing => voice?.transcribing == true;

  factory AIChatMessage.fromJson(Map<String, dynamic> json) {
    return AIChatMessage(
      role: json['role'] ?? 'user',
      content: json['content'] ?? '',
      imageUrl: json['imageUrl'],
      localImagePaths: json['localImagePaths'] != null
          ? List<String>.from(json['localImagePaths'])
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      voice: json['voice'] is Map<String, dynamic>
          ? VoiceMeta.fromJson(Map<String, dynamic>.from(json['voice']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (localImagePaths != null) 'localImagePaths': localImagePaths,
      'timestamp': timestamp.toIso8601String(),
      if (voice != null) 'voice': voice!.toJson(),
    };
  }

  AIChatMessage copyWith({
    String? role,
    String? content,
    String? imageUrl,
    List<String>? localImagePaths,
    DateTime? timestamp,
    VoiceMeta? voice,
    bool clearVoice = false,
  }) =>
      AIChatMessage(
        role: role ?? this.role,
        content: content ?? this.content,
        imageUrl: imageUrl ?? this.imageUrl,
        localImagePaths: localImagePaths ?? this.localImagePaths,
        timestamp: timestamp ?? this.timestamp,
        voice: clearVoice ? null : (voice ?? this.voice),
      );
}
