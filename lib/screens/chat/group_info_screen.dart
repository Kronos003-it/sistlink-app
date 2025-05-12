import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sist_link1/screens/profile/profile_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String chatId;

  const GroupInfoScreen({super.key, required this.chatId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  Map<String, dynamic>? _chatData;
  List<Map<String, dynamic>> _participantsData = [];
  bool _isLoading = true;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _fetchGroupDetails();
  }

  Future<void> _fetchGroupDetails() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final chatDocSnap =
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(widget.chatId)
              .get();

      if (chatDocSnap.exists && chatDocSnap.data() != null) {
        _chatData = chatDocSnap.data();
        final List<String> participantUids = List<String>.from(
          _chatData?['users'] ?? [],
        );

        if (participantUids.isNotEmpty) {
          List<Map<String, dynamic>> participants = [];
          for (String uid in participantUids) {
            final userDocSnap =
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get();
            if (userDocSnap.exists && userDocSnap.data() != null) {
              participants.add({
                'uid': uid,
                'username': userDocSnap.data()!['username'] ?? 'Unknown User',
                // Add other user data if needed, e.g., profilePicUrl
              });
            } else {
              participants.add({'uid': uid, 'username': 'User not found'});
            }
          }
          _participantsData = participants;
        }
      }
    } catch (e) {
      print("Error fetching group details: $e");
      // Handle error, maybe show a SnackBar
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _leaveGroup() async {
    if (_currentUserId == null || _chatData == null) return;

    final bool? confirmLeave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Leave Group'),
          content: Text(
            'Are you sure you want to leave "${_chatData!['groupName'] ?? 'this group'}"?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Leave', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmLeave == true) {
      setState(() => _isLoading = true); // Show loading indicator
      try {
        final chatRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatId);

        // Remove current user from users list and admins list (if present)
        // Also remove their username from userNames map
        await chatRef.update({
          'users': FieldValue.arrayRemove([_currentUserId]),
          'admins': FieldValue.arrayRemove([_currentUserId]),
          'userNames.$_currentUserId': FieldValue.delete(),
          'updatedAt':
              FieldValue.serverTimestamp(), // Ensure updatedAt is part of the update
        });

        // Calculate remaining users and admins based on the state *before* the current user left.
        // This avoids a get() call that might fail due to permissions after leaving.
        if (_chatData != null && _currentUserId != null) {
          List<String> usersInOldDoc = List<String>.from(
            _chatData!['users'] ?? [],
          );
          List<String> adminsInOldDoc = List<String>.from(
            _chatData!['admins'] ?? [],
          );

          List<String> usersAfterSelfRemoval = List<String>.from(usersInOldDoc)
            ..remove(_currentUserId!);
          List<String> adminsAfterSelfRemoval = List<String>.from(
            adminsInOldDoc,
          )..remove(_currentUserId!);

          if (usersAfterSelfRemoval.isEmpty) {
            await chatRef.delete(); // Delete group if empty
            print("Group deleted as it became empty.");
          } else if (adminsAfterSelfRemoval.isEmpty &&
              usersAfterSelfRemoval.isNotEmpty) {
            // Promote the first remaining user to admin if no admins left
            await chatRef.update({
              'admins': [usersAfterSelfRemoval.first],
              'updatedAt': FieldValue.serverTimestamp(),
            });
            print("Promoted ${usersAfterSelfRemoval.first} to admin.");
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have left the group.')),
          );
          // Pop multiple times to go back past ChatScreen
          int popCount = 0;
          Navigator.of(context).popUntil((route) => popCount++ >= 2);
        }
      } catch (e) {
        print("Error leaving group: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to leave group.')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(_chatData?['groupName'] ?? 'Group Info')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_chatData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Group Info')),
        body: const Center(
          child: Text('Group not found or error loading details.'),
        ),
      );
    }

    final String groupName = _chatData!['groupName'] ?? 'Unnamed Group';
    final List<String> adminUids = List<String>.from(
      _chatData!['admins'] ?? [],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(groupName),
        // TODO: Add Edit Group Name button for admins
      ),
      body: RefreshIndicator(
        onRefresh: _fetchGroupDetails,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              'Participants (${_participantsData.length})',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (_participantsData.isEmpty)
              const Text('No participants found.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _participantsData.length,
                itemBuilder: (context, index) {
                  final participant = _participantsData[index];
                  final bool isAdmin = adminUids.contains(participant['uid']);
                  return ListTile(
                    title: Text(participant['username'] ?? 'Unknown'),
                    subtitle: isAdmin ? const Text('Admin') : null,
                    // leading: CircleAvatar(...), // TODO: Profile pic
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (context) =>
                                  ProfileScreen(userId: participant['uid']),
                        ),
                      );
                    },
                    // TODO: Add "Remove" button for admins (if not self)
                  );
                },
              ),
            const SizedBox(height: 24),

            // TODO: Add "Add Participants" button for admins
            ElevatedButton(
              onPressed: _leaveGroup,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text(
                'Leave Group',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
