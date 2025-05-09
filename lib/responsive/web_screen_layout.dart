import 'package:flutter/material.dart';
import 'package:sist_link1/screens/home/home_screen.dart';
import 'package:sist_link1/screens/search/search_screen.dart';
import 'package:sist_link1/screens/events/event_list_screen.dart';
import 'package:sist_link1/screens/chat/chat_list_screen.dart';
import 'package:sist_link1/screens/profile/profile_screen.dart';
import 'package:sist_link1/screens/create_post/create_post_screen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // To get current user ID for profile

class WebScreenLayout extends StatefulWidget {
  const WebScreenLayout({super.key});

  @override
  State<WebScreenLayout> createState() => _WebScreenLayoutState();
}

class _WebScreenLayoutState extends State<WebScreenLayout> {
  int _selectedIndex = 0; // For NavigationRail
  late PageController _pageController;
  String? _currentUserId;

  // Define the pages for the PageView
  final List<Widget> _pages = [
    const HomeScreen(),
    const SearchScreen(),
    const EventListScreen(),
    const ChatListScreen(),
    // ProfileScreen needs userId. We'll handle this.
    // For now, a placeholder or pass current user's ID.
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;

    // Add ProfileScreen with currentUserId if available
    if (_currentUserId != null) {
      _pages.add(ProfileScreen(userId: _currentUserId!));
    } else {
      // Fallback if user ID is not available (should not happen if user is logged in)
      _pages.add(
        const Scaffold(body: Center(child: Text("Profile requires login"))),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  void _onPageChanged(int index) {
    // This is needed if PageView swiping were enabled, but good practice to have
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            labelType:
                NavigationRailLabelType
                    .selected, // Show labels for selected, or .all
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Feed'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search_outlined),
                selectedIcon: Icon(Icons.search),
                label: Text('Search'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.event_outlined),
                selectedIcon: Icon(Icons.event),
                label: Text('Events'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: Text('Chats'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Profile'),
              ),
            ],
            leading: FloatingActionButton(
              // Example for "Create Post"
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CreatePostScreen(),
                  ),
                );
              },
              elevation: 0, // To look more integrated
              child: const Icon(Icons.add),
              tooltip: 'Create Post',
            ),
            // trailing: ... // Could add logout button here
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics:
                  const NeverScrollableScrollPhysics(), // Disable swiping between pages
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }
}
