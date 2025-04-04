import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../data/models/consultant_model.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/services/SocketService.dart';
import '../../data/services/UserService.dart';

class MessageController extends GetxController {
  final MessageRepository _messageRepository;
  final UserService _userService;

  final hasMoreMessages = true.obs;

  final messages = <Message>[].obs;
  final chats = <Chat>[].obs;
  final isLoading = false.obs;
  final error = Rx<String?>(null);
  final currentPage = 1.obs;

  // User information
  final Rx<String?> userId = Rx<String?>(null);
  final Rx<String?> userName = Rx<String?>(null);
  final Rx<String?> userProfilePhoto = Rx<String?>(null);
  final Rx<String?> accountType = Rx<String?>(null);


 final consultants = <Consultant>[].obs;
  final isLoadingConsultants = false.obs;
  final consultantError = Rx<String?>(null);


  MessageController(this._messageRepository, this._userService);

  @override
  void onInit() {
    super.onInit();
    loadUserInfo();
  }

  Future<void> loadMessages({
    required String chatId,
    required int page,
    required int limit,
  }) async {
    try {
      isLoading.value = true;
      error.value = null;

      final user = await _userService.getUser();
      if (user == null) {
        error.value = 'User not authenticated';
        return;
      }

      final fetchedMessages = await _messageRepository.getMessagesByChatId(
        chatId: chatId,
        page: page,
        limit: limit,
        userId: user.id,
      );

      // Check if we received fewer messages than requested
      hasMoreMessages.value = fetchedMessages.length >= limit;

      if (page == 1) {
        messages.assignAll(fetchedMessages);
      } else {
        // Filter out any messages that are already in the list
        final existingMessageIds = messages.map((m) => m.id).toSet();
        final newMessages = fetchedMessages
            .where((message) => !existingMessageIds.contains(message.id))
            .toList();

        if (newMessages.isEmpty) {
          hasMoreMessages.value = false;
        } else {
          messages.insertAll(
              0, newMessages); // Insert at beginning for older messages
        }
      }

      currentPage.value = page;
    } catch (e) {
      print('Error in loadMessages: $e');
      error.value = 'Failed to load messages';
      hasMoreMessages.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadUserInfo() async {
    try {
      final user = await _userService.getUser();
      if (user != null) {
        userId.value = user.id;
        userName.value =
            '${await _userService.getFirstName()} ${await _userService.getLastName()}';
        userProfilePhoto.value = await _userService.getImage();
        accountType.value = await _userService.getAccountType();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user info: $e');
      }
    }
  }

  // In message_controller.dart
  Future<bool> sendMessage(
      {required String chatId,
      required String content,
      String mediaType = 'text',
      String? mediaUrl}) async {
    try {
      final socketService = SocketService();

      // Ensure socket is connected
      if (!socketService.isSocketConnected()) {
        await socketService.forceConnect();
      }
      // Send via socket
      final result = await socketService.sendMessage(chatId, {
        'content': content,
        'mediaType': mediaType,
        'mediaUrl': mediaUrl,
      });

      if (!result) {
        throw Exception('Failed to send message via socket');
      }

      return true;
    } catch (e) {
      print('Error sending message: $e');
      return false;
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    if (userId.value == null) {
      error.value = 'User not authenticated';
      return;
    }

    try {
      error.value = null;

      final updatedMessage = await _messageRepository.markMessageAsRead(
        messageId: messageId,
        userId: userId.value!,
      );

      // Update message read status locally
      final messageIndex = messages.indexWhere((m) => m.id == messageId);
      if (messageIndex != -1) {
        messages[messageIndex] = updatedMessage;
      }

      // Update unread count in the corresponding chat
      final chatIndex =
          chats.indexWhere((chat) => chat.id == updatedMessage.chatId);
      if (chatIndex != -1) {
        final chat = chats[chatIndex];
        final unreadCount = Map<String, int>.from(chat.unreadCount);
        if (unreadCount.containsKey(userId.value)) {
          unreadCount[userId.value!] = (unreadCount[userId.value!] ?? 1) - 1;
          // Create a new chat object with updated unread count
          // Note: You'll need to add a copyWith method to your Chat class
          final updatedChat = Chat(
            id: chat.id,
            type: chat.type,
            participants: chat.participants,
            unreadCount: unreadCount,
            createdAt: chat.createdAt,
            updatedAt: chat.updatedAt,
            lastMessage: chat.lastMessage,
            lastMessageDetails: chat.lastMessageDetails,
            groupDetails: chat.groupDetails,
            otherParticipants: chat.otherParticipants,
          );
          chats[chatIndex] = updatedChat;
        }
      }
    } catch (e) {
      error.value = 'Failed to mark message as read';
      if (kDebugMode) {
        print('Error marking message as read: $e');
      }
    }
  }

  Future<void> loadUserChats(String userId,
      {int page = 1, int limit = 20}) async {
    try {
      if (page == 1) {
        isLoading.value = true;
      }
      error.value = null;

      final userChats = await _messageRepository.getUserChats(
        userId: userId,
        page: page,
        limit: limit,
      );

      if (page == 1) {
        chats.assignAll(userChats);
      } else {
        // Only add new chats if they don't already exist
        final existingIds = chats.map((chat) => chat.id).toSet();
        final newChats =
            userChats.where((chat) => !existingIds.contains(chat.id));
        chats.addAll(newChats);
      }
    } catch (e) {
      error.value = 'Failed to load chats';
      print('Error loading user chats: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void setUserId(String id) {
    userId.value = id;
  }

  void clearChats() {
    chats.clear();
    error.value = null;
  }

  Future<void> createGroup({
    required String name,
    required String description,
    required List<String> participants,
    bool onlyAdminCanMessage = false,
  }) async {
    if (userId.value == null || userName.value == null) {
      error.value = 'User not authenticated';
      return;
    }

    try {
      isLoading.value = true;
      error.value = null;

      final groupChat = await _messageRepository.createGroup(
        userId: userId.value!,
        userName: userName.value!,
        name: name,
        description: description,
        participants: participants,
        onlyAdminCanMessage: onlyAdminCanMessage,
      );

      // Check if both chat and group details exist
      if (groupChat.chat != null) {
        // Insert at the beginning of the chats list
        chats.insert(0, groupChat.chat!);
      } else {
        throw Exception('Failed to create group chat');
      }
    } catch (e) {
      error.value = 'Failed to create group';
      print('Error creating group: $e');
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addGroupParticipants(
      String groupId, List<String> participants) async {
    try {
      isLoading.value = true;
      error.value = null;

      await _messageRepository.addGroupParticipants(
        groupId: groupId,
        participants: participants,
      );

      await loadUserChats(Get.find<String>());
    } catch (e) {
      error.value = 'Failed to add participants';
      if (kDebugMode) {
        print('Error adding group participants: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> joinGroup(String inviteUrl, String userId) async {
    try {
      isLoading.value = true;
      error.value = null;

      await _messageRepository.joinGroup(
        inviteUrl: inviteUrl,
        userId: userId,
      );

      // Refresh chat list to include the newly joined group
      await loadUserChats(userId);
    } catch (e) {
      error.value = 'Failed to join group';
      if (kDebugMode) {
        print('Error joining group: $e');
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> leaveGroup(String groupId, String userId) async {
    try {
      await _messageRepository.leaveGroup(groupId: groupId, userId: userId);
      // Remove the group from local chats list
      chats.removeWhere((chat) => chat.id == groupId);
    } catch (e) {
      print('Error leaving group: $e');
      rethrow;
    }
  }


  Future<void> getConsultants({
    required double latitude,
    required double longitude,
  }) async {
    try {
      isLoadingConsultants.value = true;
      consultantError.value = null;
      
      final fetchedConsultants = await _messageRepository.getConsultants(
        latitude: 18.6161,
        longitude: 73.7286,
      );
      
      consultants.value = fetchedConsultants;
    } catch (e) {
      consultantError.value = 'Failed to load consultants';
      print('Error fetching consultants: $e');
    } finally {
      isLoadingConsultants.value = false;
    }
  }

  Future<Chat?> createDirectChat({
    required String participantId,
    required String participantName,
    required String participantProfilePhoto,
  }) async {
    try {
      final user = await _userService.getUser();
      if (user == null) throw Exception('User not authenticated');

      final userProfilePhoto = await _userService.getImage() ?? '';
      final userName = '${await _userService.getFirstName()} ${await _userService.getLastName()}';
      
      final chat = await _messageRepository.createDirectChat(
        userId: user.id,
        userName: userName,
        participantId: participantId,
        participantName: participantName,
        profilePhoto: userProfilePhoto,
        participantProfilePhoto: participantProfilePhoto,
      );

      // Validate chat object
      if (chat != null && chat.id.isNotEmpty) {
        // Add the new chat to the chats list if it doesn't exist
        if (!chats.any((existingChat) => existingChat.id == chat.id)) {
          chats.insert(0, chat);
        }
        return chat;
      } else {
        print('Invalid chat object received from repository');
        return null;
      }
    } catch (e) {
      print('Error in createDirectChat: $e');
      error.value = 'Failed to create chat';
      return null;
    }
  }
}
