import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:krishi_doctor/Pages/models/MessageModel.dart';
import 'package:krishi_doctor/Pages/widget/ChatAppBar.dart';
import 'package:krishi_doctor/Pages/widget/MessageBubble.dart';
import 'package:krishi_doctor/Pages/widget/MessageInputWidget.dart';

class ChatScreen extends StatefulWidget {
  final String userName;
  final String userProfilePic;

  const ChatScreen({
    Key? key, 
    required this.userName, 
    required this.userProfilePic
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Message list with demo data
  List<MessageModel> messages = [
    MessageModel(
      text: "Hello! I'm interested in selling my crops.",
      isSentByMe: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    MessageModel(
      text: "What type of crops do you have?",
      isSentByMe: true,
      videoUrl: "https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4",
      timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
    ),
    MessageModel(
      text: "I have wheat and corn this season.",
      isSentByMe: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      imageUrl: "https://media.istockphoto.com/id/965148388/photo/green-ripening-soybean-field-agricultural-landscape.jpg?s=612x612&w=0&k=20&c=cEVP3uj34-5obt-Jf_WI3O9qfP6tVrFaQIv1rBvvpzc=",
    ),
  ];

  // State for additional input options
  bool _showPollOptions = false;

  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // Poll option controllers
  List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  // Method to send message
  void _sendMessage() {
    if (_messageController.text.isNotEmpty) {
      setState(() {
        messages.add(MessageModel(
          text: _messageController.text,
          isSentByMe: true,
          timestamp: DateTime.now(),
        ));
        _messageController.clear();
      });
    }
  }

  // Method to pick image
  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        messages.add(MessageModel(
          text: '',
          isSentByMe: true,
          timestamp: DateTime.now(),
          imageUrl: pickedFile.path,
        ));
      });
    }
  }

  // Method to pick file
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        messages.add(MessageModel(
          text: 'File: ${result.files.single.name}',
          isSentByMe: true,
          timestamp: DateTime.now(),
          fileUrl: result.files.single.path,
        ));
      });
    }
  }

  // Method to show bottom sheet for additional options
  void _showAdditionalOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionButton(
                    icon: Icons.image,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _buildOptionButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildOptionButton(
                    icon: Icons.insert_drive_file,
                    label: 'File',
                    onTap: () {
                      Navigator.pop(context);
                      _pickFile();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildOptionButton(
                icon: Icons.poll,
                label: 'Create Poll',
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _showPollOptions = true;
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to build option buttons
  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onTap,
          style: IconButton.styleFrom(
            backgroundColor: Colors.green.shade100,
            foregroundColor: Colors.green.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  // Validate poll creation
  bool _validatePoll(TextEditingController questionController, 
                     List<TextEditingController> optionControllers) {
    // Check if question is empty
    if (questionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a poll question'))
      );
      return false;
    }

    // Check if at least two options are provided
    final validOptions = optionControllers
        .where((controller) => controller.text.trim().isNotEmpty)
        .toList();

    if (validOptions.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least two poll options'))
      );
      return false;
    }

    return true;
  }

  // Create poll method
  void _createPoll(TextEditingController questionController, 
                   List<TextEditingController> optionControllers) {
    // Collect valid poll options
    final pollOptions = optionControllers
        .map((controller) => controller.text.trim())
        .where((option) => option.isNotEmpty)
        .toList();

    // Create poll message
    final pollMessage = MessageModel(
      text: questionController.text,
      isSentByMe: true,
      timestamp: DateTime.now(),
      isPoll: true,
      pollOptions: pollOptions,
      pollVotes: List.filled(pollOptions.length, 0),
    );

    // Add poll to messages
    setState(() {
      messages.add(pollMessage);
      _showPollOptions = false;
      
      // Reset poll option controllers
      _pollOptionControllers = [
        TextEditingController(),
        TextEditingController(),
      ];
    });
  }

  // Poll creation widget
  Widget _buildPollCreationWidget() {
    final TextEditingController questionController = TextEditingController();

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              TextField(
                controller: questionController,
                decoration: InputDecoration(
                  hintText: 'Enter poll question',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              
              // Dynamic poll options
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pollOptionControllers.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pollOptionControllers[index],
                            decoration: InputDecoration(
                              hintText: 'Option ${index + 1}',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        // Add option button for the last field
                        if (index == _pollOptionControllers.length - 1 && 
                            _pollOptionControllers.length < 4)
                          IconButton(
                            icon: const Icon(Icons.add_circle),
                            onPressed: () {
                              setState(() {
                                _pollOptionControllers.add(
                                  TextEditingController()
                                );
                              });
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Reset poll options
                      setState(() {
                        _showPollOptions = false;
                        _pollOptionControllers = [
                          TextEditingController(),
                          TextEditingController(),
                        ];
                      });
                    },
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      // Validate and create poll
                      if (_validatePoll(questionController, _pollOptionControllers)) {
                        _createPoll(questionController, _pollOptionControllers);
                      }
                    },
                    child: const Text('Create Poll'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Poll display widget
  Widget _buildPollWidget(MessageModel message) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message.text, 
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        if (message.pollOptions != null)
          ...message.pollOptions!.asMap().entries.map((entry) {
            int index = entry.key;
            String option = entry.value;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Voted for: $option'))
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade100,
                  foregroundColor: Colors.green.shade800,
                ),
                child: Text(option),
              ),
            );
          }).toList(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChatAppBar(
        userName: widget.userName,
        userProfilePic: widget.userProfilePic,
        onMoreOptionsPressed: () {
          // Show dropdown menu
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.block),
                      title: const Text('Block User'),
                      onTap: () {
                        Navigator.pop(context);
                        // Implement block user logic
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User Blocked'))
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.clear),
                      title: const Text('Clear Chat'),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          messages.clear();
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      body: Column(
        children: [
          // Chat messages list
          Expanded(
            child: ListView.builder(
              reverse: true,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[messages.length - 1 - index];
                return MessageBubble(
                  message: message,
                  onReact: (reaction) {
                    // Implement message reaction logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reacted with $reaction'))
                    );
                  },
                  pollWidgetBuilder: message.isPoll 
                    ? (msg) => _buildPollWidget(msg) 
                    : null,
                );
              },
            ),
          ),

          // Poll options (if enabled)
          if (_showPollOptions)
            _buildPollCreationWidget(),

          // Message input area
          MessageInputWidget(
            controller: _messageController,
            onSend: _sendMessage,
            onAttachmentTap: _showAdditionalOptionsBottomSheet,
          ),
        ],
      ),
    );
  }
}