// lib/presentation/controllers/ai_chat_controller.dart
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/ai_chat.dart';
import '../../data/models/ai_chat_message.dart';
import '../../data/repositories/ai_chat_repository.dart';
import '../../data/services/SocketService.dart';
import '../../data/services/UserService.dart';
import '../../data/services/language_service.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/services/api_service.dart';
import '../../data/services/engagement_service.dart';
import '../widgets/error_widgets.dart';
import 'presigned_url_controller.dart';

class AIChatController extends GetxController {
  final AIChatRepository _repository;
  final UserService _userService;
  final SocketService _socketService = Get.find<SocketService>();

  final chats = <AIChat>[].obs;
  final currentChat = Rxn<AIChat>();
  final messages = <AIChatMessage>[].obs;
  final isLoading = false.obs;
  final isAnalyzing = false.obs;
  final isTyping = false.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  // Pagination variables
  final currentPage = 1.obs;
  final totalPages = 1.obs;
  final hasMoreChats = true.obs;
  final isLoadingMore = false.obs;

  StreamSubscription? _aiMessageSubscription;
  StreamSubscription? _aiTypingSubscription;
  StreamSubscription? _aiAnalyzingSubscription;

  final isRateLimited = false.obs;
  final rateLimitReset = 0.obs;
  Timer? _rateLimitTimer;

  final remainingMessages = 5.obs;
  final totalDailyLimit = 5.obs;
  final limitResetTime = Rxn<DateTime>();

  final selectedImages = <File>[].obs;
  final isUploadingMultipleImages = false.obs;
  final maxImageCount = 5.obs; // Maximum number of images allowed
  final hasNetworkError =
      false.obs; // Track if there was a network error during image upload

  final messageText = ''.obs;
  final currentChatId = ''.obs;

  AIChatController(this._repository, this._userService);

  @override
  void onInit() {
    super.onInit();
    _setupSocketListeners();
    loadChats();
    _fetchMessageLimitInfo();
  }

  Future<void> _fetchMessageLimitInfo() async {
    try {
      final userId = await _userService.getUserId();
      if (userId == null) return;

      final limitInfo = await _repository.getMessageLimitInfo(userId);
      if (limitInfo != null && limitInfo['remainingMessages'] != null) {
        remainingMessages.value = limitInfo['remainingMessages'];
      }
    } catch (e) {
      print('Error fetching message limit info: $e');
    }
  }

  void _setupSocketListeners() {
    _aiMessageSubscription = _socketService.aiMessageStream.listen((data) {
      try {
        final chatId = data['chatId'];
        if (data['messages'] != null && currentChat.value?.id == chatId) {
          final newMessages = (data['messages'] as List)
              .map((msg) => AIChatMessage.fromJson(msg))
              .toList();

          messages.addAll(newMessages);

          if (currentChat.value != null) {
            final updatedChat = currentChat.value!.copyWith(
              messages: [...currentChat.value!.messages, ...newMessages],
              lastMessageAt: DateTime.now(),
            );
            currentChat.value = updatedChat;

            final index = chats.indexWhere((chat) => chat.id == chatId);
            if (index != -1) {
              chats[index] = updatedChat;
            }
          }
        }
      } catch (e) {}
    });

    _aiTypingSubscription = _socketService.aiTypingStream.listen((data) {
      if (currentChat.value?.id == data['chatId']) {
        isTyping.value = data['isTyping'] ?? false;
      }
    });

    _aiAnalyzingSubscription = _socketService.aiAnalyzingStream.listen((data) {
      if (currentChat.value?.id == data['chatId']) {
        isAnalyzing.value = data['isAnalyzing'] ?? false;
      }
    });
  }

  Future<void> loadChats({bool refresh = false}) async {
    try {
      if (refresh) {
        currentPage.value = 1;
        hasMoreChats.value = true;
        chats.clear();
      }

      if (!hasMoreChats.value || isLoadingMore.value) return;

      isLoading.value = true;
      hasError.value = false;
      errorMessage.value = '';
      isLoadingMore.value = true;

      final userId = await _userService.getUserId();
      print('[AIChatController] Loading chats for userId: $userId');

      if (userId != null) {
        final result = await _repository.getChatHistory(
          userId: userId,
          page: currentPage.value,
        );

        final newChats = (result['chats'] as List<AIChat>);
        final pagination = result['pagination'] as Map<String, dynamic>;

        print('[AIChatController] Loaded ${newChats.length} chats, total: ${pagination['total']}');

        if (refresh) {
          chats.value = newChats;
        } else {
          chats.addAll(newChats);
        }

        totalPages.value = pagination['pages'];
        hasMoreChats.value = currentPage.value < pagination['pages'];
        currentPage.value++;
      } else {
        print('[AIChatController] userId is null, cannot load chats');
      }
    } catch (e) {
      print('[AIChatController] Error loading chats: $e');
      hasError.value = true;
      errorMessage.value = 'Failed to load chats';
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> refreshChats() async {
    await loadChats(refresh: true);
  }

  Future<void> loadMoreChats() async {
    if (!isLoading.value && hasMoreChats.value) {
      await loadChats();
    }
  }

  Future<void> sendMessage(String message) async {
    if (remainingMessages.value <= 0) {
      Get.snackbar(
        'Daily Limit Reached',
        'You have reached your daily message limit',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    remainingMessages.value--;

    if (isRateLimited.value) {
      final remainingTime =
          rateLimitReset.value - DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (remainingTime > 0) {
        Get.snackbar(
          'Rate Limited',
          'Please wait ${remainingTime} seconds before sending another message',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
        return;
      }
    }

    try {
      final userId = await _userService.getUserId();
      final userName = await _userService.getFirstName();
      final userPhoto = await _userService.getImage();

      if (userId == null || userName == null) {
        throw Exception('User not authenticated');
      }

      // Add user message immediately for better UX
      final userMessage = AIChatMessage(
        role: 'user',
        content: message,
        timestamp: DateTime.now(),
      );
      messages.add(userMessage);

      // Track AI chat message
      _engagementService.trackAIChatMessage(isUserMessage: true);

      isTyping.value = true;

      final location = await _getLocationData();
      final weather = await _getWeatherData();
      final preferredLanguage = await _getPreferredLanguage();

      int retryCount = 0;
      const maxRetries = 3;
      Duration retryDelay = const Duration(seconds: 2);

      while (retryCount < maxRetries) {
        try {
          final response = await _repository.sendMessage(
            userId: userId,
            userName: userName,
            userProfilePhoto: userPhoto ?? '',
            chatId: currentChat.value?.id,
            message: message,
            preferredLanguage: preferredLanguage,
            location: location,
            weather: weather,
          );

          if (response != null) {
            final aiResponse = response['message'] ?? '';
            final context = response['context'];
            final limitInfo = response['limitInfo'];
            final serverChatId = response['chatId'];

            // Update remaining messages from backend response
            if (limitInfo != null && limitInfo['remainingMessages'] != null) {
              remainingMessages.value = limitInfo['remainingMessages'];
            }

            if (aiResponse.isNotEmpty) {
              final aiMessage = AIChatMessage(
                role: 'assistant',
                content: aiResponse,
                timestamp: DateTime.now(),
              );
              messages.add(aiMessage);

              // Update current chat with server-assigned chatId and new context
              if (serverChatId != null) {
                if (currentChat.value != null) {
                  // Update existing chat with server ID and new context
                  _updateCurrentChatWithServerId(
                    serverChatId,
                    userMessage,
                    aiMessage,
                    context,
                  );
                } else {
                  // Create new chat object with server ID
                  await _createChatFromResponse(
                    serverChatId,
                    userMessage,
                    aiMessage,
                    context,
                  );
                }
              } else if (currentChat.value != null && context != null) {
                _updateCurrentChat(userMessage, aiMessage, context);
              }
              break; // Success, exit retry loop
            }
          }
        } catch (e) {
          if (e.toString().contains('429')) {
            final response = (e as DioException).response;
            final retryAfter =
                int.tryParse(response?.headers['retry-after']?.first ?? '30');

            _handleRateLimit({
              'remaining': 0,
              'reset': DateTime.now().millisecondsSinceEpoch ~/ 1000 +
                  (retryAfter ?? 30)
            });

            retryCount++;
            if (retryCount < maxRetries) {
              Get.snackbar(
                'Rate Limited',
                'Retrying in ${retryDelay.inSeconds} seconds...',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange,
                colorText: Colors.white,
                duration: retryDelay,
              );
              await Future.delayed(retryDelay);
              retryDelay *= 2; // Exponential backoff
              continue;
            }
          }
          rethrow;
        }
      }
    } catch (e) {
      messages.removeLast(); // Remove the user message if processing failed
      Get.snackbar(
        'Error',
        'Failed to send message. Please try again later.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isTyping.value = false;
    }
  }

  void _handleRateLimit(Map<String, dynamic> rateLimit) {
    final remaining = rateLimit['remaining'] as int;
    final reset = rateLimit['reset'] as int;

    if (remaining <= 0) {
      isRateLimited.value = true;
      rateLimitReset.value = reset;

      // Start a timer to clear rate limit
      _rateLimitTimer?.cancel();
      _rateLimitTimer = Timer(
          Duration(
              seconds: reset - (DateTime.now().millisecondsSinceEpoch ~/ 1000)),
          () {
        isRateLimited.value = false;
        rateLimitReset.value = 0;
      });
    }
  }

  void _updateCurrentChat(AIChatMessage userMessage, AIChatMessage aiMessage,
      Map<String, dynamic>? context) {
    final updatedChat = currentChat.value!.copyWith(
      messages: [...currentChat.value!.messages, userMessage, aiMessage],
      context: context != null ? AIContext.fromJson(context) : null,
      lastMessageAt: DateTime.now(),
    );
    currentChat.value = updatedChat;

    // Update chat in the list
    final index = chats.indexWhere((chat) => chat.id == updatedChat.id);
    if (index != -1) {
      chats[index] = updatedChat;
    }
  }

  /// Update current chat with server-assigned ID (important for conversation continuity)
  void _updateCurrentChatWithServerId(
    String serverChatId,
    AIChatMessage userMessage,
    AIChatMessage aiMessage,
    Map<String, dynamic>? context,
  ) {
    final oldId = currentChat.value?.id;

    // Generate a proper title from the first user message
    String chatTitle = currentChat.value?.title ?? 'New Chat';
    if (chatTitle == 'New Chat' && userMessage.content.isNotEmpty) {
      chatTitle = userMessage.content.length > 30
          ? '${userMessage.content.substring(0, 30)}...'
          : userMessage.content;
    }

    // Create updated chat with server ID
    final updatedChat = AIChat(
      id: serverChatId,  // Use server-assigned ID
      userId: currentChat.value!.userId,
      userName: currentChat.value!.userName,
      userProfilePhoto: currentChat.value!.userProfilePhoto,
      title: chatTitle,
      messages: [...currentChat.value!.messages, userMessage, aiMessage],
      metadata: currentChat.value!.metadata,
      context: context != null ? AIContext.fromJson(context) : currentChat.value!.context,
      lastMessageAt: DateTime.now(),
      isActive: currentChat.value!.isActive,
      createdAt: currentChat.value!.createdAt,
      updatedAt: DateTime.now(),
    );

    currentChat.value = updatedChat;

    // Always ensure the chat is in the list
    // First, remove any chat with the old temporary ID
    if (oldId != null && oldId != serverChatId) {
      chats.removeWhere((chat) => chat.id == oldId);
    }

    // Then update or add the chat with the server ID
    final index = chats.indexWhere((chat) => chat.id == serverChatId);
    if (index != -1) {
      chats[index] = updatedChat;
    } else {
      chats.insert(0, updatedChat);
    }

    // Force refresh to ensure UI updates
    chats.refresh();

    print('[AIChatController] Updated chat ${serverChatId}, total chats: ${chats.length}');
  }

  /// Create a new chat from server response when no current chat exists
  Future<void> _createChatFromResponse(
    String serverChatId,
    AIChatMessage userMessage,
    AIChatMessage aiMessage,
    Map<String, dynamic>? context,
  ) async {
    final userId = await _userService.getUserId();
    final userName = await _userService.getFirstName();
    final userPhoto = await _userService.getImage();
    final preferredLanguage = await _getPreferredLanguage();

    final newChat = AIChat(
      id: serverChatId,
      userId: userId ?? '',
      userName: userName ?? '',
      userProfilePhoto: userPhoto ?? '',
      title: userMessage.content.length > 30
          ? '${userMessage.content.substring(0, 30)}...'
          : userMessage.content,
      messages: [userMessage, aiMessage],
      metadata: AIMetadata(
        preferredLanguage: preferredLanguage,
        location: null,
        weather: null,
      ),
      context: context != null ? AIContext.fromJson(context) : AIContext(
        currentTopic: '',
        lastContext: '',
        identifiedIssues: [],
        suggestedSolutions: [],
      ),
      lastMessageAt: DateTime.now(),
      isActive: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    currentChat.value = newChat;

    // Check if chat already exists (edge case)
    final existingIndex = chats.indexWhere((chat) => chat.id == serverChatId);
    if (existingIndex == -1) {
      chats.insert(0, newChat);
    } else {
      chats[existingIndex] = newChat;
    }

    // Force refresh to ensure UI updates
    chats.refresh();

    print('[AIChatController] Created new chat ${serverChatId}, total chats: ${chats.length}');
  }

  Future<void> loadChat(String chatId) async {
    try {
      final userId = await _userService.getUserId();
      if (userId == null) return;

      final chat = await _repository.getChatById(userId, chatId);
      currentChat.value = chat;
      messages.value = chat.messages;

      // Join the socket room for this chat
      await _socketService.forceConnect();
    } catch (e) {}
  }

  Future<String> _getPreferredLanguage() async {
    try {
      final languageService = await LanguageService.getInstance();
      return languageService.getLanguageCode();
    } catch (e) {
      return 'en';
    }
  }

  Future<Map<String, dynamic>> _getLocationData() async {
    // TODO: Implement actual location service
    return {'lat': 0.0, 'lon': 0.0};
  }

  Future<Map<String, dynamic>> _getWeatherData() async {
    // TODO: Implement actual weather service
    return {'temperature': 25.0, 'humidity': 60.0};
  }

  Future<void> analyzeCropImage(File image) async {
    // Set the image to selected images and process it
    selectedImages.value = [image];
    await processSelectedImages();
  }

  Future<void> updateTitle(String title) async {
    try {
      final userId = await _userService.getUserId();
      if (userId == null || currentChat.value == null) return;

      final updatedChat = await _repository.updateChatTitle(
        currentChat.value!.id,
        userId,
        title,
      );

      final index = chats.indexWhere((chat) => chat.id == updatedChat.id);
      if (index != -1) {
        chats[index] = updatedChat;
        currentChat.value = updatedChat;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      final userId = await _userService.getUserId();
      if (userId == null) return;

      await _repository.deleteChat(chatId, userId);
      chats.removeWhere((chat) => chat.id == chatId);
      if (currentChat.value?.id == chatId) {
        currentChat.value = null;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> ensureSocketConnection() async {
    if (!_socketService.isSocketConnected()) {
      final connected = await _socketService.forceConnect();
      if (!connected) {
        Get.snackbar(
          'Warning',
          'Using fallback connection method',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }
    }
  }

  Future<void> getMessageLimitInfo() async {
    try {
      final userId = await _userService.getUserId();
      if (userId == null) return;

      // Get today's date (reset at midnight)
      final today = DateTime.now();
      today.subtract(Duration(
          hours: today.hour, minutes: today.minute, seconds: today.second));

      // Find the most recent chat with message count
      var chatCount = 0;
      for (final chat in chats) {
        if (chat.lastMessageAt.isAfter(today)) {
          chatCount += chat.messages.where((msg) => msg.role == 'user').length;
        }
      }

      // Update remaining messages
      remainingMessages.value = totalDailyLimit.value - chatCount;
      if (remainingMessages.value < 0) remainingMessages.value = 0;

      // Set limit reset time to midnight tonight
      final tomorrow = DateTime(today.year, today.month, today.day + 1);
      limitResetTime.value = tomorrow;
    } catch (e) {}
  }

  Future<void> createNewChat() async {
    try {
      final userId = await _userService.getUserId();
      final userName = await _userService.getFirstName();

      if (userId == null || userName == null) return;

      // Track AI chat start
      _engagementService.trackAIChatStart();

      // Create a new empty chat (client-side only until first message is sent)
      currentChat.value = AIChat(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        userName: userName,
        userProfilePhoto: await _userService.getImage() ?? '',
        title: 'New Chat',
        messages: [],
        metadata: AIMetadata(
          preferredLanguage: await _getPreferredLanguage(),
          location: null,
          weather: null,
        ),
        context: AIContext(
          currentTopic: '',
          lastContext: '',
          identifiedIssues: [],
          suggestedSolutions: [],
        ),
        lastMessageAt: DateTime.now(),
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Clear messages for the new chat
      messages.clear();

      // Note: Don't add to chats list here - the chat will be added
      // when the first message is sent and we get a server-assigned ID.
      // This prevents empty chats from cluttering the history.

      print('[AIChatController] Created new chat (pending first message)');
    } catch (e) {
      print('[AIChatController] Error creating new chat: $e');
      Get.snackbar(
        'Error',
        'Failed to create new chat',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  // Method to pick multiple images from gallery
  Future<void> pickMultipleImages({bool fromCamera = false}) async {
    final ImagePicker picker = ImagePicker();
    try {
      if (fromCamera) {
        // Camera - pick a single image
        final XFile? image = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          maxWidth: 1200,
          maxHeight: 1200,
        );

        if (image != null) {
          // Validate the image file
          final file = File(image.path);
          if (!file.existsSync()) {
            throw Exception('Image file does not exist');
          }

          final fileSize = await file.length();
          if (fileSize == 0) {
            throw Exception('Empty image file');
          }

          if (fileSize > 8 * 1024 * 1024) {
            // 8MB limit
            throw Exception('Image file too large (max 8MB)');
          }

          selectedImages.value = [file];
        }
      } else {
        // Gallery - pick multiple images
        final pickedImages = await picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1200,
          maxHeight: 1200,
        );

        if (pickedImages.isNotEmpty) {
          // Limit the number of images if needed
          final imagesToProcess = pickedImages.length > maxImageCount.value
              ? pickedImages.sublist(0, maxImageCount.value)
              : pickedImages;

          // Convert XFile to File, validate, and add to selected images
          final validatedFiles = <File>[];

          for (var xFile in imagesToProcess) {
            final file = File(xFile.path);

            // Basic validation
            if (!file.existsSync()) {
              print('Warning: Image file does not exist: ${file.path}');
              continue;
            }

            final fileSize = await file.length();
            if (fileSize == 0) {
              print('Warning: Empty image file: ${file.path}');
              continue;
            }

            if (fileSize > 8 * 1024 * 1024) {
              // 8MB limit
              print(
                  'Warning: Image file too large: ${file.path} (${fileSize / 1024 / 1024} MB)');
              continue;
            }

            validatedFiles.add(file);
          }

          if (validatedFiles.isEmpty) {
            throw Exception('No valid images selected');
          }

          selectedImages.value = validatedFiles;
        }
      }
    } catch (e) {
      print('Error picking images: $e');
      Get.snackbar(
        'Image Selection Error',
        e.toString().contains('No valid images')
            ? 'No valid images were found. Please try again with different images.'
            : 'Failed to process images: ${e.toString().replaceAll('Exception: ', '')}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red[100],
        colorText: Colors.red[900],
        duration: const Duration(seconds: 5),
      );
    }
  }

  // Process selected images (single or multiple)
  Future<void> processSelectedImages([String? text]) async {
    if (selectedImages.isEmpty) return;

    // Prevent double-processing
    if (isAnalyzing.value) {
      print('[AIChatController] Already analyzing, ignoring duplicate call');
      return;
    }

    isAnalyzing.value = true;
    final messageString = text ?? '';
    hasNetworkError.value = false; // Reset error state

    try {
      if (selectedImages.length == 1) {
        await _processSingleImage(selectedImages.first, messageString);
      } else {
        // Ensure we have enough daily message limit
        if (remainingMessages.value < selectedImages.length) {
          Get.snackbar(
            'Daily Limit Reached',
            'You don\'t have enough remaining messages for today. Each image counts as one message.',
            backgroundColor: Colors.orange[100],
            colorText: Colors.orange[900],
            duration: const Duration(seconds: 5),
          );
          isAnalyzing.value = false;
          return;
        }

        // Get user information
        final userId = await _userService.getUserId();
        final userName = await _userService.getFirstName();
        final userPhoto = await _userService.getImage();

        if (userId == null || userName == null) {
          throw Exception('User not authenticated');
        }

        // Upload all images to S3 first for display in chat
        _uploadedImageUrls.clear();
        for (final image in selectedImages) {
          final uploadedUrl = await _uploadImageToS3(image);
          if (uploadedUrl != null) {
            _uploadedImageUrls.add(uploadedUrl);
          }
        }

        // Get location and weather data
        final location = await _getLocationData();
        final weather = await _getWeatherData();
        final preferredLanguage = await _getPreferredLanguage();

        final response = await _repository.analyzeMultipleImages(
          userId: userId,
          userName: userName,
          userProfilePhoto: userPhoto ?? '',
          chatId: currentChat.value?.id,
          images: selectedImages,
          message: messageString,
          preferredLanguage: preferredLanguage,
          location: Location.fromJson(location),
          weather: Weather.fromJson(weather),
        );

        // Process successful response
        await _handleSuccessfulImageResponse(response);
      }
    } catch (error) {
      // Don't clear selected images on error, to allow for retry
      if (error is ConnectionResetException ||
          error is ServiceUnavailableException ||
          error is RequestTimeoutException) {
        // For these specific errors, set the network error flag
        hasNetworkError.value = true;
        print('Network error during image processing: $error');
        // Propagate to UI for retry capability
        throw error;
      } else if (error.toString().contains('image')) {
        // Handle image-specific errors
        Get.snackbar(
          'Image Processing Error',
          error.toString().replaceAll('Exception: ', ''),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange[100],
          colorText: Colors.orange[900],
          duration: const Duration(seconds: 5),
        );
        // Clear images for image-specific errors
        selectedImages.clear();
      } else {
        // For other errors, clear the images
        selectedImages.clear();
        rethrow;
      }
    } finally {
      isAnalyzing.value = false;
    }
  }

  // Temporary storage for uploaded image URLs during processing
  final _uploadedImageUrls = <String>[].obs;
  final EngagementService _engagementService = EngagementService();

  // Upload image to S3 and return the URL
  Future<String?> _uploadImageToS3(File image) async {
    try {
      final presignedUrlController = Get.find<PresignedUrlController>();
      final userId = await _userService.getUserId();

      final imageUrl = await presignedUrlController.uploadImage(
        imageFile: image,
        contentType: 'chat_image',
        userId: userId,
        isVideo: false,
      );

      return imageUrl;
    } catch (e) {
      print('Error uploading image to S3: $e');
      return null;
    }
  }

  // Process a single image with proper error handling
  Future<void> _processSingleImage(File image, String messageString) async {
    try {
      // Get user information
      final userId = await _userService.getUserId();
      final userName = await _userService.getFirstName();
      final userPhoto = await _userService.getImage();

      if (userId == null || userName == null) {
        throw Exception('User not authenticated');
      }

      // Upload image to S3 first for display in chat
      final uploadedUrl = await _uploadImageToS3(image);
      if (uploadedUrl != null) {
        _uploadedImageUrls.clear();
        _uploadedImageUrls.add(uploadedUrl);
      }

      // Get location and weather data
      final location = await _getLocationData();
      final weather = await _getWeatherData();
      final preferredLanguage = await _getPreferredLanguage();

      final response = await _repository.analyzeCropImage(
        userId: userId,
        userName: userName,
        userProfilePhoto: userPhoto ?? '',
        chatId: currentChat.value?.id,
        image: image,
        preferredLanguage: preferredLanguage,
        location: Location.fromJson(location),
        weather: Weather.fromJson(weather),
      );

      // Process successful response with uploaded URLs
      await _handleSuccessfulImageResponse(response);
    } catch (error) {
      _uploadedImageUrls.clear();
      if (error is ConnectionResetException ||
          error is ServiceUnavailableException) {
        // For these specific errors, propagate to UI for better handling
        throw error;
      }

      // For other errors, try to provide a helpful message
      rethrow;
    }
  }

  // Helper method to handle successful image analysis response
  Future<void> _handleSuccessfulImageResponse(Map<String, dynamic> response) async {
    // Update chat if response contains data
    if (response['analysis'] != null) {
      final aiResponse = response['analysis'];
      final context = response['context'];
      final limitInfo = response['limitInfo'];
      final serverChatId = response['chatId'];

      // Get the first uploaded image URL for display (or use placeholder)
      final String? displayImageUrl =
          _uploadedImageUrls.isNotEmpty ? _uploadedImageUrls.first : null;

      // Create user message with image URL for display
      final imageMessage = AIChatMessage(
        role: 'user',
        content: selectedImages.length == 1
            ? 'Analyzing crop image...'
            : 'Uploaded ${selectedImages.length} images for analysis',
        timestamp: DateTime.now(),
        imageUrl: displayImageUrl,
        localImagePaths: _uploadedImageUrls.isNotEmpty
            ? List<String>.from(_uploadedImageUrls)
            : null,
      );

      final aiMessage = AIChatMessage(
        role: 'assistant',
        content: aiResponse,
        timestamp: DateTime.now(),
      );

      messages.addAll([imageMessage, aiMessage]);

      // Update chat with server-assigned chatId and new context
      if (serverChatId != null) {
        if (currentChat.value != null) {
          _updateCurrentChatWithServerId(
            serverChatId,
            imageMessage,
            aiMessage,
            context,
          );
        } else {
          await _createChatFromResponse(
            serverChatId,
            imageMessage,
            aiMessage,
            context,
          );
        }
      } else if (currentChat.value != null && context != null) {
        _updateCurrentChat(imageMessage, aiMessage, context);
      }

      // Handle rate limit if provided
      if (limitInfo != null) {
        // Update remaining messages if needed
        if (limitInfo['remainingMessages'] != null) {
          remainingMessages.value = limitInfo['remainingMessages'];
        }
      }
    }

    // Clear selected images and uploaded URLs after successful processing
    selectedImages.clear();
    _uploadedImageUrls.clear();
  }

  // Retry mechanism for image processing
  Future<void> retryLastFailedRequest() async {
    if (selectedImages.isEmpty) return;

    isAnalyzing.value = true;
    hasNetworkError.value = false; // Reset network error state when retrying

    try {
      if (selectedImages.length == 1) {
        await _processSingleImage(selectedImages.first, '');
      } else {
        await processSelectedImages();
      }
    } catch (error) {
      isAnalyzing.value = false;
      hasNetworkError.value = true; // Set error state if the retry also fails

      // Show appropriate error
      if (error is ServiceUnavailableException) {
        Get.snackbar(
          'Service Unavailable',
          'Please try again in a few minutes',
          backgroundColor: Colors.red[100],
          colorText: Colors.red[900],
          icon: const Icon(Icons.cloud_off, color: Colors.red),
        );
      } else {
        showNetworkErrorSnackbar(error);
      }
    }
  }

  @override
  void onClose() {
    _aiMessageSubscription?.cancel();
    _aiTypingSubscription?.cancel();
    _aiAnalyzingSubscription?.cancel();
    _rateLimitTimer?.cancel();
    super.onClose();
  }
}
