import 'package:flutter/material.dart';
import '../config.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'post_detail_screen.dart';
import 'server_screen.dart';

/// The logged-in user's own profile: their details and a grid of their posts.
///
/// Own posts do not appear in the feed — this is where they live.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _user;
  List<Post> _posts = [];
  bool _loading = true;
  String? _error;

  /// Posts currently being deleted, so each tile can show its own spinner.
  final Set<int> _deletingIds = {};

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

    final profile = await ApiService.getMe();

    if (!mounted) return;

    if (!profile.ok) {
      setState(() {
        _loading = false;
        _error = profile.message;
      });
      return;
    }

    final user = profile.data['user'] as Map<String, dynamic>?;
    final userId = user?['id'];

    final feed = userId != null
        ? await ApiService.getUserPosts(userId is int ? userId : 0)
        : null;

    if (!mounted) return;

    setState(() {
      _loading = false;
      _user = user;
      _posts = feed?.posts ?? [];
    });
  }

  /// Confirms, then deletes. The server checks ownership regardless, so a
  /// post that is not yours comes back 404 rather than being removed.
  Future<void> _deletePost(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deletingIds.add(post.id));

    final result = await ApiService.deletePost(post.id);

    if (!mounted) return;

    if (result.ok) {
      setState(() {
        _deletingIds.remove(post.id);
        _posts.removeWhere((p) => p.id == post.id);
        // Keep the header count in step without a second round trip.
        final current = _user?['post_count'];
        if (current is int && current > 0) {
          _user = {..._user!, 'post_count': current - 1};
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post deleted')),
      );
    } else {
      setState(() => _deletingIds.remove(post.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }

  /// The name shown in the app bar: full name if set, else the username.
  String get _displayName {
    final full = _user?['full_name']?.toString();
    if (full != null && full.trim().isNotEmpty) return full;
    return _user?['username']?.toString() ?? 'Profile';
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 19,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if ((_user?['is_verified'] ?? 0) == 1) ...[
                  const SizedBox(width: 5),
                  const Icon(Icons.verified,
                      size: 16, color: Color(0xFF3897F0)),
                ],
              ],
            ),
            if (_user?['username'] != null)
              Text(
                '@${_user!['username']}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        centerTitle: false,
        scrolledUnderElevation: 0.5,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onSelected: (value) async {
              if (value == 'server') {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ServerScreen()),
                );
                _load();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'server',
                child: ListTile(
                  leading: Icon(Icons.dns_outlined),
                  title: Text('Server settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Log out'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _header(context)),
                  if (_error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _message(
                        icon: Icons.cloud_off,
                        title: "Couldn't load profile",
                        detail: _error!,
                      ),
                    )
                  else if (_posts.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _message(
                        icon: Icons.photo_camera_outlined,
                        title: 'No posts yet',
                        detail: 'Tap Create below to share your first photo',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _GridTile(
                            post: _posts[index],
                            deleting:
                                _deletingIds.contains(_posts[index].id),
                            onDelete: () => _deletePost(_posts[index]),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PostDetailScreen(post: _posts[index]),
                                ),
                              );
                              _load();
                            },
                          ),
                          childCount: _posts.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final username = _user?['username']?.toString() ?? '';
    final bio = _user?['bio']?.toString();
    final avatar = _user?['profile_picture']?.toString();
    final postCount = _user?['post_count'] ?? _posts.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.tertiary],
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surface,
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: scheme.primaryContainer,
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? NetworkImage(
                            avatar.startsWith('http')
                                ? avatar
                                : '${Config.baseUrl}$avatar',
                          )
                        : null,
                    child: (avatar == null || avatar.isEmpty)
                        ? Text(
                            username.isNotEmpty
                                ? username[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w700,
                              color: scheme.onPrimaryContainer,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _stat(context, '$postCount', 'posts')),
                    Expanded(child: _stat(context, '0', 'followers')),
                    Expanded(child: _stat(context, '0', 'following')),
                  ],
                ),
              ),
            ],
          ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(bio, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String detail,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: scheme.onSurfaceVariant),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
      ),
    );
  }
}

/// One square thumbnail in the profile grid.
class _GridTile extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final bool deleting;

  const _GridTile({
    required this.post,
    required this.onTap,
    required this.onDelete,
    this.deleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = post.imageUrl.startsWith('http')
        ? post.imageUrl
        : '${Config.baseUrl}${post.imageUrl}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: GestureDetector(
      onTap: deleting ? null : onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Icon(
                Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          // Scrim behind the icon so it stays legible on a light photo.
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Colors.black54, Colors.transparent],
                ),
              ),
              child: deleting
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.white,
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Delete post',
                      onPressed: onDelete,
                    ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
