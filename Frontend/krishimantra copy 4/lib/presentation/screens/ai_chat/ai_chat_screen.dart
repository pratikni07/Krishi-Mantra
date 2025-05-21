// lib/presentation/screens/ai_chat/ai_chat_screen.dart
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as _dateFormat;

import '../../../core/constants/colors.dart';
import '../../controllers/ai_chat_controller.dart';
import '../../widgets/chat_message_bubble.dart';
import '../../../data/models/ai_chat.dart';
import '../../../data/models/ai_chat_message.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/error_widgets.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({Key? key}) : super(key: key);

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final controller = Get.find<AIChatController>();
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  final _dateFormat = DateFormat('MMM dd, yyyy');
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Control whether the sidebar is showing on mobile
  bool showSidebar = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
    // Load message limit info
    controller.getMessageLimitInfo();
  }

  @override
  void dispose() {
    scrollController.removeListener(_onScroll);
    scrollController.dispose();
    messageController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      controller.loadMoreChats();
    }
  }

  // Scroll to bottom of chat
  void _scrollToBottom() {
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 800;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title:
            Obx(() => Text(controller.currentChat.value?.title ?? 'New Chat')),
        backgroundColor: AppColors.green,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        actions: [
          // Show sidebar button on smaller screens
          if (!isLargeScreen)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                setState(() {
                  showSidebar = !showSidebar;
                });
              },
            ),
          // Show message limit indicator
          Obx(() => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Center(
                  child: Text(
                    'Messages: ${controller.remainingMessages}/5',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: controller.remainingMessages.value < 2
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              )),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => controller.createNewChat(),
            tooltip: 'New Chat',
          ),
        ],
      ),
      drawer: !isLargeScreen ? _buildSidebar(context) : null,
      body: Row(
        children: [
          // Sidebar for chat history on large screens
          if (isLargeScreen) _buildSidebar(context),

          // Main chat area
          Expanded(
            child: Column(
              children: [
                // Message display area
                Expanded(
                  child: _buildChatArea(),
                ),

                // AI is typing indicator
                Obx(() {
                  if (controller.isTyping.value) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.centerLeft,
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.green),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('AI is thinking...'),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                // Input area
                _buildInputBox(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 280,
      height: double.infinity,
      color: Colors.grey[100],
      child: Column(
        children: [
          // New chat button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => controller.createNewChat(),
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),

          // Message limit indicator
          Obx(() => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: controller.remainingMessages.value < 2
                      // ignore: deprecated_member_use
                      ? Colors.orange.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: controller.remainingMessages.value < 2
                          ? Colors.orange
                          : AppColors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Daily messages: ${controller.remainingMessages.value}/5 remaining',
                        style: TextStyle(
                          fontSize: 13,
                          color: controller.remainingMessages.value < 2
                              ? Colors.orange[800]
                              : Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              )),

          // Today heading
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Today',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ),

          // Chat history list
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.chats.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: controller.chats.length,
                itemBuilder: (context, index) {
                  final chat = controller.chats[index];
                  final isSelected =
                      controller.currentChat.value?.id == chat.id;

                  return InkWell(
                    onTap: () => controller.loadChat(chat.id),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.green.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: AppColors.green.withOpacity(0.5))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 16,
                            color:
                                isSelected ? AppColors.green : Colors.grey[600],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  chat.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? AppColors.green
                                        : Colors.black87,
                                  ),
                                ),
                                if (chat.messages.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _getLastMessage(chat),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            color: Colors.grey[600],
                            onPressed: () =>
                                _showDeleteConfirmation(context, chat.id),
                            splashRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  String _getLastMessage(AIChat chat) {
    if (chat.messages.isEmpty) return '';
    final lastMessage = chat.messages.last;
    return lastMessage.content.replaceAll('\n', ' ');
  }

  Widget _buildChatArea() {
    return Obx(() {
      if (controller.isLoading.value && controller.messages.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.messages.isEmpty) {
        return _buildEmptyState();
      }

      return ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: controller.messages.length,
        itemBuilder: (context, index) {
          final message = controller.messages[index];
          return ChatMessageBubble(
            key: ValueKey(message.timestamp.toString()),
            message: message.content,
            isUser: message.role == 'user',
            timestamp: message.timestamp,
            // imageUrl: message.imageUrl,
          );
        },
      );
    });
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.agriculture,
                  size: 40,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                "Farmer's AI Assistant",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  "Ask farming questions, get crop advice, or upload images of plants for disease analysis.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildSuggestionChip("What crops grow best in clay soil?"),
                  _buildSuggestionChip("How to prevent tomato blight?"),
                  _buildSuggestionChip("Best practices for organic farming"),
                  _buildSuggestionChip("When to harvest wheat?"),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return InkWell(
      onTap: () {
        messageController.text = text;
        setState(() {});
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.green),
          color: Colors.white,
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBox() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected images preview
          Obx(() {
            if (controller.selectedImages.isEmpty)
              return const SizedBox.shrink();

            return Container(
              height: 90,
              margin: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${controller.selectedImages.length} ${controller.selectedImages.length == 1 ? 'image' : 'images'} selected',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => controller.selectedImages.clear(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: controller.selectedImages.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 70,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  controller.selectedImages[index],
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () {
                                      final updatedList = [
                                        ...controller.selectedImages
                                      ];
                                      updatedList.removeAt(index);
                                      controller.selectedImages.value =
                                          updatedList;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }),

          // Error widget for network issues during upload
          Obx(() {
            if (!controller.hasNetworkError.value) {
              return const SizedBox.shrink();
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Server Connection Error',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The message service is currently unavailable. This might be due to server maintenance or high traffic.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => controller.selectedImages.clear(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.all(4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => controller.retryLastFailedRequest(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.all(4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppColors.green.withOpacity(0.1),
                        ),
                        child: Text(
                          'Retry',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          // Input area with message field and buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Image/Camera picker button
              InkWell(
                onTap: () {
                  _showImageSourceOptions(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade100,
                  ),
                  child: const Icon(Icons.photo_library,
                      color: Colors.grey, size: 22),
                ),
              ),
              const SizedBox(width: 10),

              // Message text field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: messageController,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (_) {
                      // Force UI update for send button
                      setState(() {});
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Send button
              InkWell(
                onTap: controller.isAnalyzing.value
                    ? null
                    : () async {
                        // Handle image upload + optional text
                        if (controller.selectedImages.isNotEmpty) {
                          try {
                            await controller.processSelectedImages(
                                messageController.text.trim().isNotEmpty
                                    ? messageController.text.trim()
                                    : null);
                            messageController.clear();
                          } catch (e) {
                            _handleImageProcessingError(e);
                          }
                          return;
                        }

                        // Handle text-only message
                        if (messageController.text.trim().isNotEmpty) {
                          try {
                            await controller
                                .sendMessage(messageController.text.trim());
                          } catch (e) {
                            // Handle any message sending errors
                            Get.snackbar(
                              'Error',
                              'Failed to send message. Please try again.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor: Colors.red,
                              colorText: Colors.white,
                            );
                          }
                        }

                        // Clear the text field after sending
                        messageController.clear();
                      },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: controller.isAnalyzing.value
                        ? Colors.grey
                        : AppColors.green,
                  ),
                  child: controller.isAnalyzing.value
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(
                          controller.selectedImages.isNotEmpty ||
                                  messageController.text.isNotEmpty
                              ? Icons.send
                              : Icons.mic,
                          color: Colors.white,
                          size: 22,
                        ),
                ),
              ),
            ],
          ),

          // Rate limit warning
          Obx(() {
            if (controller.isRateLimited.value) {
              final remaining = controller.rateLimitReset.value -
                  (DateTime.now().millisecondsSinceEpoch ~/ 1000);
              if (remaining > 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Rate limited. Try again in ${remaining}s',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                );
              }
            }

            if (controller.remainingMessages.value <= 0) {
              return const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Daily message limit reached. Try again tomorrow.',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              );
            }

            return const SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  // Show image source options - camera or gallery
  void _showImageSourceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Camera Option
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      controller.pickMultipleImages(fromCamera: true);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            color: AppColors.green,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Camera',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Gallery Option
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      controller.pickMultipleImages(fromCamera: false);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.photo_library,
                            color: AppColors.green,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gallery',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'You can select up to ${controller.maxImageCount.value} images at once',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String chatId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat'),
        content: const Text('Are you sure you want to delete this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              controller.deleteChat(chatId);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chat History'),
        content: SizedBox(
          width: double.maxFinite,
          child: Obx(() {
            if (controller.isLoading.value) {
              return const Center(child: CircularProgressIndicator());
            }

            final groupedChats = <DateTime, List<AIChat>>{};
            for (var chat in controller.chats) {
              final date = DateTime(
                chat.lastMessageAt.year,
                chat.lastMessageAt.month,
                chat.lastMessageAt.day,
              );
              if (!groupedChats.containsKey(date)) {
                groupedChats[date] = [];
              }
              groupedChats[date]!.add(chat);
            }

            final sortedDates = groupedChats.keys.toList()
              ..sort((a, b) => b.compareTo(a));

            return ListView.builder(
              shrinkWrap: true,
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                final chats = groupedChats[date]!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        _dateFormat.format(date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...chats.map((chat) => ListTile(
                          title: Text(chat.title),
                          subtitle: Text(
                            chat.messages.isNotEmpty
                                ? chat.messages.last.content
                                : '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            DateFormat('HH:mm').format(chat.lastMessageAt),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            controller.loadChat(chat.id);
                          },
                        )),
                  ],
                );
              },
            );
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // Add a method to handle displaying error messages with retry option
  void _showErrorWithRetry(String title, String message, VoidCallback onRetry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.green),
            child: const Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Widget to display when an image upload error occurs
  Widget _buildNetworkErrorWidget({required VoidCallback onRetry}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Network Error',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            'Failed to connect to server. Please check your internet connection and try again.',
            style: TextStyle(fontSize: 14),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  controller.selectedImages.clear();
                  setState(() {});
                },
                child: Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              SizedBox(width: 8),
              ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Update the _handleImageProcessingError method
  void _handleImageProcessingError(dynamic error) {
    setState(() {
      controller.isAnalyzing.value = false;
      controller.selectedImages.clear();
    });

    // Use our new error handling for better user experience
    if (error is ConnectionResetException ||
        error is ServiceUnavailableException ||
        error is RequestTimeoutException) {
      // Show a more detailed error widget for network issues
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(error is ServiceUnavailableException
              ? "Service Unavailable"
              : "Connection Issue"),
          content: SizedBox(
            height: 200,
            child: context.getErrorWidget(error, () {
              Navigator.of(context).pop();
            }),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("CLOSE"),
            ),
          ],
        ),
      );
    } else {
      // For other errors, use a snackbar
      showNetworkErrorSnackbar(error);
    }
  }

  // Update the _sendMessage method to better handle connection errors
  Future<void> _sendMessage() async {
    if (controller.isAnalyzing.value) return;

    final message = messageController.text.trim();

    if (message.isEmpty && controller.selectedImages.isEmpty) {
      return;
    }

    setState(() {
      controller.isAnalyzing.value = true;
    });

    try {
      // ... existing code for message sending ...
    } catch (error) {
      // Handle general errors for text messages
      _handleImageProcessingError(error);
    }
  }

  // Update the _analyzeImage method to better handle connection errors
  Future<void> _analyzeImage(bool isMultiple) async {
    try {
      // ... existing code for image analysis ...
    } catch (error) {
      _handleImageProcessingError(error);
    }
  }
}
