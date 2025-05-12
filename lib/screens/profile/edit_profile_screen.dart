import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io'; // Re-added
import 'package:image_picker/image_picker.dart'; // Re-added
import 'package:firebase_storage/firebase_storage.dart'
    as firebase_storage; // Re-added

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  bool _isLoading = false;
  String? _currentEmail = '';
  File? _pickedImageFile; // Re-added
  String? _currentProfilePicUrl; // Re-added
  bool _isUploadingPfp = false; // Re-added

  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (_currentUser != null) {
      setState(() => _isLoading = true);
      try {
        DocumentSnapshot userDoc =
            await FirebaseFirestore.instance
                .collection('users')
                .doc(_currentUser!.uid)
                .get();
        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          _usernameController.text = data['username'] ?? '';
          _bioController.text = data['bio'] ?? '';
          _currentEmail = data['email'] ?? _currentUser!.email;
          _currentProfilePicUrl = data['profilePicUrl'] as String?; // Re-added
        } else {
          // Fallback if user document doesn't exist but user is authenticated
          _currentProfilePicUrl =
              _currentUser!.photoURL; // Get from Auth if available
          _usernameController.text = _currentUser!.displayName ?? '';
          _currentEmail = _currentUser!.email ?? '';
        }
      } catch (e) {
        print("Error loading user data: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load profile data.')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 50, // Compress image
      );
      if (pickedFile != null) {
        setState(() {
          _pickedImageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      print("Error picking profile image: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to pick image.')));
      }
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true; // General loading for form processing
      _isUploadingPfp =
          _pickedImageFile != null; // Specific flag for PFP upload
    });

    String? newProfilePicUrl;

    try {
      if (_pickedImageFile != null) {
        // Upload new profile picture
        String fileName = 'profile.jpg'; // Consistent file name to overwrite
        firebase_storage.Reference ref = firebase_storage
            .FirebaseStorage
            .instance
            .ref()
            .child('profile_pics')
            .child(_currentUser!.uid)
            .child(fileName);

        await ref.putFile(_pickedImageFile!);
        newProfilePicUrl = await ref.getDownloadURL();
      }

      Map<String, dynamic> dataToUpdate = {
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newProfilePicUrl != null) {
        dataToUpdate['profilePicUrl'] = newProfilePicUrl;
      } else if (_pickedImageFile == null && _currentProfilePicUrl != null) {
        // If no new image was picked, but there was an existing one, keep it.
        // This case is implicitly handled by not adding profilePicUrl to dataToUpdate
        // unless a new one is uploaded. If you wanted to allow REMOVING a PFP,
        // you'd need a separate UI element and logic to set profilePicUrl to null or FieldValue.delete().
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .update(dataToUpdate);

      // Update display name and photoURL in Firebase Auth
      String newDisplayName = _usernameController.text.trim();
      bool authProfileUpdated = false;
      if (_currentUser!.displayName != newDisplayName) {
        await _currentUser?.updateDisplayName(newDisplayName);
        authProfileUpdated = true;
      }
      if (newProfilePicUrl != null &&
          _currentUser!.photoURL != newProfilePicUrl) {
        await _currentUser?.updatePhotoURL(newProfilePicUrl);
        authProfileUpdated = true;
      }

      if (authProfileUpdated) {
        await _currentUser?.reload();
        _currentUser = FirebaseAuth.instance.currentUser;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.of(context).pop(true); // Pop with true to indicate success
      }
    } catch (e) {
      print("Error updating profile: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        ),
      ],
    );
  }

  // Removed _getImageProvider method

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blueAccent[700]!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Edit Profile'),
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
              : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[300],
                              backgroundImage:
                                  _pickedImageFile != null
                                      ? FileImage(_pickedImageFile!)
                                      : (_currentProfilePicUrl != null &&
                                                  _currentProfilePicUrl!
                                                      .isNotEmpty
                                              ? NetworkImage(
                                                _currentProfilePicUrl!,
                                              )
                                              : null)
                                          as ImageProvider?,
                              child:
                                  (_pickedImageFile == null &&
                                          (_currentProfilePicUrl == null ||
                                              _currentProfilePicUrl!.isEmpty))
                                      ? Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.grey[600],
                                      )
                                      : null,
                            ),
                            Material(
                              color: primaryColor,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.hardEdge,
                              child: InkWell(
                                onTap: _pickProfileImage,
                                child: const Padding(
                                  padding: EdgeInsets.all(6.0),
                                  child: Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isUploadingPfp)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      const SizedBox(height: 32),
                      _buildLabeledTextField(
                        controller: _usernameController,
                        label: 'Username',
                        validator:
                            (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Please enter a username'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      _buildLabeledTextField(
                        controller: _bioController,
                        label: 'Bio',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Email",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14.0,
                              horizontal: 12.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Text(
                              _currentEmail ?? 'N/A',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _updateProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }
}
