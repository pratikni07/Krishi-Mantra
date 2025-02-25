// message_model.dart
import 'package:get/get.dart';
import 'package:intl/intl.dart'; // Add this import to your pubspec.yaml if not already present

class DeliveredTo {
  final String userId;
  final String userName;
  final String profilePhoto;
  final DateTime deliveredAt;
  final String id;

  DeliveredTo({
    required this.userId,
    required this.userName,
    required this.profilePhoto,
    required this.deliveredAt,
    required this.id,
  });

  factory DeliveredTo.fromJson(Map<String, dynamic> json) => DeliveredTo(
        userId: json['userId'],
        userName: json['userName'],
        profilePhoto: json['profilePhoto'],
        deliveredAt: DateTime.parse(json['deliveredAt']),
        id: json['_id'],
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userName': userName,
        'profilePhoto': profilePhoto,
        'deliveredAt': deliveredAt.toIso8601String(),
        '_id': id,
      };
}

class ReadByUser {
  final String userId;
  final String userName;
  final String? profilePhoto;

  ReadByUser({
    required this.userId,
    required this.userName,
    this.profilePhoto,
  });

  factory ReadByUser.fromJson(Map<String, dynamic> json) => ReadByUser(
        userId: json['userId'] ?? '',
        userName: json['userName'] ?? '',
        profilePhoto: json['profilePhoto'],
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userName': userName,
        if (profilePhoto != null) 'profilePhoto': profilePhoto,
      };
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String content;
  final String mediaType;
  final List<DeliveredTo> deliveredTo;
  final bool isDeleted;
  final List<ReadByUser>
      readBy; // Changed from List<String> to List<ReadByUser>
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.content,
    required this.mediaType,
    required this.deliveredTo,
    required this.isDeleted,
    required this.readBy,
    required this.createdAt,
    required this.updatedAt,
  });

  // Format date for display
  String get formattedCreatedAt {
    return DateFormat('MMM dd, yyyy HH:mm').format(createdAt);
  }

  String get formattedUpdatedAt {
    return DateFormat('MMM dd, yyyy HH:mm').format(updatedAt);
  }

  // Get time only for chat bubbles
  String get messageTime {
    return DateFormat('HH:mm').format(createdAt);
  }

  // Get date for grouping messages
  String get messageDate {
    return DateFormat('MMM dd, yyyy').format(createdAt);
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    try {
      return Message(
        id: json['_id'] ?? '',
        chatId: json['chatId'] ?? '',
        senderId: json['sender'] ?? '',
        senderName: json['senderName'] ?? '',
        senderPhoto: json['senderPhoto'],
        content: json['content'] ?? '',
        mediaType: json['mediaType'] ?? 'text',
        deliveredTo: (json['deliveredTo'] as List?)
                ?.map((x) => DeliveredTo.fromJson(x))
                .toList() ??
            [],
        isDeleted: json['isDeleted'] ?? false,
        readBy: (json['readBy'] as List?)
                ?.map((x) => ReadByUser.fromJson(x))
                .toList() ??
            [],
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'])
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'])
            : DateTime.now(),
      );
    } catch (e) {
      print('Error parsing message: $e');
      print('Problematic JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'chatId': chatId,
        'sender': senderId,
        'senderName': senderName,
        'senderPhoto': senderPhoto,
        'content': content,
        'mediaType': mediaType,
        'deliveredTo': deliveredTo.map((x) => x.toJson()).toList(),
        'isDeleted': isDeleted,
        'readBy': readBy.map((x) => x.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  List<String> get readByUserIds => readBy.map((user) => user.userId).toList();

  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? senderName,
    String? senderPhoto,
    String? content,
    String? mediaType,
    List<DeliveredTo>? deliveredTo,
    bool? isDeleted,
    List<ReadByUser>? readBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Message(
        id: id ?? this.id,
        chatId: chatId ?? this.chatId,
        senderId: senderId ?? this.senderId,
        senderName: senderName ?? this.senderName,
        senderPhoto: senderPhoto ?? this.senderPhoto,
        content: content ?? this.content,
        mediaType: mediaType ?? this.mediaType,
        deliveredTo: deliveredTo ?? this.deliveredTo,
        isDeleted: isDeleted ?? this.isDeleted,
        readBy: readBy ?? this.readBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

// chat_model.dart
class Participant {
  final String userId;
  final String userName;
  final String profilePhoto;
  final String id;

  Participant({
    required this.userId,
    required this.userName,
    required this.profilePhoto,
    required this.id,
  });

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        userId: json['userId'],
        userName: json['userName'],
        profilePhoto: json['profilePhoto'],
        id: json['_id'],
      );

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'userName': userName,
        'profilePhoto': profilePhoto,
        '_id': id,
      };
}

class Chat {
  final String id;
  final String type;
  final List<Participant> participants;
  final Map<String, int> unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastMessage;
  final List<Message>? lastMessageDetails;
  final GroupDetails? groupDetails;
  final List<Participant> otherParticipants;

  Chat({
    required this.id,
    required this.type,
    required this.participants,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessage,
    this.lastMessageDetails,
    this.groupDetails,
    required this.otherParticipants,
  });

  factory Chat.fromJson(Map<String, dynamic> json) => Chat(
        id: json['_id'] ?? '',
        type: json['type'] ?? '',
        participants: (json['participants'] as List?)
            ?.map((x) => Participant.fromJson(x))
            .toList() ?? [],
        unreadCount: Map<String, int>.from(json['unreadCount'] ?? {}),
        createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
        lastMessage: json['lastMessage'],
        lastMessageDetails: (json['lastMessageDetails'] as List?)
            ?.map((x) => Message.fromJson(x))
            .toList(),
        groupDetails: json['groupDetails'] != null 
            ? (json['groupDetails'] is List && (json['groupDetails'] as List).isNotEmpty)
                ? GroupDetails.fromJson(json['groupDetails'][0])
                : json['groupDetails'] is Map
                    ? GroupDetails.fromJson(json['groupDetails'])
                    : null
            : null,
        otherParticipants: (json['otherParticipants'] as List?)
            ?.map((x) => Participant.fromJson(x))
            .toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'type': type,
    'participants': participants.map((x) => x.toJson()).toList(),
    'unreadCount': unreadCount,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'lastMessage': lastMessage,
    'lastMessageDetails': lastMessageDetails?.map((x) => x.toJson()).toList(),
    'groupDetails': groupDetails != null ? {
      '_id': groupDetails!.id,
      'chatId': groupDetails!.chatId,
      'name': groupDetails!.name,
      'description': groupDetails!.description,
      'admin': groupDetails!.admin,
      'onlyAdminCanMessage': groupDetails!.onlyAdminCanMessage,
      'inviteUrl': groupDetails!.inviteUrl,
      'memberCount': groupDetails!.memberCount,
      'createdAt': groupDetails!.createdAt.toIso8601String(),
      'updatedAt': groupDetails!.updatedAt.toIso8601String(),
    } : null,
    'otherParticipants': otherParticipants.map((x) => x.toJson()).toList(),
  };
}

// group_model.dart
class GroupDetails {
  final String id;
  final String chatId;
  final String name;
  final String description;
  final List<String> admin;
  final bool onlyAdminCanMessage;
  final String inviteUrl;
  final int memberCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  GroupDetails({
    required this.id,
    required this.chatId,
    required this.name,
    required this.description,
    required this.admin,
    required this.onlyAdminCanMessage,
    required this.inviteUrl,
    required this.memberCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory GroupDetails.fromJson(Map<String, dynamic> json) => GroupDetails(
        id: json['_id'] ?? '',
        chatId: json['chatId'] ?? '',
        name: json['name'] ?? '',
        description: json['description'] ?? '',
        admin: List<String>.from(json['admin'] ?? []),
        onlyAdminCanMessage: json['onlyAdminCanMessage'] ?? false,
        inviteUrl: json['inviteUrl'] ?? '',
        memberCount: json['memberCount'] ?? 0,
        createdAt: DateTime.parse(json['createdAt'] ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(json['updatedAt'] ?? DateTime.now().toIso8601String()),
      );
}

class GroupChat {
  final Chat? chat;
  final GroupDetails? group;

  GroupChat({
    this.chat,
    this.group,
  });

  factory GroupChat.fromJson(Map<String, dynamic> json) {
    try {
      return GroupChat(
        chat: json['chat'] != null ? Chat.fromJson(json['chat']) : null,
        group: json['group'] != null 
            ? (json['group'] is List && (json['group'] as List).isNotEmpty)
                ? GroupDetails.fromJson(json['group'][0])
                : json['group'] is Map
                    ? GroupDetails.fromJson(json['group'])
                    : null
            : null,
      );
    } catch (e, stackTrace) {
      print('Error parsing GroupChat: $e');
      print('Stack trace: $stackTrace');
      print('Problematic JSON: $json');
      rethrow;
    }
  }
}
