import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:sist_link1/screens/chat/group_info_screen.dart';
import 'package:sist_link1/screens/profile/profile_screen.dart'; // Import ProfileScreen

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName; // Group name or other user's name
  final bool isGroup;
  final String? otherUserId; // Add for 1-to-1 chat status

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
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final String? _currentUsername =
      FirebaseAuth.instance.currentUser?.displayName;
  bool _isSending = false;

  String _formatAppBarLastSeen(Timestamp? timestamp, bool isOnline) {
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

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _currentUserId == null) return;
    final senderUsername = _currentUsername ?? 'Unknown User';
    setState(() {
      _isSending = true;
      _messageController.clear();
    });
    try {
      final messageData = {
        'senderId': _currentUserId,
        'senderUsername': senderUsername,
        'text': messageText,
        'timestamp': FieldValue.serverTimestamp(),
      };
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
            'lastMessageTimestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      print("Error sending message: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Widget _buildAppBarTitle() {
    if (widget.isGroup || widget.otherUserId == null) {
      return Text(widget.chatName);
    }
    // For 1-to-1 chat, make title tappable to view profile
    return InkWell(
      onTap: () {
        if (widget.otherUserId != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: widget.otherUserId!),
            ),
          );
        }
      },
      child: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(widget.otherUserId)
                .snapshots(),
        builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
          String statusText = 'Offline';
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            final bool isOnline = userData['isOnline'] ?? false;
            final Timestamp? lastSeen = userData['lastSeen'] as Timestamp?;
            statusText = _formatAppBarLastSeen(lastSeen, isOnline);
          }
          return Padding(
            // Add padding for better tap area and alignment
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.chatName),
                if (statusText.isNotEmpty)
                  Text(
                    statusText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _buildAppBarTitle(),
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
              tooltip: 'Group Info',
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      widget.isGroup ? 'No messages yet.' : 'Say hello!',
                    ),
                  );
                }
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final messageData =
                        messages[index].data() as Map<String, dynamic>;
                    return _buildMessageBubble(messageData);
                  },
                );
              },
            ),
          ),
          _buildMessageInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> messageData) {
    final String text = messageData['text'] ?? '';
    final String senderId = messageData['senderId'] ?? '';
    final String senderUsername = messageData['senderUsername'] ?? 'Unknown';
    final bool isMe = senderId == _currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (widget.isGroup && !isMe)
            Padding(
              padding: const EdgeInsets.only(left: 12.0, bottom: 2.0),
              child: Text(
                senderUsername,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color:
                      isMe
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Colors.grey[300],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft:
                        isMe
                            ? const Radius.circular(12)
                            : const Radius.circular(0),
                    bottomRight:
                        isMe
                            ? const Radius.circular(0)
                            : const Radius.circular(12),
                  ),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color:
                        isMe
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInputArea() {
    return Padding(
      padding: const EdgeInsets.all(
        8.0,
      ).copyWith(bottom: MediaQuery.of(context).padding.bottom + 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              enabled: !_isSending,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isSending ? null : _sendMessage,
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
