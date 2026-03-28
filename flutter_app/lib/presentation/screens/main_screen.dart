import 'package:flutter/material.dart';

import '../../data/stroll_repository.dart';
import '../widgets/bottom_nav_bar.dart';
import 'explore_screen.dart';
import 'feed_screen.dart';
import 'links_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.repository,
    this.startupError,
  });

  final StrollRepository repository;
  final String? startupError;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      FeedScreen(repository: widget.repository),
      LinksScreen(repository: widget.repository),
      ExploreScreen(repository: widget.repository),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.startupError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Failed to initialize STROLL runtime',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.startupError!,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          // Mobile Layout
          return Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
            bottomNavigationBar: BottomNavBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
            ),
          );
        } else {
          // Tablet / Desktop Layout
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  backgroundColor: const Color(0xFF261933),
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) => setState(() => _currentIndex = index),
                  selectedIconTheme: const IconThemeData(color: Colors.white, size: 28),
                  unselectedIconTheme: const IconThemeData(color: Color(0xFFAD92C9), size: 28),
                  selectedLabelTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  unselectedLabelTextStyle: const TextStyle(color: Color(0xFFAD92C9), fontSize: 12),
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.search_outlined),
                      selectedIcon: Icon(Icons.search),
                      label: Text('Discover'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: Text('Feed'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.chat_bubble_outline),
                      selectedIcon: Icon(Icons.chat_bubble),
                      label: Text('Chat'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Profile'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF362348)),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }
}
