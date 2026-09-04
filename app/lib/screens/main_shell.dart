import 'package:flutter/material.dart';
import '../services/secure_screen.dart';
import 'create_post_screen.dart';
import 'feed_screen.dart';
import 'leaderboard_screen.dart';
import 'profile_screen.dart';

/// Holds the tabs: the feed (other people's posts), create, the
/// leaderboard, and the profile (your own posts).
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
  static const _feedIndex = 0;

  int _index = _feedIndex;

  // Bumping this makes the tabs refetch after a new post is created.
  int _refreshToken = 0;

  @override
  void initState() {
    super.initState();
    // The feed is the first tab, so the block starts on.
    SecureScreen.enable();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
  }

  /// FLAG_SECURE is set on the Activity, not per widget, so it has to be
  /// toggled as tabs change. It cannot live in the feed's initState and
  /// dispose: IndexedStack keeps every tab mounted, so those never fire
  /// on a tab switch and the block would stay on across the whole app.
  void _syncSecure(int tabIndex) {
    if (tabIndex == _feedIndex) {
      SecureScreen.enable();
    } else {
      SecureScreen.disable();
    }
  }

  Future<void> _openCreate() async {
    // The camera screen is pushed over the feed, so lift the block while
    // it is open, then restore it for whichever tab we land on.
    SecureScreen.disable();

    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreatePostScreen()),
    );

    if (!mounted) return;

    if (created == true) {
      setState(() {
        _refreshToken++;
        _index = 3; // land on the profile, where the new post lives
      });
    }
    _syncSecure(_index);
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
          LeaderboardScreen(key: ValueKey('board_$_refreshToken')),
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
            _syncSecure(i);
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
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Top',
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
