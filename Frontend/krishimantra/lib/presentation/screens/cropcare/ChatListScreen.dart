import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../data/models/consultant_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/UserService.dart';
import '../../controllers/message_controller.dart';
import '../../widgets/app_header.dart';
import 'ChatDetailScreen.dart';
import 'package:get_storage/get_storage.dart';
import '../../../data/services/LocationService.dart';
import 'package:app_settings/app_settings.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

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
  final _box = GetStorage();
  static const String CACHED_CHATS_KEY = 'cached_chats';

  @override
  void initState() {
    super.initState();
    _loadCachedChats();
    // Add a small delay to ensure user ID is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialChats();
    });
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

  void _loadCachedChats() {
    try {
      final cachedChats = _box.read(CACHED_CHATS_KEY);
      if (cachedChats != null) {
        final List<dynamic> chatsList = List<dynamic>.from(cachedChats);
        // Convert each dynamic map to Chat object
        final List<Chat> chats =
            chatsList.map((chat) => Chat.fromJson(chat)).toList();
        _messageController.chats.value = chats;
      }
    } catch (e) {}
  }

  Future<void> _loadInitialChats() async {
    // Add retry logic if userId is not immediately available
    int retryCount = 0;
    while (_messageController.userId.value == null && retryCount < 3) {
      await Future.delayed(const Duration(milliseconds: 500));
      retryCount++;
    }

    if (_messageController.userId.value != null) {
      try {
        await _messageController.loadUserChats(
          _messageController.userId.value!,
          page: 1,
          limit: _itemsPerPage,
        );

        // Cache the new chats
        if (_messageController.chats.isNotEmpty) {
          final chatJsonList =
              _messageController.chats.map((chat) => chat.toJson()).toList();
          await _box.write(CACHED_CHATS_KEY, chatJsonList);
        }
      } catch (e) {}
    } else {}
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
        width: MediaQuery.of(context).size.width * 0.9,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                    Icons.group_add,
                    color: AppColors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Create New Group',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Group Name',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _groupNameController,
              decoration: InputDecoration(
                hintText: 'Enter group name',
                hintStyle: TextStyle(
                  color: AppColors.textGrey.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppColors.faintGreen.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.green, width: 1.5),
                ),
                prefixIcon: const Icon(
                  Icons.group,
                  color: AppColors.green,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Group Description',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _groupDescController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter group description',
                hintStyle: TextStyle(
                  color: AppColors.textGrey.withOpacity(0.5),
                ),
                filled: true,
                fillColor: AppColors.faintGreen.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.green, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Get.back(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: AppColors.textGrey,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (_groupNameController.text.isNotEmpty) {
                      try {
                        Get.back(); // Close dialog first
                        await _messageController.createGroup(
                          name: _groupNameController.text,
                          description: _groupDescController.text,
                          participants: [], // Initialize with empty list
                          onlyAdminCanMessage: false,
                        );
                        if (mounted) {
                          // Check if widget is still mounted
                          _groupNameController.clear();
                          _groupDescController.clear();
                          Get.snackbar(
                            'Success',
                            'Group created successfully',
                            backgroundColor: AppColors.green,
                            colorText: Colors.white,
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        }
                      } catch (e) {
                        Get.snackbar(
                          'Error',
                          'Failed to create group',
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    } else {
                      Get.snackbar(
                        'Error',
                        'Please enter a group name',
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: const Text(
                    'Create Group',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showConsultantsList() async {
    final locationService = Get.find<
        LocationService>(); // Make sure to create and register this service

    try {
      final position = await locationService.getCurrentPosition();
      if (position == null) {
        _showLocationPermissionDialog();
        return;
      }

      await _messageController.getConsultants(
          // latitude: position.latitude,
          // longitude: position.longitude,
          );

      _showConsultantsBottomSheet();
    } catch (e) {
      _showLocationPermissionDialog();
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
            'Please enable location services to connect with consultants near you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AppSettings.openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showConsultantsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text(
                    'Available Consultants',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (_messageController.isLoadingConsultants.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.green),
                  );
                }

                if (_messageController.consultantError.value != null) {
                  return Center(
                    child: Text(_messageController.consultantError.value!),
                  );
                }

                if (_messageController.consultants.isEmpty) {
                  return const Center(
                    child: Text('No consultants available'),
                  );
                }

                return ListView.builder(
                  itemCount: _messageController.consultants.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final consultant = _messageController.consultants[index];
                    return _buildConsultantCard(consultant);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsultantCard(Consultant consultant) {
    if (kDebugMode) {
      print(
          'Building card for consultant: ${consultant.id} - ${consultant.userName}');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _createDirectChat(consultant),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.faintGreen,
                child: consultant.profilePhotoId != null
                    ? ClipOval(
                        child: Image.network(
                          consultant.profilePhotoId!,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              consultant.userName[0].toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.green,
                                fontSize: 24,
                              ),
                            );
                          },
                        ),
                      )
                    : Text(
                        consultant.userName[0].toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.green,
                          fontSize: 24,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consultant.userName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 16),
                        Text(' ${consultant.rating}'),
                        Text(' • ${consultant.experience} years'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (consultant.company.logo.isNotEmpty &&
                            Uri.tryParse(consultant.company.logo)?.hasScheme ==
                                true)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              consultant.company.logo,
                              height: 20,
                              width: 20,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  height: 20,
                                  width: 20,
                                  color: Colors.grey[200],
                                  child: Icon(Icons.business,
                                      size: 12, color: Colors.grey[400]),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            height: 20,
                            width: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(Icons.business,
                                size: 12, color: Colors.grey[400]),
                          ),
                        const SizedBox(width: 8),
                        Text(
                          consultant.company.name,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
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
      ),
    );
  }

  Future<void> _createDirectChat(Consultant consultant) async {
    try {
      // Log the consultant for debugging
      if (kDebugMode) {
        print(
            'Creating chat with consultant: ${consultant.id} - ${consultant.userName}');
      }

      // Show loading indicator
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(),
        ),
        barrierDismissible: false,
      );

      // First check if chat already exists with this specific consultant
      Chat? existingChat;
      if (_messageController.chats.isNotEmpty) {
        existingChat = _messageController.chats.firstWhereOrNull((chat) =>
            chat.type == 'direct' &&
            chat.otherParticipants.isNotEmpty &&
            chat.otherParticipants.first.userId == consultant.id);

        if (kDebugMode && existingChat != null) {
          print(
              'Found existing chat: ${existingChat.id} with ${existingChat.otherParticipants.first.userName}');
        }
      }

      // If chat exists, use it; otherwise create a new one
      Chat? chat = existingChat;
      if (chat == null) {
        if (kDebugMode) {
          print(
              'No existing chat found. Creating new chat with: ${consultant.userName}');
        }

        chat = await _messageController.createDirectChat(
          participantId: consultant.id,
          participantName: consultant.userName,
          participantProfilePhoto: consultant.profilePhotoId,
        );
      }

      Get.back(); // Close loading dialog

      if (chat != null && chat.id.isNotEmpty) {
        if (mounted) {
          Navigator.pop(context); // Close consultant list
          await Future.delayed(const Duration(milliseconds: 100));
          Get.to(() => ChatDetailScreen(chat: chat));
        }
      } else {
        throw Exception('Invalid chat object received');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        'Error',
        'Failed to create chat: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
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
                onPressed: _showConsultantsList,
                backgroundColor: AppColors.green,
                child: const Icon(Icons.chat, color: AppColors.white),
              ),
            ],
          );
        }
        return FloatingActionButton(
          onPressed: _showConsultantsList,
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
