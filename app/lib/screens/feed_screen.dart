import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/secure_screen.dart';
import '../widgets/post_card.dart';
import 'create_post_screen.dart';

/// The dashboard: an Instagram-style feed of every post, newest first.
///
/// Screenshots are blocked while this screen is open (Android FLAG_SECURE)
/// and re-enabled when it closes, so login and settings stay capturable.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<Post> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
    _load();
  }

  @override
  void dispose() {
    // The flag lives on the Activity, so it must be cleared or every other
    // screen inherits the screenshot block.
    SecureScreen.disable();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.getFeed();

    if (!mounted) return;

    setState(() {
      _loading = false;
      if (result.ok) {
        _posts = result.posts;
        _error = null;
      } else {
        _error = result.message;
      }
    });
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
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : _posts.isEmpty
                      ? const _EmptyState()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _posts.length,
                          itemBuilder: (context, index) {
                            final post = _posts[index];
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

/// Shown when the feed request fails. Wrapped in a scrollable so pull to
/// refresh still works with nothing on screen.
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Icon(Icons.cloud_off, size: 56, color: scheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Center(
          child: Text(
            "Couldn't load the feed",
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }
}

/// Shown when the request succeeded but nobody has posted yet.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
        Icon(Icons.photo_camera_outlined,
            size: 56, color: scheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'No posts yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Tap + to share the first one',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
