import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io'; // Re-added
import 'package:image_picker/image_picker.dart'; // Re-added
import 'package:firebase_storage/firebase_storage.dart'
    as firebase_storage; // Re-added

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  bool _isLoading = false;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String? _currentUsername;
  String?
  _currentUserProfilePicUrl; // This will be saved with the post, but no new image for the post itself
  File? _postImageFile; // Re-added for the post image
  bool _isUploadingPostImage = false; // Re-added for upload indicator

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (_currentUserId != null) {
      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUserId)
                .get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          setState(() {
            _currentUsername = data['username'];
            _currentUserProfilePicUrl =
                data['profilePicUrl']; // Still fetch PFP to save with post
          });
        }
      } catch (e) {
        print("Error fetching user data: $e");
      }
    }
  }

  Future<void> _pickPostImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Adjust quality as needed
      );
      if (pickedFile != null) {
        setState(() {
          _postImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Error picking post image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to pick image for post.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _createPost() async {
    if (_captionController.text.trim().isEmpty) {
      // Condition changed: only caption matters now
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a caption.')));
      return;
    }
    if (_currentUserId == null || _currentUsername == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not verify user. Please try again.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploadingPostImage = _postImageFile != null;
    });

    String? imageUrl; // To store the uploaded image URL

    try {
      if (_postImageFile != null) {
        String fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_postImageFile!.path.split('/').last}';
        firebase_storage.Reference ref = firebase_storage
            .FirebaseStorage
            .instance
            .ref()
            .child('post_images')
            .child(_currentUserId!) // Store under user's ID for organization
            .child(fileName);

        await ref.putFile(_postImageFile!);
        imageUrl = await ref.getDownloadURL();
      }

      Map<String, dynamic> postData = {
        'caption': _captionController.text.trim(),
        'userId': _currentUserId,
        'username': _currentUsername,
        'profilePicUrl': _currentUserProfilePicUrl ?? '', // Creator's PFP URL
        'imageUrl': imageUrl, // This will be null if no image was picked
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'commentCount': 0, // Initialize comment count
      };
      // Remove imageUrl from map if it's null, to not store a null field explicitly
      // Or, your backend/rules can handle null imageUrls if that's preferred.
      // For this example, we'll let it be null if no image.
      // if (imageUrl == null) {
      //   postData.remove('imageUrl');
      // }

      await FirebaseFirestore.instance.collection('posts').add(postData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post created successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      print("Error creating post: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create post: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingPostImage = false;
        });
      }
    }
  }

  Widget _buildLabeledTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText ?? 'Enter $label',
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 14.0,
              horizontal: 12.0,
            ),
          ),
          validator: validator,
          textCapitalization: TextCapitalization.sentences,
        ),
      ],
    );
  }

  // Removed _getPostImageProvider method

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blueAccent[700]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Create Post',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          _isLoading
              ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
              : TextButton(
                onPressed: _createPost,
                child: Text(
                  'Post',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_isUploadingPostImage)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_postImageFile != null)
              Container(
                height: 200,
                margin: const EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  image: DecorationImage(
                    image: FileImage(_postImageFile!),
                    fit: BoxFit.cover,
                  ),
                ),
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                  onPressed: () {
                    setState(() {
                      _postImageFile = null;
                    });
                  },
                ),
              )
            else
              TextButton.icon(
                icon: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: primaryColor,
                  size: 28,
                ),
                label: Text(
                  'Add Image (Optional)',
                  style: TextStyle(color: primaryColor, fontSize: 16),
                ),
                onPressed: _pickPostImage,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                    side: BorderSide(color: Colors.grey[300]!),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _buildLabeledTextField(
              controller: _captionController,
              label: 'Caption',
              hintText: 'Write a caption...',
              maxLines: 5, // Caption can be longer now as it's the main content
              validator:
                  (value) =>
                      (value == null || value.isEmpty)
                          ? 'Please enter a caption.'
                          : null,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
