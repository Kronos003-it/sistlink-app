import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:sist_link1/screens/profile/profile_screen.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  const CommentsScreen({super.key, required this.postId});

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String? _currentUsername;
  // String? _currentUserProfilePicUrl; // No longer needed for sending, PFP display removed

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    if (_currentUser != null) {
      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUser!.uid)
                .get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _currentUsername = data['username'];
            // _currentUserProfilePicUrl = data['profilePicUrl']; // Not needed
          });
        }
      } catch (e) {
        print("Error loading current user data for comments: $e");
      }
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty ||
        _currentUser == null ||
        _currentUsername == null) {
      return;
    }
    String commentText = _commentController.text.trim();
    _commentController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
            'text': commentText,
            'userId': _currentUser!.uid,
            'username': _currentUsername,
            'type': 'text', // Ensure type is sent for the rule
            // 'profilePicUrl': _currentUserProfilePicUrl ?? '', // Removed PFP URL from comment data
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error posting comment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment.')),
        );
      }
    }
  }

  String _formatCommentTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final DateTime dateTime = timestamp.toDate();
    final Duration difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0)
      return DateFormat.yMMMd().add_jm().format(dateTime);
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Future<void> _reportComment(
    String commentId,
    String commentText,
    String commentAuthorId,
    String commentAuthorUsername,
  ) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to report a comment.'),
        ),
      );
      return;
    }

    bool? confirmReport = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Report Comment'),
            content: const Text(
              'Are you sure you want to report this comment? This may lead to actions against the comment or user if it violates community guidelines.',
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
        String snippet =
            commentText.length > 100
                ? '${commentText.substring(0, 100)}...'
                : commentText;

        await FirebaseFirestore.instance.collection('reports').add({
          'reporterUserId': _currentUser!.uid,
          'reportedContentId': commentId,
          'reportedContentType': 'comment',
          'parentContentId': widget.postId,
          'parentContentType': 'post',
          'reportedUserId': commentAuthorId,
          'reportedUsername': commentAuthorUsername,
          'commentTextSnippet': snippet,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'pending',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment reported successfully.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to report comment: ${e.toString()}'),
            ),
          );
        }
        print('Error reporting comment: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blueAccent[700]!;
    final Color subtleTextColor = Colors.grey[600]!;
    final Color textFieldBackgroundColor = Colors.grey[100]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Post & Comments', // Updated title
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          // Widget to display parent post content
          FutureBuilder<DocumentSnapshot>(
            future:
                FirebaseFirestore.instance
                    .collection('posts')
                    .doc(widget.postId)
                    .get(),
            builder: (context, postSnapshot) {
              if (postSnapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text('Post not found or has been deleted.'),
                  ),
                );
              }
              final postData =
                  postSnapshot.data!.data() as Map<String, dynamic>;
              final String postCaption = postData['caption'] ?? 'No caption';
              final String postUsername = postData['username'] ?? 'User';
              final String postUserId = postData['userId'] ?? '';
              final String? postAuthorPfpUrl =
                  postData['profilePicUrl'] as String?;
              final Timestamp? postTimestamp =
                  postData['timestamp'] as Timestamp?;

              // Helper to format timestamp (can be moved to a utility class)
              String formatPostTimestamp(Timestamp? timestamp) {
                if (timestamp == null) return '';
                final DateTime dateTime = timestamp.toDate();
                final Duration difference = DateTime.now().difference(dateTime);
                if (difference.inDays > 7)
                  return DateFormat.yMMMd().format(dateTime);
                if (difference.inDays > 0) return '${difference.inDays}d ago';
                if (difference.inHours > 0) return '${difference.inHours}h ago';
                if (difference.inMinutes > 0)
                  return '${difference.inMinutes}m ago';
                return 'Just now';
              }

              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: Colors.grey[300],
                          backgroundImage:
                              (postAuthorPfpUrl != null &&
                                      postAuthorPfpUrl.isNotEmpty)
                                  ? NetworkImage(postAuthorPfpUrl)
                                  : null,
                          child:
                              (postAuthorPfpUrl == null ||
                                      postAuthorPfpUrl.isEmpty)
                                  ? Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Colors.grey[600],
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                postUsername,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (postTimestamp != null)
                                Text(
                                  formatPostTimestamp(postTimestamp),
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
                    const SizedBox(height: 10),
                    Text(
                      postCaption,
                      style: const TextStyle(fontSize: 16, height: 1.4),
                    ),
                    // Display Post Image if available
                    if (postData['imageUrl'] != null &&
                        (postData['imageUrl'] as String).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.network(
                          postData['imageUrl'] as String,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (
                            BuildContext context,
                            Widget child,
                            ImageChunkEvent? loadingProgress,
                          ) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200, // Placeholder height
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
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
                              (context, error, stackTrace) => Container(
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
                    Divider(
                      height: 20,
                      thickness: 0.5,
                      color: Colors.grey[300],
                    ),
                  ],
                ),
              );
            },
          ),
          // Existing comments list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.postId)
                      .collection('comments')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No comments yet. Be the first!'),
                  );
                }
                final comments = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment =
                        comments[index].data() as Map<String, dynamic>;
                    final String commentUsername =
                        comment['username'] ?? 'User';
                    final String commentUserId = comment['userId'] ?? '';
                    // final String? commentProfilePicUrl = comment['profilePicUrl'] as String?; // PFP URL no longer used for display

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8.0,
                        horizontal: 4.0,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (commentUserId.isNotEmpty) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ProfileScreen(
                                          userId: commentUserId,
                                        ),
                                  ),
                                );
                              }
                            },
                            child: CircleAvatar(
                              // Default icon
                              radius: 18,
                              backgroundColor: Colors.grey[300],
                              child: Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        if (commentUserId.isNotEmpty) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => ProfileScreen(
                                                    userId: commentUserId,
                                                  ),
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        commentUsername,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatCommentTimestamp(
                                        comment['timestamp'] as Timestamp?,
                                      ),
                                      style: TextStyle(
                                        color: subtleTextColor,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  comment['text'] ?? '',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Add PopupMenuButton for reporting comment
                          if (_currentUser != null &&
                              _currentUser!.uid != commentUserId)
                            PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                size: 20,
                                color: Colors.grey[600],
                              ),
                              onSelected: (value) {
                                if (value == 'report') {
                                  final String commentId = comments[index].id;
                                  final String commentText =
                                      comment['text'] ?? '';
                                  // Call _reportComment method (to be added)
                                  _reportComment(
                                    commentId,
                                    commentText,
                                    commentUserId,
                                    commentUsername,
                                  );
                                }
                              },
                              itemBuilder:
                                  (BuildContext context) =>
                                      <PopupMenuEntry<String>>[
                                        const PopupMenuItem<String>(
                                          value: 'report',
                                          child: Text('Report Comment'),
                                        ),
                                      ],
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_currentUser != null)
            Padding(
              padding: const EdgeInsets.only(
                left: 12.0,
                right: 12.0,
                bottom: 20.0,
                top: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        filled: true,
                        fillColor: textFieldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10.0,
                          horizontal: 16.0,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send, color: primaryColor),
                    onPressed: _postComment,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
