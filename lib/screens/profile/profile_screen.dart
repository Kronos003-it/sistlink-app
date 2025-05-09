import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:sist_link1/screens/profile/edit_profile_screen.dart';
import 'package:sist_link1/screens/chat/chat_screen.dart';
import 'package:sist_link1/screens/admin/admin_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  const ProfileScreen({super.key, required this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profileUserData; // Store fetched data here
  bool _isFollowing = false;
  bool _isLoading = true; // Combined loading state
  bool _isProcessingFollow = false;
  List<dynamic> _currentUserFollowing = [];
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final profileDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();
      if (profileDoc.exists) {
        _profileUserData = profileDoc.data();
        if (_currentUserId != null && _currentUserId != widget.userId) {
          final currentUserDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUserId)
                  .get();
          if (currentUserDoc.exists) {
            _currentUserFollowing = currentUserDoc.data()?['following'] ?? [];
            _isFollowing = _currentUserFollowing.contains(widget.userId);
          }
        }
      }
    } catch (e) {
      print("Error loading profile data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatProfileLastSeen(Timestamp? timestamp, bool isOnline) {
    if (isOnline) return 'Online';
    if (timestamp == null) return 'Offline';
    final DateTime now = DateTime.now();
    final DateTime lastSeenTime = timestamp.toDate();
    final Duration difference = now.difference(lastSeenTime);

    if (difference.inMinutes < 1) return 'Last seen just now';
    if (difference.inMinutes < 60)
      return 'Last seen ${difference.inMinutes}m ago';
    if (difference.inHours < 24) return 'Last seen ${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Last seen yesterday';
    return 'Last seen ${DateFormat.yMd().format(lastSeenTime)}';
  }

  Future<void> _toggleFollow() async {
    // ... (keep existing _toggleFollow logic, ensure it calls _loadProfileData or setState to refresh UI)
    if (_currentUserId == null || _currentUserId == widget.userId) return;
    setState(() => _isProcessingFollow = true);
    final currentUserRef = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUserId);
    final profileUserRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);
    try {
      if (_isFollowing) {
        await currentUserRef.update({
          'following': FieldValue.arrayRemove([widget.userId]),
        });
        await profileUserRef.update({
          'followers': FieldValue.arrayRemove([_currentUserId]),
        });
      } else {
        await currentUserRef.update({
          'following': FieldValue.arrayUnion([widget.userId]),
        });
        await profileUserRef.update({
          'followers': FieldValue.arrayUnion([_currentUserId]),
        });
      }
      // Refresh data after follow/unfollow
      await _loadProfileData();
    } catch (e) {
      print("Error toggling follow: $e");
    } finally {
      if (mounted) setState(() => _isProcessingFollow = false);
    }
  }

  Future<void> _startChat(String profileUsername) async {
    // ... (keep existing _startChat logic)
    if (_currentUserId == null || _currentUserId == widget.userId) return;

    final currentUserDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .get();
    String currentUsername =
        currentUserDoc.data()?['username'] ?? 'Unknown User';

    List<String> ids = [_currentUserId!, widget.userId];
    ids.sort();
    String chatId = ids.join('_');
    final chatDocRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId);

    try {
      final chatDoc = await chatDocRef.get();
      if (!chatDoc.exists) {
        await chatDocRef.set({
          'users': ids,
          'userNames': {
            _currentUserId!: currentUsername,
            widget.userId: profileUsername,
          },
          'lastMessage': null,
          'lastMessageTimestamp': null,
          'isGroup': false,
        });
      }
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  chatId: chatId,
                  chatName: profileUsername,
                  otherUserId: widget.userId,
                ),
          ),
        );
      }
    } catch (e) {
      print("Error starting chat: $e");
    }
  }

  Widget _buildInfoField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 4),
        Text(
          value.isNotEmpty ? value : 'N/A',
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blueAccent[700]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Profile Page'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        titleTextStyle: const TextStyle(
          color: Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _profileUserData == null
              ? const Center(
                child: Text('User not found or error loading data.'),
              )
              : RefreshIndicator(
                onRefresh: _loadProfileData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey[300],
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey[600],
                        ),
                        // TODO: Replace with actual profile picture if implemented
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _profileUserData!['username'] ?? 'N/A',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color:
                                  (_profileUserData!['isOnline'] ?? false)
                                      ? Colors.green
                                      : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatProfileLastSeen(
                              _profileUserData!['lastSeen'] as Timestamp?,
                              _profileUserData!['isOnline'] ?? false,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Followers: ${_profileUserData!['followers']?.length ?? 0}',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),

                      _buildInfoField('Bio', _profileUserData!['bio'] ?? ''),
                      _buildInfoField(
                        'Email',
                        _profileUserData!['email'] ?? '',
                      ),

                      // Mockup has "School Name" - we don't have this field.
                      // Mockup has "Contact Information" which is email here.
                      const SizedBox(height: 24),

                      if (_currentUserId == widget.userId) ...[
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => const EditProfileScreen(),
                                  ),
                                )
                                .then(
                                  (_) => _loadProfileData(),
                                ); // Refresh on return
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Edit Profile',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                        if (_profileUserData!['isAdmin'] == true) ...[
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => const AdminDashboardScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                            ),
                            child: const Text(
                              'Admin Panel',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed:
                                  _isProcessingFollow ? null : _toggleFollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    _isFollowing ? Colors.grey : primaryColor,
                                foregroundColor: Colors.white,
                              ),
                              child:
                                  _isProcessingFollow
                                      ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                      : Text(
                                        _isFollowing ? 'Unfollow' : 'Follow',
                                      ),
                            ),
                            ElevatedButton(
                              onPressed:
                                  () => _startChat(
                                    _profileUserData!['username'] ?? 'User',
                                  ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Message'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 30),
                      const Divider(),
                      Text(
                        'Posts by ${_profileUserData!['username'] ?? 'User'}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      // Existing StreamBuilder for posts can remain here or be refactored.
                      // For brevity, assuming it's kept similar to before.
                      StreamBuilder<QuerySnapshot>(
                        stream:
                            FirebaseFirestore.instance
                                .collection('posts')
                                .where('userId', isEqualTo: widget.userId)
                                .orderBy('timestamp', descending: true)
                                .snapshots(),
                        builder: (context, postSnapshot) {
                          if (!postSnapshot.hasData)
                            return const Center(
                              child: Text("Loading posts..."),
                            );
                          if (postSnapshot.data!.docs.isEmpty)
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('No posts yet.'),
                              ),
                            );
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: postSnapshot.data!.docs.length,
                            itemBuilder: (context, index) {
                              final post = postSnapshot.data!.docs[index];
                              return Card(
                                child: ListTile(
                                  title: Text(post['caption'] ?? ''),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
