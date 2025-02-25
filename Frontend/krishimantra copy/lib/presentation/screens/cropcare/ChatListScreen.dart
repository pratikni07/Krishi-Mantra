import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../controllers/message_controller.dart';
import '../../widgets/app_header.dart';
import 'ChatDetailScreen.dart';
import '../../services/user_service.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final MessageController _messageController = Get.find<MessageController>();
  final UserService _userService = Get.find<UserService>();
  final TextEditingController _groupNameController = TextEditingController();
  final TextEditingController _groupDescController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  static const int _itemsPerPage = 20;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadInitialChats();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent) {
        _loadMoreChats();
      }
    });
  }

  Future<void> _loadInitialChats() async {
    if (_messageController.userId.value != null &&
        !_messageController.isLoading.value) {
      await _messageController.loadUserChats(
        _messageController.userId.value!,
        page: 1,
        limit: _itemsPerPage,
      );
    }
  }

  Future<void> _loadMoreChats() async {
    if (!_isLoadingMore &&
        _messageController.userId.value != null &&
        !_messageController.isLoading.value &&
        _messageController.chats.length >= _itemsPerPage) {
      // If we have at least one full page
      setState(() {
        _isLoadingMore = true;
      });

      final previousLength = _messageController.chats.length;
      _currentPage++;

      await _messageController.loadUserChats(
        _messageController.userId.value!,
        page: _currentPage,
        limit: _itemsPerPage,
      );

      // If no new items were loaded, we've reached the end
      if (previousLength == _messageController.chats.length) {
        _currentPage--; // Revert the page increment
      }

      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    _currentPage = 1;
    await _loadInitialChats();
  }

  Widget _buildChatItem(dynamic chat, int index) {
    final isGroup = chat.type == 'group';
    final otherParticipant =
        chat.otherParticipants.isNotEmpty ? chat.otherParticipants.first : null;
    final lastMessage = chat.lastMessageDetails?.isNotEmpty == true
        ? chat.lastMessageDetails?.first
        : null;

    return InkWell(
      onTap: () {
        Get.to(() => ChatDetailScreen(chat: chat));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.faintGreen,
              backgroundImage: isGroup
                  ? null
                  : NetworkImage(otherParticipant?.profilePhoto ?? ''),
              child: isGroup
                  ? const Icon(Icons.group, color: AppColors.green)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isGroup
                              ? chat.groupDetails?.name ?? 'Unknown Group'
                              : otherParticipant?.userName ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.textGrey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatDateTime(
                            lastMessage?.createdAt ?? chat.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textGrey.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage?.content ?? 'No messages yet',
                          style: TextStyle(
                            color: AppColors.textGrey.withOpacity(0.8),
                            fontSize: 14,
                            fontStyle: lastMessage == null
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.unreadCount[_messageController.userId.value] !=
                              null &&
                          chat.unreadCount[_messageController.userId.value]! >
                              0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chat.unreadCount[_messageController.userId.value]
                                .toString(),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateGroupDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Create New Group',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                hintText: 'Group Name',
                filled: true,
                fillColor: AppColors.faintGreen.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.green),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _groupDescController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Group Description',
                filled: true,
                fillColor: AppColors.faintGreen.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.green),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Get.back(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.textGrey),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (_groupNameController.text.isNotEmpty) {
                      await _messageController.createGroup(
                        name: _groupNameController.text,
                        description: _groupDescController.text,
                        participants: [],
                        onlyAdminCanMessage: false,
                      );
                      _groupNameController.clear();
                      _groupDescController.clear();
                      Get.back();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Create',
                    style: TextStyle(color: AppColors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.green,
              padding: const EdgeInsets.all(16),
              child: const AppHeader(),
            ),
            Expanded(
              child: Obx(() {
                if (_messageController.isLoading.value && _currentPage == 1) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.green),
                  );
                }

                if (_messageController.error.value != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _messageController.error.value!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _onRefresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                if (_messageController.chats.isEmpty) {
                  return const Center(
                    child: Text(
                      'No chats found',
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppColors.green,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _messageController.chats.length +
                        (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messageController.chats.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(
                              color: AppColors.green,
                            ),
                          ),
                        );
                      }
                      return _buildChatItem(
                          _messageController.chats[index], index);
                    },
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      floatingActionButton: Obx(() {
        final accountType = _messageController.accountType.value;
        if (accountType == 'consultant' || accountType == 'admin') {
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FloatingActionButton(
                heroTag: 'createGroup',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _buildCreateGroupDialog(),
                  );
                },
                backgroundColor: AppColors.green,
                child: const Icon(Icons.group_add, color: AppColors.white),
              ),
              const SizedBox(height: 16),
              FloatingActionButton(
                heroTag: 'createChat',
                onPressed: () {
                  // Navigate to new chat creation screen
                  // Get.to(() => NewChatScreen());
                },
                backgroundColor: AppColors.green,
                child: const Icon(Icons.chat, color: AppColors.white),
              ),
            ],
          );
        }
        return FloatingActionButton(
          onPressed: () {
            // Navigate to new chat creation screen
            // Get.to(() => NewChatScreen());
          },
          backgroundColor: AppColors.green,
          child: const Icon(Icons.chat, color: AppColors.white),
        );
      }),
    );
  }

  String _formatDateTime(dynamic dateTimeValue) {
    if (dateTimeValue == null) return '';

    DateTime dateTime;
    if (dateTimeValue is String) {
      try {
        dateTime = DateTime.parse(dateTimeValue);
      } catch (e) {
        return '';
      }
    } else if (dateTimeValue is DateTime) {
      dateTime = dateTimeValue;
    } else {
      return '';
    }

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return _getDayOfWeek(dateTime.weekday);
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _getDayOfWeek(int day) {
    switch (day) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _groupNameController.dispose();
    _groupDescController.dispose();
    super.dispose();
  }
}
