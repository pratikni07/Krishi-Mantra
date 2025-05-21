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
import '../widgets/error_widgets.dart';

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
      if (userId != null) {
        final result = await _repository.getChatHistory(
          userId: userId,
          page: currentPage.value,
        );

        final newChats = (result['chats'] as List<AIChat>);
        final pagination = result['pagination'] as Map<String, dynamic>;

        if (refresh) {
          chats.value = newChats;
        } else {
          chats.addAll(newChats);
        }

        totalPages.value = pagination['pages'];
        hasMoreChats.value = currentPage.value < pagination['pages'];
        currentPage.value++;
      }
    } catch (e) {
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
            final rateLimit = response['rateLimit'];

            if (rateLimit != null) {
              _handleRateLimit(rateLimit);
            }

            if (aiResponse.isNotEmpty) {
              final aiMessage = AIChatMessage(
                role: 'assistant',
                content: aiResponse,
                timestamp: DateTime.now(),
              );
              messages.add(aiMessage);

              // Update current chat with new context
              if (currentChat.value != null && context != null) {
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
      Map<String, dynamic> context) {
    final updatedChat = currentChat.value!.copyWith(
      messages: [...currentChat.value!.messages, userMessage, aiMessage],
      context: AIContext.fromJson(context),
      lastMessageAt: DateTime.now(),
    );
    currentChat.value = updatedChat;

    // Update chat in the list
    final index = chats.indexWhere((chat) => chat.id == updatedChat.id);
    if (index != -1) {
      chats[index] = updatedChat;
    }
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

      // Create a new empty chat
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

      // Clear messages
      messages.clear();

      // Add new chat to the list
      chats.insert(0, currentChat.value!);
    } catch (e) {
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
        _handleSuccessfulImageResponse(response);
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

      // Process successful response
      _handleSuccessfulImageResponse(response);
    } catch (error) {
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
  void _handleSuccessfulImageResponse(Map<String, dynamic> response) {
    // Update chat if response contains data
    if (response['analysis'] != null) {
      final aiResponse = response['analysis'];
      final context = response['context'];
      final limitInfo = response['limitInfo'];

      // Add the real message with image information
      final imageMessage = AIChatMessage(
        role: 'user',
        content:
            'Uploaded ${selectedImages.length} ${selectedImages.length == 1 ? 'image' : 'images'} for analysis',
        timestamp: DateTime.now(),
        imageUrl: 'images_uploaded', // Marker to show this was an image message
      );

      final aiMessage = AIChatMessage(
        role: 'assistant',
        content: aiResponse,
        timestamp: DateTime.now(),
      );

      messages.addAll([imageMessage, aiMessage]);

      // Update chat with new context
      if (currentChat.value != null && context != null) {
        final updatedChat = currentChat.value!.copyWith(
          messages: [...currentChat.value!.messages, imageMessage, aiMessage],
          context: AIContext.fromJson(context),
          lastMessageAt: DateTime.now(),
        );

        currentChat.value = updatedChat;

        // Update chat in the list
        final index = chats.indexWhere((chat) => chat.id == updatedChat.id);
        if (index != -1) {
          chats[index] = updatedChat;
        }
      }

      // Handle rate limit if provided
      if (limitInfo != null) {
        // Update remaining messages if needed
        if (limitInfo['remainingMessages'] != null) {
          remainingMessages.value = limitInfo['remainingMessages'];
        }
      }
    }

    // Clear selected images after successful processing
    selectedImages.clear();
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
