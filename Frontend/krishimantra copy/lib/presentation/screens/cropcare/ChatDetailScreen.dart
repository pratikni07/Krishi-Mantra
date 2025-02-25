import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:async';
import '../../../core/constants/colors.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/UserService.dart';
import '../../../data/services/SocketService.dart';
import '../../controllers/message_controller.dart';

class ChatDetailScreen extends StatefulWidget {
  final dynamic chat;

  const ChatDetailScreen({
    Key? key,
    required this.chat,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final MessageController _messageController = Get.find<MessageController>();
  final UserService _userService = UserService();
  final SocketService _socketService = SocketService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final _typingUsers = <String>{}.obs;
  Timer? _typingTimer;
  bool _isFirstLoad = true;
  bool _isLoadingMore = false;

  String? currentUserId;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _deliveryStatusSubscription;
  StreamSubscription? _readReceiptSubscription;
  StreamSubscription? _onlineStatusSubscription;

  static const int _messagesPerPage = 20;
  static const Duration _typingTimeout = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _initializeUser();
    await _initializeSocketConnection();
    _setupScrollController();
    _setupTextControllerListener();
  }

  Future<void> _initializeSocketConnection() async {
    try {
      if (!_socketService.isSocketConnected()) {
        await _socketService.initialize();
        await _socketService.forceConnect();
      }
      _setupSocketListeners();
    } catch (e) {
      print('Chat screen socket initialization error: $e');
    }
  }

  Future<void> _initializeUser() async {
    final user = await _userService.getUser();
    if (user != null) {
      setState(() {
        currentUserId = user.id;
      });
      await _loadInitialMessages();
    }
  }

  void _setupSocketListeners() {
    _messageSubscription = _socketService.messageStream.listen((data) {
      if (data['chatId'] == widget.chat.id) {
        _handleNewMessage(Message.fromJson(data));
      }
    });

    _typingSubscription = _socketService.typingStream.listen((data) {
      if (data['chatId'] == widget.chat.id && data['userId'] != currentUserId) {
        // Get user name from participants
        String? typingUserName = _getUserNameById(data['userId']);
        if (typingUserName != null) {
          if (data['isTyping']) {
            _typingUsers.add(typingUserName);
          } else {
            _typingUsers.remove(typingUserName);
          }
        }
      }
    });

    _deliveryStatusSubscription =
        _socketService.deliveryStatusStream.listen((data) {
      if (data['chatId'] == widget.chat.id) {
        _updateMessageDeliveryStatus(data);
      }
    });

    _readReceiptSubscription = _socketService.readReceiptStream.listen((data) {
      if (data['chatId'] == widget.chat.id) {
        _updateMessageReadStatus(data);
      }
    });
  }

  String? _getUserNameById(String userId) {
    if (widget.chat.participants != null) {
      final participant = widget.chat.participants
          .firstWhere((p) => p.userId == userId, orElse: () => null);
      return participant?.userName;
    }
    return null;
  }

  void _setupScrollController() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _messageController.hasMoreMessages.value) {
        _loadMoreMessages();
      }
    });
  }

  void _setupTextControllerListener() {
    bool isCurrentlyTyping = false;

    _textController.addListener(() {
      final hasText = _textController.text.isNotEmpty;

      // Only send typing start if state is changing
      if (hasText && !isCurrentlyTyping) {
        isCurrentlyTyping = true;
        _socketService.sendTypingStart(widget.chat.id);
        _resetTypingTimer();
      } else if (!hasText && isCurrentlyTyping) {
        isCurrentlyTyping = false;
        _socketService.sendTypingStop(widget.chat.id);
        _typingTimer?.cancel();
      } else if (hasText) {
        // Reset timer if still typing
        _resetTypingTimer();
      }
    });
  }

  Future<void> _loadInitialMessages() async {
    _messageController.hasMoreMessages.value = true;
    _messageController.messages.clear();

    await _messageController.loadMessages(
      chatId: widget.chat.id,
      page: 1,
      limit: _messagesPerPage,
    );

    if (_isFirstLoad) {
      _isFirstLoad = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_messageController.hasMoreMessages.value) return;

    setState(() => _isLoadingMore = true);

    final nextPage =
        (_messageController.messages.length ~/ _messagesPerPage) + 1;
    final currentLength = _messageController.messages.length;

    await _messageController.loadMessages(
      chatId: widget.chat.id,
      page: nextPage,
      limit: _messagesPerPage,
    );

    if (currentLength == _messageController.messages.length) {
      _messageController.hasMoreMessages.value = false;
    }

    setState(() => _isLoadingMore = false);
  }

  void _handleNewMessage(Message message) {
    _messageController.messages.insert(0, message);

    if (_isAtBottom()) {
      _scrollToBottom();
    }

    // Mark message as delivered
    if (message.senderId != currentUserId) {
      // _socketService.markMessagesAsDelivered(widget.chat.id, [message.id]);
    }
  }

  void _updateMessageDeliveryStatus(Map<String, dynamic> data) {
    final messageId = data['messageId'];
    final deliveredTo = List<DeliveredTo>.from(
        (data['deliveredTo'] as List).map((d) => DeliveredTo.fromJson(d)));

    final index =
        _messageController.messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final message = _messageController.messages[index];
      _messageController.messages[index] = message.copyWith(
        deliveredTo: deliveredTo,
      );
    }
  }

  _updateMessageReadStatus(Map<String, dynamic> data) {
    final messageId =
        data['messageId']; // expects single messageId, server sends array
    final readBy = List<ReadByUser>.from((data['readBy'] as List)
        .map((r) => ReadByUser.fromJson(r))); // expects readBy array

    final index =
        _messageController.messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final message = _messageController.messages[index];
      _messageController.messages[index] = message.copyWith(
        readBy: readBy,
      );
    }
  }

  bool _isAtBottom() {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll <= 50.0;
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final messageContent = _textController.text.trim();
    if (messageContent.isEmpty) return;

    _textController.clear();
    _focusNode.unfocus();
    _socketService.sendTypingStop(widget.chat.id);

    try {
      await _messageController.sendMessage(
        chatId: widget.chat.id,
        content: messageContent,
      );

      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    }
  }

  Widget _buildMessagesList() {
    return Obx(() {
      final messages = _messageController.messages;
      if (_messageController.isLoading.value && messages.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.green),
        );
      }
      final unreadMessageIds = messages
          .where((m) =>
              m.senderId != currentUserId &&
              !m.readByUserIds.contains(currentUserId))
          .map((m) => m.id)
          .toList();

      // Mark visible messages as read in batch
      if (unreadMessageIds.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _socketService.markMessagesAsRead(widget.chat.id, unreadMessageIds);
        });
      }

      return ListView.builder(
        controller: _scrollController,
        reverse: false,
        padding: EdgeInsets.only(
          top: 16,
          bottom: 8 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: messages.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isLoadingMore && index == 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(color: AppColors.green),
              ),
            );
          }

          final messageIndex = _isLoadingMore ? index - 1 : index;
          final message = messages[messageIndex];
          final showDateHeader = _shouldShowDateHeader(messageIndex, messages);

          return Column(
            children: [
              if (showDateHeader) _buildDateHeader(message.createdAt),
              _buildMessageBubble(message),
            ],
          );
        },
      );
    });
  }

  bool _shouldShowDateHeader(int index, List<Message> messages) {
    if (index == 0) return true;
    final currentDate = messages[index].createdAt;
    final previousDate = messages[index - 1].createdAt;
    return !_isSameDay(currentDate, previousDate);
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateHeader(date),
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == DateTime(now.year, now.month, now.day)) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Widget _buildMessageBubble(Message message) {
    final isMyMessage = message.senderId == currentUserId;

    return VisibilityDetector(
      key: Key(message.id),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.5 &&
            !isMyMessage &&
            !message.readByUserIds.contains(currentUserId)) {
          _messageController.markMessageAsRead(message.id);
          _socketService.markMessagesAsRead(widget.chat.id, [message.id]);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment:
              isMyMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMyMessage) ...[
              _buildAvatar(message),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMyMessage ? AppColors.green : Colors.grey[200],
                  borderRadius: BorderRadius.circular(16).copyWith(
                    topLeft: Radius.circular(isMyMessage ? 16 : 4),
                    topRight: Radius.circular(isMyMessage ? 4 : 16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMyMessage && widget.chat.type == 'group')
                      _buildSenderName(message),
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMyMessage ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildMessageFooter(message, isMyMessage),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(Message message) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.faintGreen,
      backgroundImage: message.senderPhoto != null
          ? NetworkImage(message.senderPhoto!)
          : null,
      child: message.senderPhoto == null
          ? Text(
              message.senderName[0].toUpperCase(),
              style: const TextStyle(color: AppColors.green),
            )
          : null,
    );
  }

  Widget _buildSenderName(Message message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        message.senderName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: AppColors.textGrey,
        ),
      ),
    );
  }

  Widget _buildMessageFooter(Message message, bool isMyMessage) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(message.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: isMyMessage ? Colors.white.withOpacity(0.7) : Colors.black54,
          ),
        ),
        if (isMyMessage) ...[
          const SizedBox(width: 4),
          Icon(
            message.readBy.isNotEmpty ? Icons.done_all : Icons.done,
            size: 16,
            color: message.readBy.isNotEmpty
                ? Colors.white.withOpacity(0.7)
                : Colors.white.withOpacity(0.5),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void _resetTypingTimer() {
    _typingTimer?.cancel();
    _typingTimer = Timer(_typingTimeout, () {
      _socketService.sendTypingStop(widget.chat.id);
    });
  }

  Widget _buildTypingIndicator() {
    return Obx(() {
      if (_typingUsers.isEmpty) return const SizedBox.shrink();

      final text = _typingUsers.length == 1
          ? '${_typingUsers.first} is typing...'
          : '${_typingUsers.length} people are typing...';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textGrey,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    });
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file, color: AppColors.textGrey),
            onPressed: _showAttachmentOptions,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                hintStyle: const TextStyle(color: AppColors.textGrey),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: AppColors.green),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Content',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo,
                  label: 'Gallery',
                  onTap: () {
                    // Implement gallery attachment
                    Navigator.pop(context);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    // Implement camera attachment
                    Navigator.pop(context);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  onTap: () {
                    // Implement document attachment
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.faintGreen,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(icon, color: AppColors.green, size: 25),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.green,
        elevation: 1,
        title: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.faintGreen,
              backgroundImage: widget.chat.type == 'group'
                  ? null
                  : NetworkImage(
                      widget.chat.otherParticipants.first.profilePhoto ?? '',
                    ),
              child: widget.chat.type == 'group'
                  ? const Icon(Icons.group, color: AppColors.green)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.type == 'group'
                        ? widget.chat.groupDetails?.name ?? 'Unknown Group'
                        : widget.chat.otherParticipants.first.userName ??
                            'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.chat.type == 'group')
                    Text(
                      '${widget.chat.participants.length} members',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Implement chat options menu
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessagesList(),
          ),
          _buildTypingIndicator(),
          _buildMessageInput(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _typingSubscription?.cancel();
    _deliveryStatusSubscription?.cancel();
    _readReceiptSubscription?.cancel();
    _onlineStatusSubscription?.cancel();
    _typingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
