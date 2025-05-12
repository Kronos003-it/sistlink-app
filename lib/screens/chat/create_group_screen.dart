import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sist_link1/screens/chat/chat_screen.dart'; // Import ChatScreen

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  final List<String> _selectedUserIds = [];
  final List<Map<String, dynamic>> _followList = [];
  bool _isLoading = true;
  bool _isCreatingGroup = false;
  String? _currentUserId;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _fetchFollowingAndCurrentUser();
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchFollowingAndCurrentUser() async {
    if (_currentUserId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final currentUserDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUserId)
              .get();
      if (currentUserDoc.exists) {
        _currentUsername = currentUserDoc.data()?['username'];
      }
      final followingIds = List<String>.from(
        currentUserDoc.data()?['following'] ?? [],
      );
      if (followingIds.isNotEmpty) {
        final usersSnapshot =
            await FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: followingIds)
                .get();
        for (var doc in usersSnapshot.docs) {
          _followList.add({
            'uid': doc.id,
            'username': doc.data()['username'] ?? 'Unknown',
          });
        }
      }
    } catch (e) {
      print("Error fetching following list: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleUserSelection(String userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name.')),
      );
      return;
    }
    if (_selectedUserIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one user.')),
      );
      return;
    }
    if (_currentUserId == null || _currentUsername == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Current user data not found.')),
      );
      return;
    }

    setState(() => _isCreatingGroup = true);

    final List<String> participantIds = [_currentUserId!, ..._selectedUserIds];
    final Map<String, String> participantNames = {
      _currentUserId!: _currentUsername!,
    };
    for (var user in _followList) {
      if (_selectedUserIds.contains(user['uid'])) {
        participantNames[user['uid']] = user['username'];
      }
    }

    try {
      final newChatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .add({
            'groupName': groupName,
            'isGroup': true,
            'users': participantIds,
            'userNames': participantNames,
            'admins': [_currentUserId],
            'lastMessage': null,
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(), // Added createdAt field
          });

      print('Group created with ID: ${newChatDoc.id}');

      if (mounted) {
        // Pop CreateGroupScreen and push ChatScreen
        Navigator.of(context).pushReplacement(
          // Use pushReplacement
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  chatId: newChatDoc.id,
                  chatName: groupName, // Use group name
                  isGroup: true, // Indicate it's a group
                ),
          ),
        );
      }
    } catch (e) {
      print("Error creating group: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create group.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingGroup = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Group'),
        actions: [
          TextButton(
            onPressed: _isCreatingGroup ? null : _createGroup,
            child:
                _isCreatingGroup
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Create'),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Select Participants (from following):',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    child:
                        _followList.isEmpty
                            ? const Center(
                              child: Text('You are not following anyone.'),
                            )
                            : ListView.builder(
                              itemCount: _followList.length,
                              itemBuilder: (context, index) {
                                final user = _followList[index];
                                final userId = user['uid'];
                                final username = user['username'];
                                final isSelected = _selectedUserIds.contains(
                                  userId,
                                );

                                return CheckboxListTile(
                                  title: Text(username),
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    _toggleUserSelection(userId);
                                  },
                                );
                              },
                            ),
                  ),
                ],
              ),
    );
  }
}
