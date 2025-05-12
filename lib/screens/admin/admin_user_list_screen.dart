import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sist_link1/screens/profile/profile_screen.dart'; // To navigate to user profiles

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _toggleAdminStatus(String userId, bool currentIsAdmin) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isAdmin': !currentIsAdmin,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User admin status ${!currentIsAdmin ? "granted" : "revoked"} successfully.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update admin status: ${e.toString()}'),
        ),
      );
    }
  }

  Future<void> _toggleBanStatus(String userId, bool currentIsBanned) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isBanned': !currentIsBanned,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'User ${!currentIsBanned ? "banned" : "unbanned"} successfully.',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update ban status: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        backgroundColor: Colors.blueAccent[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('users').orderBy('username').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!.docs;

          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final String userId = users[index].id;
              final String username = userData['username'] ?? 'N/A';
              final String email = userData['email'] ?? 'N/A';
              final bool isAdmin = userData['isAdmin'] ?? false;
              final bool isBanned = userData['isBanned'] ?? false;
              // final String? profilePicUrl = userData['profilePicUrl'] as String?; // PFP URL no longer used

              return ListTile(
                leading: CircleAvatar(
                  // Default icon
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.person, color: Colors.grey[700]),
                ),
                title: Text(
                  username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message: isAdmin ? 'Revoke Admin' : 'Grant Admin',
                      child: IconButton(
                        icon: Icon(
                          isAdmin
                              ? Icons.shield_rounded
                              : Icons.shield_outlined,
                          color: isAdmin ? Colors.blueAccent[700] : Colors.grey,
                        ),
                        onPressed: () => _toggleAdminStatus(userId, isAdmin),
                      ),
                    ),
                    Tooltip(
                      message: isBanned ? 'Unban User' : 'Ban User',
                      child: IconButton(
                        icon: Icon(
                          isBanned ? Icons.block_flipped : Icons.block,
                          color: isBanned ? Colors.redAccent[700] : Colors.grey,
                        ),
                        onPressed: () => _toggleBanStatus(userId, isBanned),
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ProfileScreen(userId: userId),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
