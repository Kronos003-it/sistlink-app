import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io'; // Added for File
import 'package:image_picker/image_picker.dart'; // Added for ImagePicker
import 'package:firebase_storage/firebase_storage.dart'
    as firebase_storage; // Added for Firebase Storage
import 'package:sist_link1/screens/profile/profile_screen.dart';
import 'package:sist_link1/screens/chat/group_info_screen.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isGroup;
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.isGroup = false,
    this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  String? _currentUsername;
  bool _isUploading = false; // Added for upload indicator
  // String? _currentUserProfilePicUrl; // Not strictly needed for text-only sending

  @override
  void initState() {
    super.initState();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    if (_currentUser != null) {
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(_currentUser!.uid)
              .get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _currentUsername = data['username'];
            // _currentUserProfilePicUrl = data['profilePicUrl'];
          });
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    final String messageText = _messageController.text.trim();
    if (messageText.isEmpty) {
      return;
    }
    if (_currentUser == null || _currentUsername == null) return;

    _messageController.clear();

    final messageData = {
      'senderId': _currentUser!.uid,
      'senderUsername': _currentUsername,
      'text': messageText,
      'type': 'text',
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
            'lastMessage': messageText,
            'lastMessageType': 'text',
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error sending text message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message.')),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    if (_isUploading) return;
    setState(() {
      _isUploading = true;
    });

    final ImagePicker picker = ImagePicker();
    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        String fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
        firebase_storage.Reference ref = firebase_storage
            .FirebaseStorage
            .instance
            .ref()
            .child('chat_images')
            .child(widget.chatId)
            .child(fileName);

        await ref.putFile(imageFile);
        String imageUrl = await ref.getDownloadURL();
        await _sendImageMessage(imageUrl);
      }
    } catch (e) {
      print("Error picking/uploading image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _sendImageMessage(String imageUrl) async {
    if (_currentUser == null || _currentUsername == null) return;

    final messageData = {
      'senderId': _currentUser!.uid,
      'senderUsername': _currentUsername,
      'imageUrl': imageUrl,
      'type': 'image',
      'timestamp': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(messageData);

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .update({
            'lastMessage': '📷 Image',
            'lastMessageType': 'image',
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error sending image message: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send image message.')),
        );
      }
    }
  }

  String _formatMessageTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    return DateFormat.jm().format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (widget.isGroup)
              const CircleAvatar(radius: 18, child: Icon(Icons.group, size: 20))
            else if (widget.otherUserId != null)
              FutureBuilder<DocumentSnapshot>(
                future:
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.otherUserId)
                        .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData &&
                      snapshot.data!.exists) {
                    final userData =
                        snapshot.data!.data() as Map<String, dynamic>;
                    final String? picUrl = userData['profilePicUrl'];
                    return CircleAvatar(
                      radius: 18,
                      backgroundImage:
                          (picUrl != null && picUrl.isNotEmpty)
                              ? NetworkImage(picUrl)
                              : null,
                      child:
                          (picUrl == null || picUrl.isEmpty)
                              ? const Icon(Icons.person, size: 20)
                              : null,
                    );
                  }
                  return const CircleAvatar(
                    radius: 18,
                    child: Icon(Icons.person, size: 20),
                  );
                },
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.chatName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (widget.isGroup)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => GroupInfoScreen(chatId: widget.chatId),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('chats')
                      .doc(widget.chatId)
                      .collection('messages')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(10.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                        messages[index].data() as Map<String, dynamic>;
                    final bool isMe =
                        messageData['senderId'] == _currentUser?.uid;
                    final String messageType = messageData['type'] ?? 'text';

                    Widget messageContent;
                    if (messageType == 'image') {
                      final String? imageUrl =
                          messageData['imageUrl'] as String?;
                      if (imageUrl != null && imageUrl.isNotEmpty) {
                        messageContent = ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: Image.network(
                            imageUrl,
                            width: MediaQuery.of(context).size.width * 0.6,
                            fit: BoxFit.cover,
                            loadingBuilder: (
                              BuildContext context,
                              Widget child,
                              ImageChunkEvent? loadingProgress,
                            ) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: MediaQuery.of(context).size.width * 0.6,
                                height: 150, // Placeholder height
                                color: Colors.grey[300],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
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
                                (context, error, stackTrace) => Container(
                                  width:
                                      MediaQuery.of(context).size.width * 0.6,
                                  height: 150,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                          ),
                        );
                      } else {
                        messageContent = const Text(
                          '[Image not available]',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        );
                      }
                    } else {
                      // Default to text
                      final String? text = messageData['text'] as String?;
                      messageContent = Text(
                        text ?? '',
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      );
                    }

                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                          vertical: 5.0,
                          horizontal: 8.0,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10.0,
                          horizontal: 14.0,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isMe ? Colors.blueAccent[700] : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16.0),
                            topRight: const Radius.circular(16.0),
                            bottomLeft:
                                isMe
                                    ? const Radius.circular(16.0)
                                    : const Radius.circular(0),
                            bottomRight:
                                isMe
                                    ? const Radius.circular(0)
                                    : const Radius.circular(16.0),
                          ),
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                          children: [
                            if (!isMe && widget.isGroup)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  messageData['senderUsername'] ?? 'User',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        isMe ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ),
                            messageContent, // Display text or image
                            const SizedBox(height: 4.0),
                            Text(
                              _formatMessageTimestamp(
                                messageData['timestamp'] as Timestamp?,
                              ),
                              style: TextStyle(
                                fontSize: 10.0,
                                color: isMe ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          Padding(
            padding: const EdgeInsets.only(
              left: 12.0,
              right: 12.0,
              bottom: 20.0,
              top: 8.0,
            ),
            child: Row(
              children: [
                IconButton(
                  // Added attach image button
                  icon: Icon(
                    Icons.attach_file,
                    color: Theme.of(context).primaryColor,
                  ),
                  onPressed: _isUploading ? null : _pickAndSendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey[100],
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
                    maxLines: 5,
                    onSubmitted: (_) => _sendMessage(),
                    enabled: !_isUploading,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                  onPressed: _isUploading ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
