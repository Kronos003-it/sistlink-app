import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminModeratePostsScreen extends StatefulWidget {
  const AdminModeratePostsScreen({super.key});

  @override
  State<AdminModeratePostsScreen> createState() =>
      _AdminModeratePostsScreenState();
}

class _AdminModeratePostsScreenState extends State<AdminModeratePostsScreen> {
  Future<void> _deletePost(String postId) async {
    // Show confirmation dialog before deleting
    bool? confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text(
            'Are you sure you want to delete this post? This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmDelete == true) {
      try {
        await FirebaseFirestore.instance
            .collection('posts')
            .doc(postId)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post deleted successfully.')),
          );
        }
      } catch (e) {
        print("Error deleting post: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete post: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderate Posts'),
        backgroundColor: Colors.blueAccent[700],
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('posts')
                .orderBy('timestamp', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error.toString()}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No posts found.'));
          }

          final posts = snapshot.data!.docs;

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final postData = posts[index].data() as Map<String, dynamic>;
              final String postId = posts[index].id;
              final String caption = postData['caption'] ?? 'No caption';
              final String username = postData['username'] ?? 'Unknown User';
              // Consider fetching/displaying post's own image if it has one:
              // final String? postImageUrl = postData['imageUrl'] as String?;
              // Consider fetching author's PFP:
              // final String? authorProfilePicUrl = postData['profilePicUrl'] as String?;

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                child: ListTile(
                  // leading: CircleAvatar( ... author PFP ... ), // Optional: Display author PFP
                  title: Text(
                    caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'By: $username\nPosted: ${postData['timestamp']?.toDate().toString() ?? 'N/A'}',
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red[700]),
                    onPressed: () => _deletePost(postId),
                    tooltip: 'Delete Post',
                  ),
                  onTap: () {
                    // Optional: Navigate to post detail or comment screen
                    // For now, just log or do nothing
                    print("Tapped on post: $postId");
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
