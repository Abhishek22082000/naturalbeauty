import 'package:flutter/material.dart';
import '../config.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../services/secure_screen.dart';
import 'create_post_screen.dart';
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

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
    _load();
  }

  @override
  void dispose() {
    SecureScreen.disable();
    super.dispose();
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
        title: Text(
          _user?['username']?.toString() ?? 'Profile',
          style: const TextStyle(fontWeight: FontWeight.w600),
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
                        detail: 'Tap + to share your first photo',
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(2),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _GridTile(
                            post: _posts[index],
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
    final fullName = _user?['full_name']?.toString();
    final bio = _user?['bio']?.toString();
    final avatar = _user?['profile_picture']?.toString();
    final postCount = _user?['post_count'] ?? _posts.length;
    final isVerified = (_user?['is_verified'] ?? 0) == 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
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
                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                          color: scheme.onPrimaryContainer,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 28),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat(context, '$postCount', 'posts'),
                    _stat(context, '0', 'followers'),
                    _stat(context, '0', 'following'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (fullName != null && fullName.isNotEmpty)
                Text(
                  fullName,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              if (isVerified) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified, size: 15, color: Color(0xFF3897F0)),
              ],
            ],
          ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(bio, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
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
    );
  }
}

/// One square thumbnail in the profile grid.
class _GridTile extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const _GridTile({required this.post, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final url = post.imageUrl.startsWith('http')
        ? post.imageUrl
        : '${Config.baseUrl}${post.imageUrl}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
    );
  }
}
