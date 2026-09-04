import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';
import 'server_screen.dart';
import 'login_screen.dart';

/// The dashboard: an Instagram-style feed of posts.
///
/// The backend has no `GET /posts/feed` yet, so this falls back to mock
/// posts and shows a banner saying so. When the endpoint exists, the
/// fallback disappears on its own — no code change needed here.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = [];
  bool _loading = true;
  bool _usingMockData = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.getFeed();

    if (!mounted) return;

    if (result.ok) {
      setState(() {
        _posts = result.posts;
        _usingMockData = false;
        _loading = false;
      });
    } else {
      // No feed endpoint yet (404), or the server is unreachable.
      // Show the design with placeholder posts either way.
      setState(() {
        _posts = MockPosts.sample;
        _usingMockData = true;
        _error = result.message;
        _loading = false;
      });
    }
  }

  /// Optimistic like: flip the UI immediately, then call the API and roll
  /// back if it fails. Waiting for the round trip makes the heart feel laggy.
  Future<void> _toggleLike(Post post) async {
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;

    final wasLiked = post.isLiked;

    setState(() {
      _posts[index] = post.copyWith(
        isLiked: !wasLiked,
        likeCount: wasLiked ? post.likeCount - 1 : post.likeCount + 1,
      );
    });

    if (_usingMockData) return; // nothing real to call

    final result = wasLiked
        ? await ApiService.unlikePost(post.id)
        : await ApiService.likePost(post.id);

    if (!mounted) return;

    // 409 "already liked" and 404 "like not found" mean the server and the
    // UI simply disagreed — the end state is what we wanted, so keep it.
    final acceptable = result.ok ||
        result.statusCode == 409 ||
        result.statusCode == 404;

    if (!acceptable) {
      setState(() => _posts[index] = post); // roll back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  Future<void> _logout() async {
    await ApiService.clearToken();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NaturalBeauty',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'New post',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CreatePostScreen()),
              );
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.dns_outlined),
            tooltip: 'Server settings',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ServerScreen()),
              );
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _posts.length + (_usingMockData ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_usingMockData && index == 0) {
                    return _MockBanner(error: _error);
                  }
                  final post = _posts[index - (_usingMockData ? 1 : 0)];
                  return PostCard(
                    post: post,
                    onLikeToggle: () => _toggleLike(post),
                  );
                },
              ),
            ),
    );
  }
}

/// Explains that these posts are placeholders, and what the server needs.
class _MockBanner extends StatelessWidget {
  final String? error;

  const _MockBanner({this.error});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined,
                  size: 20, color: scheme.onTertiaryContainer),
              const SizedBox(width: 8),
              Text(
                'Showing sample posts',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The backend has no GET /posts/feed endpoint yet, so this is '
            'placeholder data to show the layout. Real posts appear here '
            'automatically once the endpoint exists.',
            style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 12),
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(
                color: scheme.onTertiaryContainer.withValues(alpha: 0.75),
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
