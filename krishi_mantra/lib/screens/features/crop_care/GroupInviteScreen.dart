import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:krishi_mantra/API/CropCareScreemAPI.dart';

class GroupInviteScreen extends StatefulWidget {
  const GroupInviteScreen({Key? key}) : super(key: key);

  @override
  _GroupInviteScreenState createState() => _GroupInviteScreenState();
}

class _GroupInviteScreenState extends State<GroupInviteScreen> {
  final TextEditingController _inviteController = TextEditingController();
  final ChatService _chatService = ChatService();

  void _joinGroup() async {
    if (_inviteController.text.isNotEmpty) {
      try {
        final response = await _chatService.joinGroupViaInvite(
          inviteUrl: _inviteController.text.trim(),
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully joined the group!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to join group'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Join Group'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Enter Group Invite Link',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _inviteController,
              decoration: InputDecoration(
                labelText: 'Invite Link',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.paste),
                  onPressed: () async {
                    final clipboardData = await Clipboard.getData('text/plain');
                    if (clipboardData != null && clipboardData.text != null) {
                      _inviteController.text = clipboardData.text!;
                    }
                  },
                ),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _joinGroup,
              child: Text('Join Group'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
