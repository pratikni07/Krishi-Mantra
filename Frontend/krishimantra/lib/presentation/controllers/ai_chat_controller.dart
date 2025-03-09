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

    try {
      isAnalyzing.value = true;

      final userId = await _userService.getUserId();
      final userName = await _userService.getFirstName();
      final userPhoto = await _userService.getImage();

      if (userId == null || userName == null) return;

      final bytes = await image.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Get environmental data
      final location = await _getLocationData();
      final weather = await _getWeatherData();
      final preferredLanguage = await _getPreferredLanguage();

      final analysisData = {
        'imageBuffer': base64Image,
        'preferredLanguage': preferredLanguage,
        'location': location,
        'weather': weather,
      };

      if (currentChat.value?.id != null) {
        final success = await _socketService.analyzeImage(
          currentChat.value!.id,
          analysisData,
        );

        if (!success) {
          // Fallback to HTTP request
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

          if (response['analysis'] != null) {
            // Update chat with new context and messages
            await loadChat(currentChat.value!.id);
          }
        }
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to analyze image: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isAnalyzing.value = false;
    }
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

  @override
  void onClose() {
    _aiMessageSubscription?.cancel();
    _aiTypingSubscription?.cancel();
    _aiAnalyzingSubscription?.cancel();
    _rateLimitTimer?.cancel();
    super.onClose();
  }
}
