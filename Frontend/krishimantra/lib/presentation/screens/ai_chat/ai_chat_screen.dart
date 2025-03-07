// lib/presentation/screens/ai_chat/ai_chat_screen.dart
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
        leading: isLargeScreen
            ? null
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () {
                  setState(() {
                    showSidebar = !showSidebar;
                  });
                },
              ),
        actions: [
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
                      child: Row(
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
                          const SizedBox(width: 8),
                          const Text('AI is thinking...'),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),

                // Input area
                _buildInputArea(),
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
            imageUrl: message.imageUrl,
          );
        },
      );
    });
  }

  Widget _buildEmptyState() {
    return Center(
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
            child: Icon(
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
        ],
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
          style: TextStyle(
            color: AppColors.green,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Obx(() => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, -1),
              ),
            ],
            border: Border(
              top: BorderSide(color: Colors.grey[200]!),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.camera_alt),
                onPressed: controller.remainingMessages.value > 0
                    ? _pickImage
                    : () => _showLimitReachedDialog(),
                color: controller.remainingMessages.value > 0
                    ? AppColors.green
                    : Colors.grey,
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: controller.remainingMessages.value > 0
                          ? 'Message Farmer AI...'
                          : 'Daily message limit reached',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    enabled: controller.remainingMessages.value > 0,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: messageController.text.trim().isNotEmpty &&
                        controller.remainingMessages.value > 0
                    ? AppColors.green
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(50),
                child: InkWell(
                  onTap: messageController.text.trim().isNotEmpty &&
                          controller.remainingMessages.value > 0
                      ? _sendMessage
                      : null,
                  borderRadius: BorderRadius.circular(50),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.send,
                      color: messageController.text.trim().isNotEmpty &&
                              controller.remainingMessages.value > 0
                          ? Colors.white
                          : Colors.grey[500],
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (image != null) {
      await controller.analyzeCropImage(File(image.path));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    }
  }

  void _sendMessage() async {
    final message = messageController.text.trim();
    if (message.isEmpty) return;

    messageController.clear(); // Clear immediately for better UX

    try {
      await controller.sendMessage(message);

      // Scroll to bottom after sending message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to send message',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Daily Message Limit Reached'),
        content: const Text(
          'You have used all your free daily messages. Please wait until tomorrow for your limit to reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
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
}
