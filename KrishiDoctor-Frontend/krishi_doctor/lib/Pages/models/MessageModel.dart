class MessageModel {
  final String text;
  final bool isSentByMe;
  final DateTime timestamp;
  final String? imageUrl;
  final String? fileUrl;
  final String? videoUrl;
  final List<String>? reactions;
  
  // New properties for poll
  final bool isPoll;
  final List<String>? pollOptions;
  final List<int>? pollVotes;

  MessageModel({
    required this.text,
    required this.isSentByMe,
    required this.timestamp,
    this.imageUrl,
    this.fileUrl,
    this.videoUrl,
    this.reactions,
    
    // Add default values for new poll-related properties
    this.isPoll = false,
    this.pollOptions,
    this.pollVotes,
  });
}