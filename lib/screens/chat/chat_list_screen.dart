import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sist_link1/screens/chat/chat_screen.dart';
import 'package:sist_link1/screens/chat/create_group_screen.dart';
import 'package:intl/intl.dart'; // For date formatting

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  String _formatChatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final DateTime messageTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final Duration difference = now.difference(messageTime);

    if (difference.inDays == 0 && now.day == messageTime.day) {
      return DateFormat.jm().format(messageTime);
    } else if (difference.inDays == 1 ||
        (difference.inDays == 0 && now.day != messageTime.day)) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat.EEEE().format(messageTime);
    } else {
      return DateFormat.yMd().format(messageTime);
    }
  }

  String _formatLastSeen(Timestamp? timestamp, bool isOnline) {
    if (isOnline) return 'Online';
    if (timestamp == null) return 'Offline';
    // Simple last seen, can be expanded later like in ProfileScreen
    final DateTime lastSeenTime = timestamp.toDate();
    final Duration difference = DateTime.now().difference(lastSeenTime);

    if (difference.inMinutes < 60)
      return 'Last seen ${difference.inMinutes}m ago';
    if (difference.inHours < 24) return 'Last seen ${difference.inHours}h ago';
    return 'Last seen ${DateFormat.yMd().format(lastSeenTime)}';
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Colors.blueAccent[700]!;
    final Color subtleTextColor = Colors.grey[600]!;

    if (_currentUserId == null) {
      return const Scaffold(body: Center(child: Text("Please log in.")));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Chats',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: Icon(Icons.group_add_outlined, color: primaryColor),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const CreateGroupScreen(),
                ),
              );
            },
            tooltip: 'Create Group Chat',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('chats')
                .where('users', arrayContains: _currentUserId)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("Error fetching chats: ${snapshot.error}");
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'No chats yet. Start a new conversation!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          List<DocumentSnapshot> chats = snapshot.data!.docs;
          chats.sort((a, b) {
            Timestamp? tsA =
                (a.data() as Map<String, dynamic>)['lastMessageTimestamp']
                    as Timestamp?;
            Timestamp? tsB =
                (b.data() as Map<String, dynamic>)['lastMessageTimestamp']
                    as Timestamp?;
            if (tsA == null && tsB == null) return 0;
            if (tsA == null) return 1;
            if (tsB == null) return -1;
            return tsB.compareTo(tsA);
          });

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder:
                (context, index) =>
                    Divider(height: 0.5, indent: 70, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final chatDoc = chats[index];
              final chatData = chatDoc.data() as Map<String, dynamic>;
              final bool isGroup = chatData['isGroup'] ?? false;
              String chatName = 'Chat';
              String otherUserId = '';

              if (isGroup) {
                chatName = chatData['groupName'] ?? 'Group Chat';
                String? groupPhotoUrl = chatData['groupPhotoUrl'] as String?;
                Widget avatarWidget = CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.grey[300],
                  backgroundImage:
                      (groupPhotoUrl != null && groupPhotoUrl.isNotEmpty)
                          ? NetworkImage(groupPhotoUrl)
                          : null,
                  child:
                      (groupPhotoUrl == null || groupPhotoUrl.isEmpty)
                          ? Icon(Icons.group, size: 25, color: Colors.grey[700])
                          : null,
                );
                return ListTile(
                  leading: avatarWidget,
                  title: Text(
                    chatName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    chatData['lastMessage'] ?? 'Group created',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: subtleTextColor, fontSize: 13),
                  ),
                  trailing: Text(
                    _formatChatTimestamp(
                      chatData['lastMessageTimestamp'] as Timestamp?,
                    ),
                    style: TextStyle(color: subtleTextColor, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (context) => ChatScreen(
                              chatId: chatDoc.id,
                              chatName: chatName,
                              isGroup: true,
                            ),
                      ),
                    );
                  },
                );
              } else {
                // 1-on-1 Chat
                List<dynamic> userIds = chatData['users'] ?? [];
                Map<String, dynamic> userNames = chatData['userNames'] ?? {};
                for (String userId in userIds) {
                  if (userId != _currentUserId) {
                    otherUserId = userId;
                    chatName = userNames[userId] ?? 'User';
                    break;
                  }
                }

                return FutureBuilder<DocumentSnapshot>(
                  future:
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUserId)
                          .get(),
                  builder: (context, userSnapshot) {
                    Widget leadingAvatar;
                    String subtitleText;

                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      leadingAvatar = CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey[300],
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                      subtitleText = 'Loading...';
                    } else if (!userSnapshot.hasData ||
                        !userSnapshot.data!.exists) {
                      leadingAvatar = CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.grey[300],
                        child: Icon(
                          Icons.person,
                          size: 25,
                          color: Colors.grey[700],
                        ),
                      );
                      subtitleText =
                          chatData['lastMessage'] ?? 'Chat started'; // Fallback
                    } else {
                      final otherUserData =
                          userSnapshot.data!.data() as Map<String, dynamic>;
                      final String? picUrl =
                          otherUserData['profilePicUrl'] as String?;
                      final bool isOnline = otherUserData['isOnline'] ?? false;
                      final Timestamp? lastSeen =
                          otherUserData['lastSeen'] as Timestamp?;

                      leadingAvatar = Stack(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundColor: Colors.grey[300],
                            backgroundImage:
                                (picUrl != null && picUrl.isNotEmpty)
                                    ? NetworkImage(picUrl)
                                    : null,
                            child:
                                (picUrl == null || picUrl.isEmpty)
                                    ? Icon(
                                      Icons.person,
                                      size: 25,
                                      color: Colors.grey[700],
                                    )
                                    : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color:
                                    isOnline
                                        ? Colors.greenAccent[400]
                                        : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                      subtitleText = _formatLastSeen(lastSeen, isOnline);
                    }

                    return ListTile(
                      leading: leadingAvatar,
                      title: Text(
                        chatName,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        subtitleText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: subtleTextColor, fontSize: 13),
                      ),
                      trailing: Text(
                        _formatChatTimestamp(
                          chatData['lastMessageTimestamp'] as Timestamp?,
                        ),
                        style: TextStyle(color: subtleTextColor, fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (context) => ChatScreen(
                                  chatId: chatDoc.id,
                                  chatName: chatName,
                                  isGroup: false,
                                  otherUserId: otherUserId,
                                ),
                          ),
                        );
                      },
                    );
                  },
                );
              }
            },
          );
        },
      ),
    );
  }
}
