import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sist_link1/screens/home/home_screen.dart';
import 'package:sist_link1/screens/search/search_screen.dart';
import 'package:sist_link1/screens/events/event_list_screen.dart';
import 'package:sist_link1/screens/chat/chat_list_screen.dart';
import 'package:sist_link1/screens/create_post/create_post_screen.dart';
import 'package:sist_link1/screens/profile/profile_screen.dart';

class MobileScreenLayout extends StatefulWidget {
  const MobileScreenLayout({super.key});

  @override
  State<MobileScreenLayout> createState() => _MobileScreenLayoutState();
}

class _MobileScreenLayoutState extends State<MobileScreenLayout>
    with WidgetsBindingObserver {
  int _pageIndex = 0; // Tracks the selected tab index
  late PageController _pageController;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    WidgetsBinding.instance.addObserver(this);
    _updateUserOnlineStatus(true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (_currentUserId == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _updateUserOnlineStatus(true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _updateUserOnlineStatus(false);
        break;
    }
  }

  Future<void> _updateUserOnlineStatus(bool isOnline) async {
    if (_currentUserId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .update({
              'isOnline': isOnline,
              'lastSeen': FieldValue.serverTimestamp(),
            });
      } catch (e) {
        // Error updating status
      }
    }
  }

  void _onNavigationTap(int tappedItemIndex) {
    _pageController.jumpToPage(tappedItemIndex);
  }

  void _onPageChanged(int pageIndex) {
    setState(() {
      _pageIndex = pageIndex;
    });
  }

  List<Widget> get _pages {
    if (_currentUserId == null) {
      // Fallback, should be handled by AuthWrapper
      return [
        const HomeScreen(),
        const SearchScreen(),
        const EventListScreen(),
        const ChatListScreen(),
        const Scaffold(body: Center(child: Text("Profile requires User ID"))),
      ];
    }
    return [
      const HomeScreen(), // Index 0
      const SearchScreen(), // Index 1
      const EventListScreen(), // Index 2
      const ChatListScreen(), // Index 3
      ProfileScreen(userId: _currentUserId!), // Index 4
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        physics: const NeverScrollableScrollPhysics(), // Disable direct swiping
        children: _pages,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        child: const Icon(Icons.add),
        tooltip: 'Create Post',
      ),
      // Standard BottomNavigationBar for 5 tabs
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _pageIndex,
        onTap: _onNavigationTap,
        type: BottomNavigationBarType.fixed, // Ensures all labels are visible
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chats',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
