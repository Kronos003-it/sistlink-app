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
    if (difference.inDays > 0) return DateFormat.yMMMd().format(dateTime);
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _reportPost(
    String postId,
    String postCreatorId,
    String postCreatorUsername,
  ) async {
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to report a post.'),
        ),
      );
      return;
    }

    // Optional: Show a confirmation dialog
    bool? confirmReport = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Report Post'),
            content: const Text(
              'Are you sure you want to report this post? This may lead to actions against the post or user if it violates community guidelines.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Report'),
              ),
            ],
          ),
    );

    if (confirmReport == true) {
      try {
        await FirebaseFirestore.instance.collection('reports').add({
          'reporterUserId': _currentUserId,
          'reportedContentId': postId,
          'reportedContentType': 'post',
          'reportedUserId': postCreatorId,
          'reportedUsername': postCreatorUsername,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Post reported successfully. Thank you for your feedback.',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to report post: ${e.toString()}')),
          );
        }
        print('Error reporting post: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blueAccent[700]!;
    final Color cardBackgroundColor = Colors.white;
    final Color subtleTextColor = Colors.grey[600]!;

    List<String> idsForFeed = List.from(_followingIds);
    if (_currentUserId != null && !idsForFeed.contains(_currentUserId!)) {
      idsForFeed.add(_currentUserId!);
    }
    final List<String> queryIds =
        idsForFeed.isNotEmpty ? idsForFeed : ['dummy_non_existent_id'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'SistLink Feed',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: Icon(Icons.event_available, color: primaryColor),
            onPressed:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreateEventScreen(),
                  ),
                ),
            tooltip: 'Create Event',
          ),
        ],
      ),
      body:
          _isLoadingFollowing
              ? const Center(child: CircularProgressIndicator())
              : _currentUserId == null
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Please log in to see your feed.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: subtleTextColor),
                  ),
                ),
              )
              : StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('posts')
                        .where('userId', whereIn: queryIds)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (snapshot.hasError)
                    return Center(child: Text('Error: ${snapshot.error}'));
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'No posts yet. Follow some users or create your own post!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: subtleTextColor,
                          ),
                        ),
                      ),
                    );
                  }
                  final posts = snapshot.data!.docs;
                  return ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: posts.length,
                    itemBuilder: (context, index) {
                      final post = posts[index].data() as Map<String, dynamic>;
                      final String postId = posts[index].id;
                      final List<dynamic> likes = post['likes'] ?? [];
                      final bool isLikedByCurrentUser =
                          _currentUserId != null &&
                          likes.contains(_currentUserId);
                      final String profilePicUrl =
                          post['profilePicUrl'] ??
                          ''; // Re-enabled PFP for post author
                      final String postUsername = post['username'] ?? 'User';
                      final String postUserId = post['userId'] ?? '';
                      final String? postImageUrl =
                          post['imageUrl']
                              as String?; // Re-enabled post image display

                      return Card(
                        elevation: 1.0,
                        margin: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        // clipBehavior: Clip.antiAlias, // Not needed if no image that might overflow
                        color: cardBackgroundColor,
                        child: Padding(
                          // Changed from Column to Padding directly on Card
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                // User info row
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.grey[300],
                                    backgroundImage:
                                        profilePicUrl.isNotEmpty
                                            ? NetworkImage(profilePicUrl)
                                            : null,
                                    child:
                                        profilePicUrl.isEmpty
                                            ? Icon(
                                              Icons.person,
                                              color: Colors.grey[600],
                                            )
                                            : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        GestureDetector(
                                          onTap: () {
                                            if (postUserId.isNotEmpty) {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          ProfileScreen(
                                                            userId: postUserId,
                                                          ),
                                                ),
                                              );
                                            }
                                          },
                                          child: Text(
                                            postUsername,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatTimestamp(
                                            post['timestamp'] as Timestamp,
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: subtleTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // PopupMenuButton for more options (e.g., Report)
                                  if (_currentUserId != null &&
                                      _currentUserId !=
                                          postUserId) // Don't show report for own posts
                                    PopupMenuButton<String>(
                                      icon: Icon(
                                        Icons.more_vert,
                                        color: subtleTextColor,
                                      ),
                                      onSelected: (value) {
                                        if (value == 'report') {
                                          // Call _reportPost method (to be added)
                                          _reportPost(
                                            postId,
                                            postUserId,
                                            postUsername,
                                          );
                                        }
                                      },
                                      itemBuilder:
                                          (BuildContext context) =>
                                              <PopupMenuEntry<String>>[
                                                const PopupMenuItem<String>(
                                                  value: 'report',
                                                  child: Text('Report Post'),
                                                ),
                                              ],
                                    ),
                                ],
                              ),
                              const SizedBox(
                                height: 12,
                              ), // Space after user info
                              if (post['caption'] != null &&
                                  (post['caption'] as String).isNotEmpty)
                                Text(
                                  post['caption'],
                                  style: const TextStyle(
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              if (postImageUrl != null &&
                                  postImageUrl.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8.0),
                                  child: Image.network(
                                    postImageUrl,
                                    fit: BoxFit.cover,
                                    width:
                                        double.infinity, // Take full card width
                                    // You might want to set a max height or aspect ratio
                                    loadingBuilder: (
                                      BuildContext context,
                                      Widget child,
                                      ImageChunkEvent? loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        height:
                                            200, // Placeholder height during loading
                                        color: Colors.grey[200],
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            value:
                                                loadingProgress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? loadingProgress
                                                            .cumulativeBytesLoaded /
                                                        loadingProgress
                                                            .expectedTotalBytes!
                                                    : null,
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 200,
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: Icon(
                                                  Icons.broken_image,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                              ],
                              const SizedBox(
                                height: 12,
                              ), // Space before actions
                              Divider(color: Colors.grey[200], height: 16),
                              Row(
                                // Actions row
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                                  ? Colors.redAccent
                                                  : subtleTextColor,
                                        ),
                                        iconSize: 22,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed:
                                            () => _toggleLike(postId, likes),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${likes.length}',
                                        style: TextStyle(
                                          color: subtleTextColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          Icons.chat_bubble_outline,
                                          color: subtleTextColor,
                                        ),
                                        iconSize: 22,
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed:
                                            () => Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder:
                                                    (context) => CommentsScreen(
                                                      postId: postId,
                                                    ),
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.share_outlined,
                                      color: subtleTextColor,
                                    ),
                                    iconSize: 22,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      /* TODO: Implement share */
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
