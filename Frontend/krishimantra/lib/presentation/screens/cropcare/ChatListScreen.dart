import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/utils/language_helper.dart';
import '../../../data/models/consultant_model.dart';
import '../../../data/models/message_model.dart';
import '../../../data/services/UserService.dart';
import '../../../data/services/language_service.dart';
import '../../controllers/message_controller.dart';
import '../../widgets/app_header.dart';
import '../../widgets/skeleton/skeleton_widgets.dart';
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

class _ChatListScreenState extends State<ChatListScreen> with TranslationMixin {
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

  // Translation keys
  static const String KEY_UNKNOWN_GROUP = 'unknown_group';
  static const String KEY_UNKNOWN = 'unknown';
  static const String KEY_NO_MESSAGES = 'no_messages_yet';
  static const String KEY_CREATE_NEW_GROUP = 'create_new_group';
  static const String KEY_GROUP_NAME = 'group_name';
  static const String KEY_ENTER_GROUP_NAME = 'enter_group_name';
  static const String KEY_GROUP_DESCRIPTION = 'group_description';
  static const String KEY_ENTER_GROUP_DESC = 'enter_group_description';
  static const String KEY_CANCEL = 'cancel';
  static const String KEY_CREATE_GROUP = 'create_group';
  static const String KEY_SUCCESS = 'success';
  static const String KEY_GROUP_CREATED = 'group_created_successfully';
  static const String KEY_ERROR = 'error';
  static const String KEY_FAILED_CREATE_GROUP = 'failed_to_create_group';
  static const String KEY_ENTER_GROUP_NAME_ERROR = 'please_enter_group_name';
  static const String KEY_LOCATION_PERMISSION = 'location_permission_required';
  static const String KEY_LOCATION_PERMISSION_MSG = 'enable_location_for_consultants';
  static const String KEY_OPEN_SETTINGS = 'open_settings';
  static const String KEY_AVAILABLE_CONSULTANTS = 'available_consultants';
  static const String KEY_NO_CONSULTANTS = 'no_consultants_available';
  static const String KEY_YEARS = 'years';
  static const String KEY_FAILED_CREATE_CHAT = 'failed_to_create_chat';
  static const String KEY_RETRY = 'retry';
  static const String KEY_NO_CHATS = 'no_chats_found';
  static const String KEY_YESTERDAY = 'yesterday';
  static const String KEY_MONDAY = 'monday';
  static const String KEY_TUESDAY = 'tuesday';
  static const String KEY_WEDNESDAY = 'wednesday';
  static const String KEY_THURSDAY = 'thursday';
  static const String KEY_FRIDAY = 'friday';
  static const String KEY_SATURDAY = 'saturday';
  static const String KEY_SUNDAY = 'sunday';

  @override
  void initState() {
    super.initState();
    _registerTranslations();
    _initializeLanguage();
    _loadCachedChats();
    // Add a small delay to ensure user ID is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialChats();
    });
    _setupScrollListener();
  }

  void _registerTranslations() {
    registerTranslation(KEY_UNKNOWN_GROUP, 'Unknown Group');
    registerTranslation(KEY_UNKNOWN, 'Unknown');
    registerTranslation(KEY_NO_MESSAGES, 'No messages yet');
    registerTranslation(KEY_CREATE_NEW_GROUP, 'Create New Group');
    registerTranslation(KEY_GROUP_NAME, 'Group Name');
    registerTranslation(KEY_ENTER_GROUP_NAME, 'Enter group name');
    registerTranslation(KEY_GROUP_DESCRIPTION, 'Group Description');
    registerTranslation(KEY_ENTER_GROUP_DESC, 'Enter group description');
    registerTranslation(KEY_CANCEL, 'Cancel');
    registerTranslation(KEY_CREATE_GROUP, 'Create Group');
    registerTranslation(KEY_SUCCESS, 'Success');
    registerTranslation(KEY_GROUP_CREATED, 'Group created successfully');
    registerTranslation(KEY_ERROR, 'Error');
    registerTranslation(KEY_FAILED_CREATE_GROUP, 'Failed to create group');
    registerTranslation(KEY_ENTER_GROUP_NAME_ERROR, 'Please enter a group name');
    registerTranslation(KEY_LOCATION_PERMISSION, 'Location Permission Required');
    registerTranslation(KEY_LOCATION_PERMISSION_MSG, 'Please enable location services to connect with consultants near you.');
    registerTranslation(KEY_OPEN_SETTINGS, 'Open Settings');
    registerTranslation(KEY_AVAILABLE_CONSULTANTS, 'Available Consultants');
    registerTranslation(KEY_NO_CONSULTANTS, 'No consultants available');
    registerTranslation(KEY_YEARS, 'years');
    registerTranslation(KEY_FAILED_CREATE_CHAT, 'Failed to create chat');
    registerTranslation(KEY_RETRY, 'Retry');
    registerTranslation(KEY_NO_CHATS, 'No chats found');
    registerTranslation(KEY_YESTERDAY, 'Yesterday');
    registerTranslation(KEY_MONDAY, 'Monday');
    registerTranslation(KEY_TUESDAY, 'Tuesday');
    registerTranslation(KEY_WEDNESDAY, 'Wednesday');
    registerTranslation(KEY_THURSDAY, 'Thursday');
    registerTranslation(KEY_FRIDAY, 'Friday');
    registerTranslation(KEY_SATURDAY, 'Saturday');
    registerTranslation(KEY_SUNDAY, 'Sunday');
  }

  Future<void> _initializeLanguage() async {
    await updateTranslations();
    if (mounted) setState(() {});
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
    final avatarRadius = ResponsiveUtils.responsive(mobile: 24.0, tablet: 30.0);

    return InkWell(
      onTap: () async {
        await Get.to(() => ChatDetailScreen(chat: chat));
        // Refresh chats after returning to update unread counts
        if (_messageController.userId.value != null) {
          _messageController.loadUserChats(_messageController.userId.value!);
        }
      },
      child: Container(
        padding: RPadding.symmetric(horizontal: 16, vertical: 12),
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
              radius: avatarRadius,
              backgroundColor: AppColors.faintGreen,
              backgroundImage: !isGroup &&
                      otherParticipant?.profilePhoto != null &&
                      otherParticipant!.profilePhoto!.isNotEmpty
                  ? NetworkImage(otherParticipant.profilePhoto!)
                  : null,
              child: isGroup
                  ? Icon(Icons.group, color: AppColors.green, size: AppSizes.iconM)
                  : (otherParticipant?.profilePhoto == null ||
                          otherParticipant!.profilePhoto!.isEmpty)
                      ? Text(
                          (otherParticipant?.userName ?? '?')[0].toUpperCase(),
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: AppSizes.fontL,
                          ),
                        )
                      : null,
            ),
            SizedBox(width: AppSizes.paddingM),
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
                              ? chat.groupDetails?.name ?? getTranslation(KEY_UNKNOWN_GROUP)
                              : otherParticipant?.userName ?? getTranslation(KEY_UNKNOWN),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: AppSizes.fontL,
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
                          fontSize: AppSizes.fontS,
                          color: AppColors.textGrey.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSizes.paddingXS),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessage?.content ?? getTranslation(KEY_NO_MESSAGES),
                          style: TextStyle(
                            color: AppColors.textGrey.withOpacity(0.8),
                            fontSize: AppSizes.fontM,
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
                          margin: EdgeInsets.only(left: AppSizes.paddingS),
                          padding: RPadding.symmetric(horizontal: 8, vertical: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.green,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            chat.unreadCount[_messageController.userId.value]
                                .toString(),
                            style: TextStyle(
                              color: AppColors.white,
                              fontSize: AppSizes.fontS,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusXL)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        padding: RPadding.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppSizes.radiusXL),
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
                  padding: RPadding.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.faintGreen,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                  ),
                  child: Icon(
                    Icons.group_add,
                    color: AppColors.green,
                    size: AppSizes.iconM,
                  ),
                ),
                SizedBox(width: AppSizes.paddingM),
                Flexible(
                  child: Text(
                    getTranslation(KEY_CREATE_NEW_GROUP),
                    style: TextStyle(
                      fontSize: AppSizes.fontTitle,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textGrey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSizes.paddingXL),
            Text(
              getTranslation(KEY_GROUP_NAME),
              style: TextStyle(
                fontSize: AppSizes.fontM,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey,
              ),
            ),
            SizedBox(height: AppSizes.paddingS),
            TextField(
              controller: _groupNameController,
              style: TextStyle(fontSize: AppSizes.fontM),
              decoration: InputDecoration(
                hintText: getTranslation(KEY_ENTER_GROUP_NAME),
                hintStyle: TextStyle(
                  color: AppColors.textGrey.withOpacity(0.5),
                  fontSize: AppSizes.fontM,
                ),
                filled: true,
                fillColor: AppColors.faintGreen.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  borderSide:
                      const BorderSide(color: AppColors.green, width: 1.5),
                ),
                prefixIcon: Icon(
                  Icons.group,
                  color: AppColors.green,
                  size: AppSizes.iconM,
                ),
              ),
            ),
            SizedBox(height: AppSizes.paddingL),
            Text(
              getTranslation(KEY_GROUP_DESCRIPTION),
              style: TextStyle(
                fontSize: AppSizes.fontM,
                fontWeight: FontWeight.w600,
                color: AppColors.textGrey,
              ),
            ),
            SizedBox(height: AppSizes.paddingS),
            TextField(
              controller: _groupDescController,
              maxLines: 3,
              style: TextStyle(fontSize: AppSizes.fontM),
              decoration: InputDecoration(
                hintText: getTranslation(KEY_ENTER_GROUP_DESC),
                hintStyle: TextStyle(
                  color: AppColors.textGrey.withOpacity(0.5),
                  fontSize: AppSizes.fontM,
                ),
                filled: true,
                fillColor: AppColors.faintGreen.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  borderSide:
                      const BorderSide(color: AppColors.green, width: 1.5),
                ),
              ),
            ),
            SizedBox(height: AppSizes.paddingXXL),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(
                      padding: RPadding.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      getTranslation(KEY_CANCEL),
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: AppSizes.fontL,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSizes.paddingS),
                Flexible(
                  child: ElevatedButton(
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
                            getTranslation(KEY_SUCCESS),
                            getTranslation(KEY_GROUP_CREATED),
                            backgroundColor: AppColors.green,
                            colorText: Colors.white,
                            snackPosition: SnackPosition.BOTTOM,
                          );
                        }
                      } catch (e) {
                        Get.snackbar(
                          getTranslation(KEY_ERROR),
                          getTranslation(KEY_FAILED_CREATE_GROUP),
                          backgroundColor: Colors.red,
                          colorText: Colors.white,
                          snackPosition: SnackPosition.BOTTOM,
                        );
                      }
                    } else {
                      Get.snackbar(
                        getTranslation(KEY_ERROR),
                        getTranslation(KEY_ENTER_GROUP_NAME_ERROR),
                        backgroundColor: Colors.red,
                        colorText: Colors.white,
                        snackPosition: SnackPosition.BOTTOM,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: RPadding.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSizes.radiusL),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    getTranslation(KEY_CREATE_GROUP),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppSizes.fontL,
                      fontWeight: FontWeight.w600,
                    ),
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
        title: Text(getTranslation(KEY_LOCATION_PERMISSION)),
        content: Text(getTranslation(KEY_LOCATION_PERMISSION_MSG)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(getTranslation(KEY_CANCEL)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await AppSettings.openAppSettings();
            },
            child: Text(getTranslation(KEY_OPEN_SETTINGS)),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXXL)),
        ),
        child: Column(
          children: [
            Container(
              padding: RPadding.all(16),
              decoration: BoxDecoration(
                color: AppColors.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusXXL)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: Colors.white, size: AppSizes.iconM),
                  SizedBox(width: AppSizes.paddingM),
                  Text(
                    getTranslation(KEY_AVAILABLE_CONSULTANTS),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: AppSizes.fontL,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white, size: AppSizes.iconM),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (_messageController.isLoadingConsultants.value) {
                  return SizedBox(
                    height: 160,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: AppSizes.paddingL),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        return const SkeletonConsultantCard();
                      },
                    ),
                  );
                }

                if (_messageController.consultantError.value != null) {
                  return Center(
                    child: Text(
                      _messageController.consultantError.value!,
                      style: TextStyle(fontSize: AppSizes.fontM),
                    ),
                  );
                }

                if (_messageController.consultants.isEmpty) {
                  return Center(
                    child: Text(
                      getTranslation(KEY_NO_CONSULTANTS),
                      style: TextStyle(fontSize: AppSizes.fontM),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: _messageController.consultants.length,
                  padding: RPadding.all(16),
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

    final avatarRadius = ResponsiveUtils.responsive(mobile: 30.0, tablet: 38.0);
    final avatarSize = avatarRadius * 2;

    return Card(
      margin: EdgeInsets.only(bottom: AppSizes.paddingL),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusL)),
      child: InkWell(
        onTap: () => _createDirectChat(consultant),
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        child: Padding(
          padding: RPadding.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: avatarRadius,
                backgroundColor: AppColors.faintGreen,
                child: consultant.profilePhotoId != null
                    ? ClipOval(
                        child: Image.network(
                          consultant.profilePhotoId!,
                          width: avatarSize,
                          height: avatarSize,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              consultant.userName[0].toUpperCase(),
                              style: TextStyle(
                                color: AppColors.green,
                                fontSize: AppSizes.fontTitle,
                              ),
                            );
                          },
                        ),
                      )
                    : Text(
                        consultant.userName[0].toUpperCase(),
                        style: TextStyle(
                          color: AppColors.green,
                          fontSize: AppSizes.fontTitle,
                        ),
                      ),
              ),
              SizedBox(width: AppSizes.paddingL),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consultant.userName,
                      style: TextStyle(
                        fontSize: AppSizes.fontL,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: AppSizes.paddingXS),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: AppSizes.iconS),
                        Text(' ${consultant.rating}', style: TextStyle(fontSize: AppSizes.fontM)),
                        Text(' • ${consultant.experience} ${getTranslation(KEY_YEARS)}', style: TextStyle(fontSize: AppSizes.fontM)),
                      ],
                    ),
                    SizedBox(height: AppSizes.paddingXS),
                    Row(
                      children: [
                        if (consultant.company.logo.isNotEmpty &&
                            Uri.tryParse(consultant.company.logo)?.hasScheme ==
                                true)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppSizes.radiusXS),
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
                              borderRadius: BorderRadius.circular(AppSizes.radiusXS),
                            ),
                            child: Icon(Icons.business,
                                size: 12, color: Colors.grey[400]),
                          ),
                        SizedBox(width: AppSizes.paddingS),
                        Text(
                          consultant.company.name,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: AppSizes.fontS,
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
          await Get.to(() => ChatDetailScreen(chat: chat));
          // Refresh chats after returning to update unread counts
          if (_messageController.userId.value != null) {
            _messageController.loadUserChats(_messageController.userId.value!);
          }
        }
      } else {
        throw Exception('Invalid chat object received');
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) {
        Get.back();
      }

      Get.snackbar(
        getTranslation(KEY_ERROR),
        '${getTranslation(KEY_FAILED_CREATE_CHAT)}: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ResponsiveUtils.init(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: AppColors.green,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: Column(
          children: [
            Container(
              color: AppColors.green,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                right: AppSizes.paddingL,
                bottom: AppSizes.paddingL,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: Colors.white, size: AppSizes.iconM),
                    onPressed: () => Get.back(),
                  ),
                  const Expanded(child: AppHeader()),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (_messageController.isLoading.value && _currentPage == 1) {
                  return ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 5,
                    itemBuilder: (context, index) {
                      return const SkeletonChatItem();
                    },
                  );
                }

                if (_messageController.error.value != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _messageController.error.value!,
                          style: TextStyle(color: Colors.red, fontSize: AppSizes.fontM),
                        ),
                        SizedBox(height: AppSizes.paddingL),
                        ElevatedButton(
                          onPressed: _onRefresh,
                          style: ElevatedButton.styleFrom(
                            padding: RPadding.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.radiusL),
                            ),
                          ),
                          child: Text(getTranslation(KEY_RETRY), style: TextStyle(fontSize: AppSizes.fontM)),
                        ),
                      ],
                    ),
                  );
                }

                if (_messageController.chats.isEmpty) {
                  return Center(
                    child: Text(
                      getTranslation(KEY_NO_CHATS),
                      style: TextStyle(
                        color: AppColors.textGrey,
                        fontSize: AppSizes.fontL,
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
                        return Center(
                          child: Padding(
                            padding: RPadding.all(8),
                            child: const CircularProgressIndicator(
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
                  child: Icon(Icons.group_add, color: AppColors.white, size: AppSizes.iconM),
                ),
                SizedBox(height: AppSizes.paddingL),
                FloatingActionButton(
                  heroTag: 'createChat',
                  onPressed: _showConsultantsList,
                  backgroundColor: AppColors.green,
                  child: Icon(Icons.chat, color: AppColors.white, size: AppSizes.iconM),
                ),
              ],
            );
          }
          return FloatingActionButton(
            onPressed: _showConsultantsList,
            backgroundColor: AppColors.green,
            child: Icon(Icons.chat, color: AppColors.white, size: AppSizes.iconM),
          );
        }),
      ),
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
      return getTranslation(KEY_YESTERDAY);
    } else if (difference.inDays < 7) {
      return _getDayOfWeek(dateTime.weekday);
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _getDayOfWeek(int day) {
    switch (day) {
      case 1:
        return getTranslation(KEY_MONDAY);
      case 2:
        return getTranslation(KEY_TUESDAY);
      case 3:
        return getTranslation(KEY_WEDNESDAY);
      case 4:
        return getTranslation(KEY_THURSDAY);
      case 5:
        return getTranslation(KEY_FRIDAY);
      case 6:
        return getTranslation(KEY_SATURDAY);
      case 7:
        return getTranslation(KEY_SUNDAY);
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
