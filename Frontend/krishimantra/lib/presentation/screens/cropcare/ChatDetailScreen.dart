import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'dart:async';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/language_helper.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/UserService.dart';
import '../../../data/services/SocketService.dart';
import '../../controllers/message_controller.dart';
import '../../../data/models/participant_model.dart';
import 'dart:math' show pi, sin;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../widgets/chat_message_bubble.dart';
import '../../widgets/media_preview_dialog.dart';
import '../../widgets/loading_message_bubble.dart';
import '../../../utils/permission_helper.dart';

class ChatDetailScreen extends StatefulWidget {
  final dynamic chat;

  const ChatDetailScreen({
    Key? key,
    required this.chat,
  }) : super(key: key);

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> with TranslationMixin {
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

  // Track messages already marked as read to prevent duplicates
  final Set<String> _markedAsReadMessageIds = {};
  Timer? _readMarkingDebounceTimer;
  final List<String> _pendingReadMessageIds = [];

  // Translation keys
  static const String KEY_FAILED_SEND_MESSAGE = 'failed_send_message';
  static const String KEY_TODAY = 'today';
  static const String KEY_YESTERDAY = 'yesterday';
  static const String KEY_IS_TYPING = 'is_typing';
  static const String KEY_PEOPLE_TYPING = 'people_typing';
  static const String KEY_TYPE_MESSAGE = 'type_message';
  static const String KEY_SHARE_CONTENT = 'share_content';
  static const String KEY_GALLERY = 'gallery';
  static const String KEY_CAMERA = 'camera';
  static const String KEY_DOCUMENT = 'document';
  static const String KEY_PERMISSION_REQUIRED = 'permission_required';
  static const String KEY_GALLERY_ACCESS = 'gallery_access_needed';
  static const String KEY_CAMERA_ACCESS = 'camera_access_needed';
  static const String KEY_STORAGE_ACCESS = 'storage_access_needed';
  static const String KEY_ERROR = 'error';
  static const String KEY_FAILED_UPLOAD_IMAGE = 'failed_upload_image';
  static const String KEY_FAILED_UPLOAD_DOCUMENT = 'failed_upload_document';
  static const String KEY_FAILED_PREVIEW_IMAGE = 'failed_preview_image';
  static const String KEY_FAILED_PREVIEW_DOCUMENT = 'failed_preview_document';
  static const String KEY_UNKNOWN_GROUP = 'unknown_group';
  static const String KEY_PARTICIPANTS = 'participants';
  static const String KEY_LEAVE_GROUP = 'leave_group';
  static const String KEY_LEAVE_GROUP_CONFIRM = 'leave_group_confirm';
  static const String KEY_CANCEL = 'cancel';
  static const String KEY_LEAVE = 'leave';
  static const String KEY_SUCCESS = 'success';
  static const String KEY_LEFT_GROUP = 'left_group';
  static const String KEY_FAILED_LEAVE_GROUP = 'failed_leave_group';
  static const String KEY_GROUP_PARTICIPANTS = 'group_participants';
  static const String KEY_ADMIN = 'admin';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    _initializeLanguage();
    _initializeChat();
  }

  void _registerTranslations() {
    registerTranslation(KEY_FAILED_SEND_MESSAGE, 'Failed to send message');
    registerTranslation(KEY_TODAY, 'Today');
    registerTranslation(KEY_YESTERDAY, 'Yesterday');
    registerTranslation(KEY_IS_TYPING, 'is typing...');
    registerTranslation(KEY_PEOPLE_TYPING, 'people are typing...');
    registerTranslation(KEY_TYPE_MESSAGE, 'Type a message...');
    registerTranslation(KEY_SHARE_CONTENT, 'Share Content');
    registerTranslation(KEY_GALLERY, 'Gallery');
    registerTranslation(KEY_CAMERA, 'Camera');
    registerTranslation(KEY_DOCUMENT, 'Document');
    registerTranslation(KEY_PERMISSION_REQUIRED, 'Permission Required');
    registerTranslation(KEY_GALLERY_ACCESS, 'Gallery access is needed to select images');
    registerTranslation(KEY_CAMERA_ACCESS, 'Camera access is needed to take photos');
    registerTranslation(KEY_STORAGE_ACCESS, 'Storage access is needed to select documents');
    registerTranslation(KEY_ERROR, 'Error');
    registerTranslation(KEY_FAILED_UPLOAD_IMAGE, 'Failed to upload image');
    registerTranslation(KEY_FAILED_UPLOAD_DOCUMENT, 'Failed to upload document');
    registerTranslation(KEY_FAILED_PREVIEW_IMAGE, 'Failed to preview image');
    registerTranslation(KEY_FAILED_PREVIEW_DOCUMENT, 'Failed to preview document');
    registerTranslation(KEY_UNKNOWN_GROUP, 'Unknown Group');
    registerTranslation(KEY_PARTICIPANTS, 'participants');
    registerTranslation(KEY_LEAVE_GROUP, 'Leave Group');
    registerTranslation(KEY_LEAVE_GROUP_CONFIRM, 'Are you sure you want to leave this group?');
    registerTranslation(KEY_CANCEL, 'Cancel');
    registerTranslation(KEY_LEAVE, 'Leave');
    registerTranslation(KEY_SUCCESS, 'Success');
    registerTranslation(KEY_LEFT_GROUP, 'You have left the group');
    registerTranslation(KEY_FAILED_LEAVE_GROUP, 'Failed to leave group');
    registerTranslation(KEY_GROUP_PARTICIPANTS, 'Group Participants');
    registerTranslation(KEY_ADMIN, 'Admin');
  }

  Future<void> _initializeLanguage() async {
    await updateTranslations();
    if (mounted) setState(() {});
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
    } catch (e) {}
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

      if (hasText && !isCurrentlyTyping) {
        isCurrentlyTyping = true;
        _socketService.sendTypingStart(widget.chat.id);
        _resetTypingTimer();
      } else if (!hasText && isCurrentlyTyping) {
        isCurrentlyTyping = false;
        _socketService.sendTypingStop(widget.chat.id);
        _typingTimer?.cancel();
      } else if (hasText) {
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
    _messageController.messages.add(message);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    if (message.senderId != currentUserId) {
      // _socketService.markMessagesAsDelivered(widget.chat.id, [message.id]);
    }
  }

  void _updateMessageDeliveryStatus(Map<String, dynamic> data) {
    try {
      final messageId = data['messageId'];
      if (messageId == null) return;

      // Add null check and default to empty list if null
      final deliveredToData = data['deliveredTo'];
      if (deliveredToData == null) return;

      List<DeliveredTo> deliveredTo;
      try {
        deliveredTo = List<DeliveredTo>.from(
          (deliveredToData as List).map((d) => DeliveredTo.fromJson(d)),
        );
      } catch (e) {
        return;
      }

      final index =
          _messageController.messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final message = _messageController.messages[index];
        _messageController.messages[index] = message.copyWith(
          deliveredTo: deliveredTo,
        );
      }
    } catch (e) {}
  }

  void _updateMessageReadStatus(Map<String, dynamic> data) {
    try {
      final messageId = data['messageId'];
      if (messageId == null) return;

      // Add null check and default to empty list if null
      final readByData = data['readBy'];
      if (readByData == null) return;

      List<ReadByUser> readBy;
      try {
        readBy = List<ReadByUser>.from(
          (readByData as List).map((r) => ReadByUser.fromJson(r)),
        );
      } catch (e) {
        return;
      }

      final index =
          _messageController.messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final message = _messageController.messages[index];
        _messageController.messages[index] = message.copyWith(
          readBy: readBy,
        );
      }
    } catch (e) {}
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
        _scrollController.position.maxScrollExtent,
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
        SnackBar(content: Text(getTranslation(KEY_FAILED_SEND_MESSAGE))),
      );
    }
  }

  Widget _buildMessagesList() {
    return Obx(() {
      final messages = _messageController.messages;
      final tempMessages = _messageController.tempMessages;

      if (_messageController.isLoading.value && messages.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.green),
        );
      }

      // Find unread messages that haven't been marked yet
      final unreadMessageIds = messages
          .where((m) =>
              m.senderId != currentUserId &&
              !m.readByUserIds.contains(currentUserId) &&
              !_markedAsReadMessageIds.contains(m.id))
          .map((m) => m.id)
          .toList();

      // Mark visible messages as read with debouncing to prevent duplicates
      if (unreadMessageIds.isNotEmpty) {
        _pendingReadMessageIds.addAll(unreadMessageIds);
        _markedAsReadMessageIds.addAll(unreadMessageIds);

        // Debounce the read marking to batch multiple calls
        _readMarkingDebounceTimer?.cancel();
        _readMarkingDebounceTimer = Timer(const Duration(milliseconds: 300), () {
          if (_pendingReadMessageIds.isNotEmpty) {
            _socketService.markMessagesAsRead(widget.chat.id, List.from(_pendingReadMessageIds));
            _pendingReadMessageIds.clear();
          }
        });
      }

      // Calculate the total item count (messages + temp messages + loading indicator)
      final itemCount =
          messages.length + tempMessages.length + (_isLoadingMore ? 1 : 0);

      return ListView.builder(
        controller: _scrollController,
        reverse: false,
        padding: EdgeInsets.only(
          top: 16,
          bottom: 8 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Show loading indicator at the top if loading more messages
          if (_isLoadingMore && index == 0) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(color: AppColors.green),
              ),
            );
          }

          // Adjust index for the loading indicator
          final adjustedIndex = _isLoadingMore ? index - 1 : index;

          // Check if we're rendering a message or a temporary message
          if (adjustedIndex < messages.length) {
            // Regular message
            final message = messages[adjustedIndex];
            final showDateHeader =
                _shouldShowDateHeader(adjustedIndex, messages);

            return Column(
              children: [
                if (showDateHeader) _buildDateHeader(message.createdAt),
                ChatMessageBubble(
                  message: message.content,
                  isUser: message.senderId == currentUserId,
                  timestamp: message.createdAt,
                  mediaUrl: message.mediaUrl,
                  mediaType: message.mediaType,
                  mediaMetadata: message.mediaMetadata,
                ),
              ],
            );
          } else {
            // Temporary message (like loading states)
            final tempIndex = adjustedIndex - messages.length;
            final tempKey = tempMessages.keys.elementAt(tempIndex);
            return tempMessages[tempKey]!;
          }
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
      padding: RPadding.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: RPadding.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(AppSizes.radiusL),
          ),
          child: Text(
            _formatDateHeader(date),
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: AppSizes.fontS,
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
      return getTranslation(KEY_TODAY);
    } else if (messageDate == yesterday) {
      return getTranslation(KEY_YESTERDAY);
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
                    if (message.content != null) // Add null check
                      Text(
                        message
                            .content!, // Use null assertion operator since we checked above
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

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Animated dots
            SizedBox(
              width: 35,
              child: Stack(
                children: [
                  _buildAnimatedDot(0),
                  _buildAnimatedDot(1),
                  _buildAnimatedDot(2),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Typing text
            Text(
              _typingUsers.length == 1
                  ? '${_typingUsers.first} ${getTranslation(KEY_IS_TYPING)}'
                  : '${_typingUsers.length} ${getTranslation(KEY_PEOPLE_TYPING)}',
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildAnimatedDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Positioned(
          left: index * 10.0,
          bottom: sin((value * pi) + (index * pi / 2)) * 5,
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.green,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.only(
        left: AppSizes.paddingL,
        right: AppSizes.paddingL,
        top: AppSizes.paddingS,
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
            icon: Icon(Icons.attach_file, color: AppColors.textGrey, size: AppSizes.iconM),
            onPressed: _showAttachmentOptions,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              focusNode: _focusNode,
              style: TextStyle(fontSize: AppSizes.fontM),
              decoration: InputDecoration(
                hintText: getTranslation(KEY_TYPE_MESSAGE),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusXXL),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: RPadding.symmetric(horizontal: 20, vertical: 10),
                hintStyle: TextStyle(color: AppColors.textGrey, fontSize: AppSizes.fontM),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: AppColors.green, size: AppSizes.iconM),
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
        padding: RPadding.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXXL)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              getTranslation(KEY_SHARE_CONTENT),
              style: TextStyle(
                fontSize: AppSizes.fontL,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: AppSizes.paddingL),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo,
                  label: getTranslation(KEY_GALLERY),
                  onTap: () async {
                    Navigator.pop(context);

                    // Check gallery permission first
                    final hasPermission = await PermissionHelper.requestGalleryPermission(context);
                    if (!hasPermission) {
                      Get.snackbar(
                        getTranslation(KEY_PERMISSION_REQUIRED),
                        getTranslation(KEY_GALLERY_ACCESS),
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 3),
                      );
                      return;
                    }

                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                    );
                    if (image != null) {
                      await _handleImageUpload(File(image.path));
                    }
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: getTranslation(KEY_CAMERA),
                  onTap: () async {
                    Navigator.pop(context);

                    // Check camera permission first
                    final hasPermission = await PermissionHelper.requestCameraPermission(context);
                    if (!hasPermission) {
                      Get.snackbar(
                        getTranslation(KEY_PERMISSION_REQUIRED),
                        getTranslation(KEY_CAMERA_ACCESS),
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 3),
                      );
                      return;
                    }

                    final ImagePicker picker = ImagePicker();
                    final XFile? photo = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 70,
                    );
                    if (photo != null) {
                      await _handleImageUpload(File(photo.path));
                    }
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: getTranslation(KEY_DOCUMENT),
                  onTap: () async {
                    Navigator.pop(context);

                    // Check storage permission for documents
                    final hasPermission = await PermissionHelper.requestGalleryPermission(context);
                    if (!hasPermission) {
                      Get.snackbar(
                        getTranslation(KEY_PERMISSION_REQUIRED),
                        getTranslation(KEY_STORAGE_ACCESS),
                        snackPosition: SnackPosition.BOTTOM,
                        duration: const Duration(seconds: 3),
                      );
                      return;
                    }

                    final result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf', 'doc', 'docx'],
                    );
                    if (result != null) {
                      await _handleDocumentUpload(
                          File(result.files.single.path!));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleImageUpload(File imageFile) async {
    try {
      // Show preview dialog
      final result = await Get.dialog<bool>(
        MediaPreviewDialog(
          mediaFile: imageFile,
          mediaType: 'image',
          captionController:
              TextEditingController(), // Empty controller, no caption needed
          onSend: (file) async {
            // Create a temporary message ID for the loading bubble
            final tempId = DateTime.now().millisecondsSinceEpoch.toString();

            // Show loading in the chat instead of fullscreen
            final loadingBubble = LoadingMessageBubble(
              mediaFile: file,
              mediaType: 'image',
            );

            // Add loading bubble to UI
            _messageController.addTempMessage(tempId, loadingBubble);

            try {
              // Upload image and get URL
              final mediaUrl = await _messageController.uploadMedia(
                file,
                'chat_image',
              );

              if (mediaUrl != null) {
                // Remove temp message
                _messageController.removeTempMessage(tempId);

                // Send message with image
                await _messageController.sendMessage(
                  chatId: widget.chat.id,
                  content: '', // Empty content since we removed captions
                  mediaType: 'image',
                  mediaUrl: mediaUrl,
                );

                // Scroll to bottom to show the new message
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
              }
            } catch (e) {
              // Remove temp message on error
              _messageController.removeTempMessage(tempId);

              Get.snackbar(
                getTranslation(KEY_ERROR),
                '${getTranslation(KEY_FAILED_UPLOAD_IMAGE)}: ${e.toString()}',
                snackPosition: SnackPosition.BOTTOM,
              );
            }
          },
        ),
        barrierDismissible: false,
      );

      // If dialog was dismissed without requesting send, don't proceed
      if (result != true) {
        return;
      }
    } catch (e) {
      Get.snackbar(
        getTranslation(KEY_ERROR),
        '${getTranslation(KEY_FAILED_PREVIEW_IMAGE)}: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _handleDocumentUpload(File document) async {
    try {
      // Show preview dialog
      final result = await Get.dialog<bool>(
        MediaPreviewDialog(
          mediaFile: document,
          mediaType: 'document',
          captionController:
              TextEditingController(), // Empty controller, no caption needed
          onSend: (file) async {
            final tempId = DateTime.now().millisecondsSinceEpoch.toString();

            final loadingBubble = LoadingMessageBubble(
              mediaFile: file,
              mediaType: 'document',
            );

            _messageController.addTempMessage(tempId, loadingBubble);

            try {
              // Upload document and get URL
              final mediaUrl = await _messageController.uploadMedia(
                file,
                'chat_document',
              );

              if (mediaUrl != null) {
                // Remove temp message
                _messageController.removeTempMessage(tempId);

                final fileName = file.path.split('/').last;
                await _messageController.sendMessage(
                  chatId: widget.chat.id,
                  content: '', // Empty content since we removed captions
                  mediaType: 'document',
                  mediaUrl: mediaUrl,
                  mediaMetadata: {
                    'fileName': fileName,
                    'fileSize': await file.length(),
                  },
                );

                // Scroll to bottom to show the new message
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
              }
            } catch (e) {
              // Remove temp message on error
              _messageController.removeTempMessage(tempId);

              Get.snackbar(
                getTranslation(KEY_ERROR),
                '${getTranslation(KEY_FAILED_UPLOAD_DOCUMENT)}: ${e.toString()}',
                snackPosition: SnackPosition.BOTTOM,
              );
            }
          },
        ),
        barrierDismissible: false,
      );

      // If dialog was dismissed without requesting send, don't proceed
      if (result != true) {
        return;
      }
    } catch (e) {
      Get.snackbar(
        getTranslation(KEY_ERROR),
        '${getTranslation(KEY_FAILED_PREVIEW_DOCUMENT)}: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      // Default deferToChild only registers taps on opaque pixels (the
      // icon circle), so taps on the label text fall through. Opaque
      // makes the whole Column bounds tappable.
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: RPadding.all(15),
            decoration: BoxDecoration(
              color: AppColors.faintGreen,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(icon, color: AppColors.green, size: AppSizes.iconM),
          ),
          SizedBox(height: AppSizes.paddingS),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textGrey,
              fontSize: AppSizes.fontS,
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final avatarRadius = ResponsiveUtils.responsive(mobile: 20.0, tablet: 25.0);

    return AppBar(
      backgroundColor: AppColors.green,
      elevation: 1,
      title: Row(
        children: [
          CircleAvatar(
            radius: avatarRadius,
            backgroundColor: AppColors.faintGreen,
            backgroundImage: widget.chat.type == 'group' || widget.chat.otherParticipants.isEmpty
                ? null
                : (widget.chat.otherParticipants.first.profilePhoto?.isNotEmpty == true
                    ? NetworkImage(widget.chat.otherParticipants.first.profilePhoto!)
                    : null),
            child: widget.chat.type == 'group' || widget.chat.otherParticipants.isEmpty
                ? Icon(Icons.group, color: AppColors.green, size: AppSizes.iconM)
                : (widget.chat.otherParticipants.first.profilePhoto?.isNotEmpty != true
                    ? Icon(Icons.person, color: AppColors.green, size: AppSizes.iconM)
                    : null),
          ),
          SizedBox(width: AppSizes.paddingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chat.type == 'group'
                      ? widget.chat.groupDetails?.name ?? getTranslation(KEY_UNKNOWN_GROUP)
                      : (widget.chat.otherParticipants.isNotEmpty
                          ? widget.chat.otherParticipants.first.userName
                          : 'Unknown'),
                  style: TextStyle(
                    fontSize: AppSizes.fontL,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (widget.chat.type == 'group')
                  Text(
                    '${widget.chat.participants.length} ${getTranslation(KEY_PARTICIPANTS)}',
                    style: TextStyle(
                      fontSize: AppSizes.fontS,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (widget.chat.type == 'group')
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: _handleGroupMenuAction,
            color: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'participants',
                child: Row(
                  children: [
                    Icon(Icons.group, color: AppColors.textGrey),
                    const SizedBox(width: 12),
                    Text(
                      getTranslation(KEY_PARTICIPANTS),
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem<String>(
                value: 'leave',
                child: Row(
                  children: [
                    const Icon(Icons.exit_to_app, color: Colors.red),
                    const SizedBox(width: 12),
                    Text(
                      getTranslation(KEY_LEAVE_GROUP),
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _handleGroupMenuAction(String value) {
    switch (value) {
      case 'participants':
        _showParticipantsDialog();
        break;
      case 'leave':
        _showLeaveGroupConfirmation();
        break;
    }
  }

  void _showParticipantsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.faintGreen,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.group,
                      color: AppColors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${getTranslation(KEY_GROUP_PARTICIPANTS)} (${widget.chat.participants.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textGrey,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textGrey,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.chat.participants.length,
                  itemBuilder: (context, index) {
                    final participant = widget.chat.participants[index];
                    final isAdmin = widget.chat.groupDetails?.admin
                            .contains(participant.userId) ??
                        false;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.faintGreen,
                          backgroundImage: NetworkImage(
                            participant.profilePhoto,
                          ),
                          child: participant.profilePhoto.isEmpty
                              ? Text(
                                  participant.userName[0].toUpperCase(),
                                  style:
                                      const TextStyle(color: AppColors.green),
                                )
                              : null,
                        ),
                        title: Text(
                          participant.userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textGrey,
                            fontSize: 15,
                          ),
                        ),
                        trailing: isAdmin
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.faintGreen,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  getTranslation(KEY_ADMIN),
                                  style: const TextStyle(
                                    color: AppColors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveGroupConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(getTranslation(KEY_LEAVE_GROUP)),
        content: Text(getTranslation(KEY_LEAVE_GROUP_CONFIRM)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              getTranslation(KEY_CANCEL),
              style: const TextStyle(color: AppColors.textGrey),
            ),
          ),
          TextButton(
            onPressed: () async {
              try {
                await _messageController.leaveGroup(
                  widget.chat.id,
                  currentUserId!,
                );
                if (mounted) {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to chat list
                  Get.snackbar(
                    getTranslation(KEY_SUCCESS),
                    getTranslation(KEY_LEFT_GROUP),
                    backgroundColor: AppColors.green,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                Get.snackbar(
                  getTranslation(KEY_ERROR),
                  getTranslation(KEY_FAILED_LEAVE_GROUP),
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                  snackPosition: SnackPosition.BOTTOM,
                );
              }
            },
            child: Text(
              getTranslation(KEY_LEAVE),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
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
    _readMarkingDebounceTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
