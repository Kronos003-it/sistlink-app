import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminUserListScreen extends StatefulWidget {
  const AdminUserListScreen({super.key});

  @override
  State<AdminUserListScreen> createState() => _AdminUserListScreenState();
}

class _AdminUserListScreenState extends State<AdminUserListScreen> {
  final String? _currentAdminId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> _toggleAdminStatus(String userId, bool currentIsAdmin) async {
    if (userId == _currentAdminId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admins cannot change their own admin status.'),
        ),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isAdmin': !currentIsAdmin,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User admin status updated to ${!currentIsAdmin}.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating admin status: $e')),
      );
    }
  }

  Future<void> _toggleBanStatus(String userId, bool currentIsBanned) async {
    if (userId == _currentAdminId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admins cannot ban themselves.')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isBanned': !currentIsBanned,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User ban status updated to ${!currentIsBanned}.'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating ban status: $e')));
    }
  }

  void _showUserActionsDialog(
    BuildContext context,
    String userId,
    String username,
    bool isAdmin,
    bool isBanned,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Manage: $username'),
          contentPadding: const EdgeInsets.all(20.0).copyWith(top: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'UID: $userId',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Text('Admin Status: ${isAdmin ? "Admin" : "User"}'),
              Text('Ban Status: ${isBanned ? "Banned" : "Not Banned"}'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                isAdmin ? 'Remove Admin' : 'Make Admin',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _toggleAdminStatus(userId, isAdmin);
              },
            ),
            TextButton(
              child: Text(
                isBanned ? 'Unban User' : 'Ban User',
                style: TextStyle(color: isBanned ? Colors.green : Colors.red),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _toggleBanStatus(userId, isBanned);
              },
            ),
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Manage Users',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .orderBy('username')
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.'));
          }

          final users = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(8.0),
            itemCount: users.length,
            separatorBuilder:
                (context, index) =>
                    const SizedBox(height: 0), // Cards have their own margin
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final String userId = users[index].id;
              final String username = userData['username'] ?? 'N/A';
              final String email = userData['email'] ?? 'N/A';
              final bool isAdmin = userData['isAdmin'] ?? false;
              final bool isBanned = userData['isBanned'] ?? false;

              return Card(
                elevation: 1.0,
                margin: const EdgeInsets.symmetric(
                  vertical: 5.0,
                  horizontal: 8.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[300],
                    child: Icon(Icons.person_outline, color: Colors.grey[700]),
                  ),
                  title: Text(
                    username,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isBanned ? Colors.red[700] : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    email,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: <Widget>[
                      if (isAdmin)
                        Chip(
                          label: const Text('Admin'),
                          backgroundColor: Colors.orangeAccent.withOpacity(0.2),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[800],
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 0,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      if (isBanned)
                        Chip(
                          label: const Text('Banned'),
                          backgroundColor: Colors.redAccent.withOpacity(0.2),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            color: Colors.red[700],
                            fontWeight: FontWeight.w500,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 0,
                          ),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                    ],
                  ),
                  onTap:
                      () => _showUserActionsDialog(
                        context,
                        userId,
                        username,
                        isAdmin,
                        isBanned,
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
