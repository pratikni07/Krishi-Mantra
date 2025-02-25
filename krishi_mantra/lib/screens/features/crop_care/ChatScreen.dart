import 'dart:convert';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:krishi_mantra/API/CropCareScreemAPI.dart';
import 'package:krishi_mantra/screens/features/crop_care/GroupSettingsScreen.dart';
import 'package:krishi_mantra/screens/features/crop_care/models/MessageModel.dart';
import 'package:krishi_mantra/services/socket_service.dart';
import 'package:video_player/video_player.dart';

class ChatColors {
  static const Color primary = Color(0xFF2E7D32);
  static const Color lightPrimary = Color.fromARGB(255, 244, 244, 244);
  static const Color avatarBackground = Color(0xFFA5D6A7);
  static MaterialColor primarySwatch = Colors.green;
}

class ChatScreen extends StatefulWidget {
  final SocketService socketService;
  final String chatId;
  final String? consultantId;
  final String userName;
  final String? userProfilePic;
  final bool isGroup;

  const ChatScreen({
    Key? key,
    required this.socketService,
    required this.chatId,
    this.consultantId,
    required this.userName,
    this.userProfilePic,
    this.isGroup = false,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  late SocketService _socketService;

  final List<MessageModel> _messages = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;
  File? _selectedMedia;
  String? _selectedMediaType;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _socketService = widget.socketService;
    _loadMessages();

    // Add message received listener
    _socketService.onMessageReceived = (message) {
      if (message['chatId'] == widget.chatId) {
        setState(() {
          _messages.add(MessageModel.fromJson(message, _chatService.userId));
          _scrollToBottom();
        });
      }
    };
  }

  Future<void> _pickMedia(ImageSource source, String type) async {
    try {
      final XFile? pickedFile;
      if (type == 'image') {
        pickedFile = await _imagePicker.pickImage(source: source);
      } else {
        pickedFile = await _imagePicker.pickVideo(source: source);
      }

      if (pickedFile != null) {
        setState(() {
          _selectedMedia = File(pickedFile!.path);
          _selectedMediaType = type;
        });

        if (type == 'video') {
          _videoController = VideoPlayerController.file(_selectedMedia!)
            ..initialize().then((_) {
              setState(() {});
            });
        }

        // Show preview dialog
        _showMediaPreviewDialog();
      }
    } catch (e) {
      _showError('Error picking media: $e');
    }
  }

  void _showMediaPreviewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedMediaType == 'image')
              Image.file(_selectedMedia!)
            else if (_selectedMediaType == 'video' && _videoController != null)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedMedia = null;
                      _selectedMediaType = null;
                      _videoController?.dispose();
                      _videoController = null;
                    });
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _sendMediaMessage();
                  },
                  child: const Text('Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, 'image');
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, 'image');
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record Video'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, 'video');
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Choose Video'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, 'video');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendMediaMessage() async {
    if (_selectedMedia == null) return;

    try {
      // Upload media file
      final String? mediaUrl = await _chatService.uploadMedia(_selectedMedia!);
      _socketService.sendMessage(widget.chatId, 'Media message',
          mediaUrl: mediaUrl);

      // Send message with media
      final response = await _chatService.sendMessage(
        widget.chatId,
        'Media message', // Optional caption could be added here
        mediaUrl: mediaUrl,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messageData = data['message'] ?? data;

        final newMessage = MessageModel(
          id: messageData['_id'] ?? '',
          content: messageData['content'] ?? '',
          isSentByMe: true,
          timestamp: DateTime.now(),
          imageUrl: mediaUrl,
          mediaType: _selectedMediaType,
          senderId: _chatService.userId,
          readBy: [],
          deliveredTo: [_chatService.userId],
        );

        setState(() {
          _messages.add(newMessage);
          _selectedMedia = null;
          _selectedMediaType = null;
          if (_videoController != null) {
            _videoController!.dispose();
            _videoController = null;
          }
        });

        _scrollToBottom();
      }
    } catch (e) {
      _showError('Failed to send media message');
    }
  }

  void _onTypingStart() {
    _socketService.startTyping(widget.chatId);
  }

  void _onTypingStop() {
    _socketService.stopTyping(widget.chatId);
  }

  Widget _buildMessageContent(MessageModel message) {
    if (message.mediaType == 'image') {
      return CachedNetworkImage(
        imageUrl: message.imageUrl!,
        placeholder: (context, url) => const CircularProgressIndicator(),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      );
    } else if (message.mediaType == 'video') {
      return GestureDetector(
        onTap: () {
          // Implement video player screen navigation
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            CachedNetworkImage(
              imageUrl: message.imageUrl!, // Video thumbnail
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(Icons.error),
            ),
            const Icon(
              Icons.play_circle_fill,
              size: 48,
              color: Colors.white,
            ),
          ],
        ),
      );
    } else {
      return Text(
        message.content,
        style: TextStyle(
          color: message.isSentByMe ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
      );
    }
  }

  Future<void> _loadMessages() async {
    if (!_hasMore) return;

    try {
      final response =
          await _chatService.getChatMessages(widget.chatId, page: _currentPage);
      if (response.statusCode == 200) {
        final List<dynamic> messages = json.decode(response.body);
        final newMessages = messages
            .map((msg) => MessageModel.fromJson(msg, _chatService.userId))
            .toList();

        setState(() {
          _messages.addAll(newMessages);
          _hasMore = newMessages.length == 50;
          _currentPage++;
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      _showError('Failed to load messages');
      setState(() => _isLoading = false);
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.minScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _markMessageAsRead(String messageId) async {
    try {
      final response = await _chatService.markMessageAsRead(messageId);
      if (response.statusCode == 200) {
        setState(() {
          final messageIndex = _messages.indexWhere((m) => m.id == messageId);
          if (messageIndex != -1) {
            final updatedMessage = MessageModel(
              id: _messages[messageIndex].id,
              content: _messages[messageIndex].content,
              isSentByMe: _messages[messageIndex].isSentByMe,
              timestamp: _messages[messageIndex].timestamp,
              imageUrl: _messages[messageIndex].imageUrl,
              mediaType: _messages[messageIndex].mediaType,
              senderId: _messages[messageIndex].senderId,
              readBy: [..._messages[messageIndex].readBy, _chatService.userId],
              deliveredTo: _messages[messageIndex].deliveredTo,
            );
            _messages[messageIndex] = updatedMessage;
          }
        });
      }
    } catch (e) {
      print('Error marking message as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    final messageContent = _messageController.text.trim();
    _messageController.clear();
    _socketService.sendMessage(widget.chatId, messageContent);

    try {
      final response =
          await _chatService.sendMessage(widget.chatId, messageContent);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final messageData = data['message'] ?? data;

        final newMessage = MessageModel(
          id: messageData['_id'] ?? '',
          content: messageContent,
          isSentByMe: true,
          timestamp: DateTime.now(),
          senderId: _chatService.userId,
          readBy: [],
          deliveredTo: [_chatService.userId],
        );

        setState(() {
          _messages.insert(0, newMessage); // Use insert instead of add
        });

        // Scroll to bottom after sending
        _scrollToBottom();
      }
    } catch (e) {
      _showError('Failed to send message');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildMessageStatus(MessageModel message) {
    if (!message.isSentByMe) return const SizedBox.shrink();

    if (message.isRead) {
      return const Icon(Icons.done_all, size: 16, color: Colors.blue);
    } else if (message.isDelivered) {
      return const Icon(Icons.done_all, size: 16, color: Colors.grey);
    } else {
      return const Icon(Icons.done, size: 16, color: Colors.grey);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatColors.lightPrimary,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leadingWidth: 30, // Reduced leading width
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          padding: EdgeInsets.only(left: 20), // Remove padding
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18, // Slightly reduced radius
              backgroundImage: widget.userProfilePic != null
                  ? NetworkImage(widget.userProfilePic!)
                  : null,
              backgroundColor: ChatColors.avatarBackground,
              child: widget.userProfilePic == null
                  ? Text(
                      widget.userName[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(width: 8), // Reduced spacing
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!widget.isGroup)
                    Text(
                      'Online',
                      style: TextStyle(
                        color: ChatColors.primarySwatch[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        // Add group settings option in AppBar actions
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupSettingsScreen(
                      groupId: widget.chatId,
                      groupName: widget.userName,
                      currentAdminSetting:
                          false, // Fetch actual value from backend
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: message.isSentByMe
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      if (!message.isSentByMe) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundImage: widget.userProfilePic != null
                              ? NetworkImage(widget.userProfilePic!)
                              : null,
                          backgroundColor: ChatColors.avatarBackground,
                          child: widget.userProfilePic == null
                              ? Text(
                                  widget.userName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                      ],
                      Container(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: message.isSentByMe
                              ? ChatColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMessageContent(message),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatTime(message.timestamp),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: message.isSentByMe
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.grey[600],
                                  ),
                                ),
                                if (message.isSentByMe) ...[
                                  const SizedBox(width: 4),
                                  _buildMessageStatus(message),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: Colors.grey[600],
                    onPressed: _showMediaOptions,
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: const InputDecoration(
                                hintText: 'Type a message...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.emoji_emotions_outlined),
                            color: Colors.grey[600],
                            onPressed: () {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: ChatColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send),
                      color: Colors.white,
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
