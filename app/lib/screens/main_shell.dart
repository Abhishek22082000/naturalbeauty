import 'package:flutter/material.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
import 'profile_screen.dart';

/// Holds the tabs: the feed (other people's posts), create, and the
/// profile (your own posts).
///
/// Create is a bottom-nav destination rather than a real tab — selecting
/// it opens the camera screen and returns to whichever tab you were on,
/// the way Instagram's + works.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  // Bumping this makes the tabs refetch after a new post is created.
  int _refreshToken = 0;

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );
    if (created == true && mounted) {
      setState(() {
        _refreshToken++;
        _index = 2; // land on the profile, where the new post lives
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps both tabs alive, so switching back does not
      // refetch or lose scroll position.
      body: IndexedStack(
        index: _index == 1 ? 0 : _index, // create is not a real page
        children: [
          FeedScreen(key: ValueKey('feed_$_refreshToken')),
          const SizedBox.shrink(),
          ProfileScreen(key: ValueKey('profile_$_refreshToken')),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index == 1 ? 0 : _index,
        onDestinationSelected: (i) {
          if (i == 1) {
            _openCreate();
          } else {
            setState(() => _index = i);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_box_outlined),
            selectedIcon: Icon(Icons.add_box),
            label: 'Create',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
