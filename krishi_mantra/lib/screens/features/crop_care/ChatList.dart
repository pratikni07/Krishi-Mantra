import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:krishi_mantra/API/ConsultantScreenAPI.dart';
import 'package:krishi_mantra/API/CropCareScreemAPI.dart';
import 'package:krishi_mantra/screens/features/crop_care/ChatScreen.dart';
import 'package:krishi_mantra/screens/features/crop_care/CreateGroupScreen.dart';
import 'package:krishi_mantra/screens/features/crop_care/GroupInviteScreen.dart';
import 'package:krishi_mantra/screens/features/crop_care/models/Consultant.dart';
import 'package:krishi_mantra/services/socket_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  ChatListScreenState createState() => ChatListScreenState();
}

class ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final ApiService _apiService = ApiService();
  List<ChatPreview> _chats = [];
  List<Consultant> _consultants = [];
  bool _isLoading = true;
  late SocketService _socketService;

  @override
  void initState() {
    super.initState();
    _socketService = SocketService(
      userId: _chatService.userId,
      onChatCreated: (chatData) {
        _loadChats(); // Refresh chat list when new chat is created
      },
    );
    _socketService.connect();
    _loadChats();
    _loadConsultants();
  }

  Future<void> _loadConsultants() async {
    try {
      final response = await _apiService.getConsultantByLocation(
          18.6161, 73.7286); // Replace with actual coordinates
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _consultants = (data['consultants'] as List)
              .map((json) => Consultant.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load consultants: $e')),
      );
    }
  }

  Future<void> _createChat(Consultant consultant) async {
    try {
      final response = await _chatService.createDirectChat(
          consultant.id, consultant.name, consultant.photoUrl);
      if (response.statusCode == 200) {
        final chatData = json.decode(response.body);

        // Create SocketService for this chat
        final socketService = SocketService(
          userId: _chatService.userId,
          onMessageReceived: (message) {
            // Optional: Handle incoming messages if needed
          },
        );
        socketService.connect();

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              socketService: socketService, // Add this line
              chatId: chatData['_id'],
              consultantId: consultant.id.toString(),
              userName: consultant.name,
              userProfilePic: consultant.photoUrl,
              isGroup: false,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create chat: $e')),
      );
    }
  }

  void _showConsultantModal() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Consultant',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _consultants.length,
                itemBuilder: (context, index) {
                  final consultant = _consultants[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(consultant.photoUrl),
                    ),
                    title: Text(consultant.name),
                    subtitle: Row(
                      children: [
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        Text(' ${consultant.rating}'),
                        Text(' • ${consultant.experience} years'),
                      ],
                    ),
                    trailing: Image.network(
                      consultant.companyLogo,
                      width: 40,
                      height: 40,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _createChat(consultant);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadChats() async {
    try {
      final response = await _chatService.getChatList();
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _chats = data.map((json) => ChatPreview.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load chats: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.green.shade400,
                Colors.green.shade600,
              ],
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Crop Consultations',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '${_chats.length} active chats',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'create_group':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateGroupScreen(),
                    ),
                  );
                  break;
                case 'join_group':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupInviteScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                value: 'create_group',
                child: Text('Create Group'),
              ),
              PopupMenuItem(
                value: 'join_group',
                child: Text('Join Group'),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.white.withOpacity(0.2),
            height: 1.0,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? const Center(child: Text('No chats available'))
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(
                          chat.type == 'group'
                              ? chat.groupDetails?.groupImage ??
                                  'https://via.placeholder.com/150' // Default group image
                              : chat.otherParticipant?.profilePhoto ??
                                  'https://via.placeholder.com/150',
                        ),
                      ),
                      title: Text(
                        chat.type == 'group'
                            ? chat.groupDetails?.name ?? 'Unnamed Group'
                            : chat.otherParticipant?.userName ?? 'Unknown User',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (chat.type == 'group' &&
                              chat.groupDetails?.memberCount != null)
                            Text(
                              '${chat.groupDetails!.memberCount} members',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          Text(chat.lastMessage ?? 'No messages yet'),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (chat.updatedAt != null)
                            Text(
                              _formatTime(chat.updatedAt!),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          if (chat.unreadCount > 0)
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                chat.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatId: chat.id,
                            consultantId: chat.type == 'group'
                                ? null
                                : chat.otherParticipant?.userId,
                            userName: chat.type == 'group'
                                ? chat.groupDetails?.name ?? 'Unnamed Group'
                                : chat.otherParticipant?.userName ??
                                    'Unknown User',
                            userProfilePic: chat.type == 'group'
                                ? chat.groupDetails?.groupImage
                                : chat.otherParticipant?.profilePhoto,
                            isGroup: chat.type == 'group',
                            socketService: _socketService,
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showConsultantModal,
        child: const Icon(Icons.add),
        backgroundColor: Colors.green,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      return _getDayName(time);
    } else {
      return '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year.toString().substring(2)}';
    }
  }

  String _getDayName(DateTime time) {
    switch (time.weekday) {
      case 1:
        return 'Mon';
      case 2:
        return 'Tue';
      case 3:
        return 'Wed';
      case 4:
        return 'Thu';
      case 5:
        return 'Fri';
      case 6:
        return 'Sat';
      case 7:
        return 'Sun';
      default:
        return '';
    }
  }
}

class Participant {
  final String userId;
  final String userName;
  final String profilePhoto;

  Participant({
    required this.userId,
    required this.userName,
    required this.profilePhoto,
  });

  factory Participant.fromJson(Map<String, dynamic> json) {
    return Participant(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      profilePhoto: json['profilePhoto'] as String,
    );
  }
}

class GroupDetails {
  final String name;
  final String description;
  final List<String> admin;
  final bool onlyAdminCanMessage;
  final String inviteUrl;
  final int memberCount;
  final String? groupImage;

  GroupDetails({
    required this.name,
    required this.description,
    required this.admin,
    required this.onlyAdminCanMessage,
    required this.inviteUrl,
    required this.memberCount,
    this.groupImage,
  });

  factory GroupDetails.fromJson(Map<String, dynamic> json) {
    return GroupDetails(
      name: json['name'] as String,
      description: json['description'] as String,
      admin: (json['admin'] as List).cast<String>(),
      onlyAdminCanMessage: json['onlyAdminCanMessage'] as bool,
      inviteUrl: json['inviteUrl'] as String,
      memberCount: json['memberCount'] as int,
      groupImage: json['groupImage'] as String?,
    );
  }
}

class ChatPreview {
  final String id;
  final String type;
  final Participant? otherParticipant;
  final GroupDetails? groupDetails;
  final String? lastMessage;
  final DateTime? updatedAt;
  final int unreadCount;

  ChatPreview({
    required this.id,
    required this.type,
    this.otherParticipant,
    this.groupDetails,
    this.lastMessage,
    this.updatedAt,
    this.unreadCount = 0,
  });

  factory ChatPreview.fromJson(Map<String, dynamic> json) {
    try {
      if (json['type'] == 'group') {
        return ChatPreview(
          id: json['_id']?.toString() ?? '',
          type: json['type']?.toString() ?? 'direct',
          groupDetails:
              json['groupDetails'] is List && json['groupDetails'].isNotEmpty
                  ? GroupDetails.fromJson(json['groupDetails'][0])
                  : null,
          lastMessage: json['lastMessageDetails'] is List &&
                  json['lastMessageDetails'].isNotEmpty &&
                  json['lastMessageDetails'][0]['content'] != null
              ? json['lastMessageDetails'][0]['content'].toString()
              : null,
          updatedAt: json['updatedAt'] != null
              ? DateTime.tryParse(json['updatedAt'].toString())
              : null,
          unreadCount: json['unreadCount'] is Map
              ? (json['unreadCount'] as Map)
                  .values
                  .fold(0, (sum, value) => sum + (value as int? ?? 0))
              : 0,
        );
      }

      return ChatPreview(
        id: json['_id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'direct',
        otherParticipant: json['otherParticipants'] is List &&
                json['otherParticipants'].isNotEmpty
            ? Participant.fromJson(json['otherParticipants'][0])
            : null,
        lastMessage: json['lastMessageDetails'] is List &&
                json['lastMessageDetails'].isNotEmpty &&
                json['lastMessageDetails'][0]['content'] != null
            ? json['lastMessageDetails'][0]['content'].toString()
            : null,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString())
            : null,
        unreadCount: json['unreadCount'] is Map
            ? (json['unreadCount'] as Map)
                .values
                .fold(0, (sum, value) => sum + (value as int? ?? 0))
            : 0,
      );
    } catch (e) {
      print('Error parsing ChatPreview: $e');
      // Return a default chat preview instead of throwing
      return ChatPreview(
          id: json['_id']?.toString() ?? '', type: 'direct', unreadCount: 0);
    }
  }
}
