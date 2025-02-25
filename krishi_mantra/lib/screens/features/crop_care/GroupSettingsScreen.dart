import 'package:flutter/material.dart';
import 'package:krishi_mantra/API/CropCareScreemAPI.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? groupDescription;
  final bool currentAdminSetting;

  const GroupSettingsScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
    this.groupDescription,
    required this.currentAdminSetting,
  }) : super(key: key);

  @override
  _GroupSettingsScreenState createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  final ChatService _chatService = ChatService();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late bool _onlyAdminCanMessage;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.groupName);
    _descriptionController =
        TextEditingController(text: widget.groupDescription);
    _onlyAdminCanMessage = widget.currentAdminSetting;
  }

  void _updateGroupSettings() async {
    try {
      final response = await _chatService.updateGroupSettings(
        groupId: widget.groupId,
        name: _nameController.text,
        description: _descriptionController.text,
        onlyAdminCanMessage: _onlyAdminCanMessage,
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Group settings updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update group settings'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Group Settings'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Group Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            SizedBox(height: 16),
            SwitchListTile(
              title: Text('Only Admins Can Message'),
              subtitle:
                  Text('When enabled, only group admins can send messages'),
              value: _onlyAdminCanMessage,
              onChanged: (bool value) {
                setState(() {
                  _onlyAdminCanMessage = value;
                });
              },
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _updateGroupSettings,
              child: Text('Save Changes'),
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
