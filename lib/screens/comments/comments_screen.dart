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
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final String? _currentUsername =
      FirebaseAuth.instance.currentUser?.displayName;
  bool _isPostingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty ||
        _currentUserId == null ||
        _currentUsername == null) {
      return;
    }
    setState(() => _isPostingComment = true);
    try {
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(widget.postId)
          .collection('comments')
          .add({
            'text': commentText,
            'userId': _currentUserId,
            'username': _currentUsername,
            'timestamp': FieldValue.serverTimestamp(),
            'likes': [],
          });
      _commentController.clear();
    } catch (e) {
      print("Error posting comment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post comment.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  String _formatCommentTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final DateTime dateTime = timestamp.toDate();
    final Duration difference = DateTime.now().difference(dateTime);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m';
    if (difference.inHours < 24) return '${difference.inHours}h';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return DateFormat.yMd().format(dateTime);
  }

  Widget _buildCommentInputArea() {
    final Color primaryColor = Colors.blueAccent[700]!;
    return Container(
      padding: EdgeInsets.only(
        left: 16.0,
        right: 8.0,
        top: 8.0,
        bottom: MediaQuery.of(context).padding.bottom + 8.0,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 15.0,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              enabled: !_isPostingComment,
            ),
          ),
          _isPostingComment
              ? const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
              : IconButton(
                icon: Icon(Icons.send, color: primaryColor),
                onPressed: _postComment,
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color subtleTextColor = Colors.grey[600]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Comments',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('posts')
                      .doc(widget.postId)
                      .collection('comments')
                      .orderBy(
                        'timestamp',
                        descending: false,
                      ) // Show oldest comments first
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No comments yet. Be the first!'),
                  );
                }
                final comments = snapshot.data!.docs;
                return ListView.separated(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: comments.length,
                  separatorBuilder:
                      (context, index) =>
                          Divider(color: Colors.grey[200], height: 1),
                  itemBuilder: (context, index) {
                    final commentData =
                        comments[index].data() as Map<String, dynamic>;
                    final String username = commentData['username'] ?? 'User';
                    final String text = commentData['text'] ?? '';
                    final String userId = commentData['userId'] ?? '';
                    final Timestamp? timestamp =
                        commentData['timestamp'] as Timestamp?;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: Icon(Icons.person, color: Colors.grey[600]),
                        // TODO: User profile pic
                      ),
                      title: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (userId.isNotEmpty) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            ProfileScreen(userId: userId),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              username,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatCommentTimestamp(timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: subtleTextColor,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(text, style: const TextStyle(fontSize: 15)),
                      ),
                      // TODO: Add like button for comments
                    );
                  },
                );
              },
            ),
          ),
          _buildCommentInputArea(),
        ],
      ),
    );
  }
}
