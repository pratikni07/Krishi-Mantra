import 'package:flutter/material.dart';
import 'package:krishi_mantra/API/CropCareScreemAPI.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  _CreateGroupScreenState createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final ChatService _chatService = ChatService();

  String _groupName = '';
  String _groupDescription = '';
  bool _onlyAdminCanMessage = false;
  List<Map<String, String>> _participants = [];

  void _addParticipant(String userId, String userName, String profilePhoto) {
    setState(() {
      _participants.add({
        'userId': userId,
        'userName': userName,
        'profilePhoto': profilePhoto
      });
    });
  }

  void _removeParticipant(String userId) {
    setState(() {
      _participants
          .removeWhere((participant) => participant['userId'] == userId);
    });
  }

  void _createGroup() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        final response = await _chatService.createGroup(
          name: _groupName,
          description: _groupDescription,
          onlyAdminCanMessage: _onlyAdminCanMessage,
          participants: _participants,
        );

        if (response.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Group created successfully!')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create group')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Group'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter group name';
                  }
                  return null;
                },
                onSaved: (value) => _groupName = value!,
              ),
              SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Group Description (Optional)',
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => _groupDescription = value ?? '',
              ),
              SizedBox(height: 16),
              SwitchListTile(
                title: Text('Only Admins Can Message'),
                value: _onlyAdminCanMessage,
                onChanged: (bool value) {
                  setState(() {
                    _onlyAdminCanMessage = value;
                  });
                },
              ),
              SizedBox(height: 16),
              Text(
                'Participants',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // Add participant selection logic here
              ElevatedButton(
                onPressed: _createGroup,
                child: Text('Create Group'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
