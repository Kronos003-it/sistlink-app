import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sist_link1/screens/comments/comments_screen.dart';
import 'package:sist_link1/screens/profile/profile_screen.dart';
import 'package:sist_link1/screens/events/create_event_screen.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  List<String> _followingIds = [];
  bool _isLoadingFollowing = true;

  @override
  void initState() {
    super.initState();
    _fetchFollowing();
  }

  Future<void> _fetchFollowing() async {
    if (_currentUserId == null) {
      setState(() => _isLoadingFollowing = false);
      return;
    }
    try {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUserId)
              .get();
      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          _followingIds = List<String>.from(userDoc.data()!['following'] ?? []);
          _isLoadingFollowing = false;
        });
      } else {
        setState(() => _isLoadingFollowing = false);
      }
    } catch (e) {
      print("Error fetching following list: $e");
      setState(() => _isLoadingFollowing = false);
    }
  }

  Future<void> _toggleLike(String postId, List<dynamic> currentLikes) async {
    if (_currentUserId == null) return;
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
    if (currentLikes.contains(_currentUserId)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([_currentUserId]),
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([_currentUserId]),
      });
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final Duration difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return DateFormat.yMMMd().format(dateTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SistLink'),
        actions: [
          IconButton(
            icon: const Icon(Icons.event),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateEventScreen(),
                ),
              );
            },
            tooltip: 'Create Event',
          ),
        ],
      ),
      body:
          _isLoadingFollowing
              ? const Center(child: CircularProgressIndicator())
              : _currentUserId == null || _followingIds.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _currentUserId == null
                        ? 'Please log in to see your feed.'
                        : 'Follow some users to see their posts here!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ),
              )
              : StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('posts')
                        .where(
                          'userId',
                          whereIn:
                              _followingIds.isNotEmpty
                                  ? _followingIds
                                  : ['dummy_non_existent_id'],
                        )
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No posts from users you follow yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    );
                  }

                  final posts = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index].data() as Map<String, dynamic>;
                      final String postId = posts[index].id;
                      final List<dynamic> likes = post['likes'] ?? [];
                      final bool isLikedByCurrentUser =
                          _currentUserId != null &&
                          likes.contains(_currentUserId);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 16.0,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder:
                                                    (context) => ProfileScreen(
                                                      userId: post['userId'],
                                                    ),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            post['username'] ?? 'User',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatTimestamp(
                                            post['timestamp'] as Timestamp,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                post['caption'] ?? '',
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          isLikedByCurrentUser
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color:
                                              isLikedByCurrentUser
                                                  ? Colors.red
                                                  : Colors.grey,
                                        ),
                                        onPressed:
                                            () => _toggleLike(postId, likes),
                                      ),
                                      Text('${likes.length}'),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.comment_outlined,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder:
                                              (context) => CommentsScreen(
                                                postId: postId,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.share_outlined,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      // TODO: Implement share functionality
                                    },
                                  ),
                                ],
                              ),
                            ],
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
