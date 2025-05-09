import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sist_link1/screens/chat/chat_screen.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String _selectedFilter = "All chats"; // For the filter chips

  // (Keep existing _formatLastMessageTimestamp and _buildUserStatusIndicator)
  String _formatLastMessageTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final DateTime now = DateTime.now();
    final DateTime messageTime = timestamp.toDate();
    if (now.difference(messageTime).inDays == 0) {
      return DateFormat.jm().format(messageTime); // e.g., 5:30 PM
    } else if (now.difference(messageTime).inDays == 1) {
      return "Yesterday";
    } else {
      return DateFormat.Md().format(messageTime); // e.g., 1/15
    }
  }

  Widget _buildUserStatusIndicator(String userId, {bool forAvatar = false}) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .snapshots(),
      builder: (context, AsyncSnapshot<DocumentSnapshot> userSnapshot) {
        if (!userSnapshot.hasData || userSnapshot.data?.data() == null) {
          return forAvatar
              ? const SizedBox.shrink()
              : Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                margin: const EdgeInsets.only(right: 8),
              );
        }
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final bool isOnline = userData['isOnline'] ?? false;

        Color statusColor = isOnline ? Colors.green : Colors.grey[400]!;
        if (forAvatar) {
          // Positioned on avatar
          return Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          );
        }
        // Default: leading dot
        return Container(
          margin: const EdgeInsets.only(right: 8.0),
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        );
      },
    );
  }

  Widget _buildFilterChips() {
    const filters = [
      "All chats",
      "Personal",
      "Work",
      "Groups",
    ]; // "Work" is from mockup, not implemented
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children:
              filters.map((filter) {
                bool isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (bool selected) {
                      if (selected) {
                        setState(() => _selectedFilter = filter);
                        // TODO: Implement actual filtering logic if this were functional
                      }
                    },
                    selectedColor: Colors.blueAccent[700],
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    backgroundColor: Colors.grey[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Recent Chats",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(child: Text("Please log in.")),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Recent Chats',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.grey[700]),
            onPressed: () {
              // TODO: Implement chat search functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chat search not implemented yet.'),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('chats')
                      .where('users', arrayContains: _currentUserId)
                      .orderBy('lastMessageTimestamp', descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No chats yet.'));
                }

                final chats = snapshot.data!.docs;

                return ListView.separated(
                  itemCount: chats.length,
                  separatorBuilder:
                      (context, index) => Divider(
                        height: 1,
                        indent: 70,
                        endIndent: 16,
                        color: Colors.grey[200],
                      ),
                  itemBuilder: (context, index) {
                    final chatData =
                        chats[index].data() as Map<String, dynamic>;
                    final String chatId = chats[index].id;
                    final bool isGroup = chatData['isGroup'] ?? false;
                    final List<dynamic> users = chatData['users'] ?? [];
                    final Map<String, dynamic> userNames =
                        chatData['userNames'] ?? {};
                    final String lastMessage =
                        chatData['lastMessage'] ?? 'No messages yet.';
                    final Timestamp? lastTimestamp =
                        chatData['lastMessageTimestamp'];

                    String chatName = 'Unknown Chat';
                    String otherUserIdForStatus = '';
                    Widget avatarWidget;

                    if (isGroup) {
                      chatName = chatData['groupName'] ?? 'Group Chat';
                      avatarWidget = CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: const Icon(Icons.group, color: Colors.white),
                      );
                    } else if (users.length == 2) {
                      otherUserIdForStatus = users.firstWhere(
                        (id) => id != _currentUserId,
                        orElse: () => '',
                      );
                      if (otherUserIdForStatus.isNotEmpty) {
                        chatName = userNames[otherUserIdForStatus] ?? 'Chat';
                      }
                      avatarWidget = Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.grey[300],
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                            ), // Placeholder
                          ),
                          if (otherUserIdForStatus.isNotEmpty)
                            _buildUserStatusIndicator(
                              otherUserIdForStatus,
                              forAvatar: true,
                            ),
                        ],
                      );
                    } else {
                      avatarWidget = CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: const Icon(
                          Icons.help_outline,
                          color: Colors.white,
                        ),
                      );
                    }

                    // Placeholder for unread count
                    final int unreadCount =
                        (index % 3 == 0 && lastMessage.isNotEmpty)
                            ? (index + 1) % 5
                            : 0;

                    return ListTile(
                      leading: avatarWidget,
                      title: Text(
                        chatName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatLastMessageTimestamp(lastTimestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent[700],
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (context) => ChatScreen(
                                  chatId: chatId,
                                  chatName: chatName,
                                  isGroup: isGroup,
                                  otherUserId:
                                      isGroup ? null : otherUserIdForStatus,
                                ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
