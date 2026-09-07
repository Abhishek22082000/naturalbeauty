import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
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

  bool get _accountPrivate => (_user?['is_private'] ?? 0) == 1;

  final _picker = ImagePicker();
  bool _savingAvatar = false;

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

  /// Take, pick or remove the profile photo.
  Future<void> _changeAvatar() async {
    final hasOne = (_user?['profile_picture']?.toString() ?? '').isNotEmpty;

    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            if (hasOne)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () => Navigator.pop(context, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'remove') {
      await _removeAvatar();
    } else {
      await _pickAvatar(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;

      // Square and circle-framed: the avatar is always shown in a circle,
      // so cropping to anything else would just be cropped again on render.
      final scheme = Theme.of(context).colorScheme;
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop photo',
            toolbarColor: scheme.surface,
            toolbarWidgetColor: scheme.onSurface,
            statusBarColor: scheme.surface,
            activeControlsWidgetColor: scheme.primary,
            backgroundColor: Colors.black,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
            // The avatar always renders in a circle, so frame it as one.
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: 'Crop photo',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            rotateButtonsHidden: true,
            rotateClockwiseButtonHidden: true,
            cropStyle: CropStyle.circle,
          ),
        ],
      );

      if (cropped == null || !mounted) return;

      setState(() => _savingAvatar = true);
      final result = await ApiService.setProfilePicture(File(cropped.path));

      if (!mounted) return;
      setState(() {
        _savingAvatar = false;
        if (result.ok) {
          _user = {
            ..._user!,
            'profile_picture': result.data['profile_picture'],
          };
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(result.ok ? 'Profile photo updated' : result.message),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingAvatar = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open $e')));
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _savingAvatar = true);
    final result = await ApiService.removeProfilePicture();

    if (!mounted) return;
    setState(() {
      _savingAvatar = false;
      if (result.ok) {
        _user = {..._user!, 'profile_picture': null};
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result.ok ? 'Photo removed' : result.message)),
    );
  }

  /// Flips the whole account between private and public.
  ///
  /// The account setting is the stricter of the two: while it is on, even
  /// a post marked public stays hidden from everyone else.
  Future<void> _toggleAccountPrivacy() async {
    final next = !_accountPrivate;
    final result = await ApiService.setAccountPrivacy(next);

    if (!mounted) return;

    if (result.ok) {
      setState(() => _user = {..._user!, 'is_private': next ? 1 : 0});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next
              ? 'Account is private — only you can see your posts'
              : 'Account is public'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  /// Flips one post between private and public.
  Future<void> _togglePostPrivacy(Post post) async {
    final next = !post.isPrivate;
    final index = _posts.indexWhere((p) => p.id == post.id);
    if (index == -1) return;

    // Optimistic: the lock badge flips at once, and rolls back on failure.
    setState(() => _posts[index] = post.copyWith(isPrivate: next));

    final result = await ApiService.setPostPrivacy(post.id, next);

    if (!mounted) return;

    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next ? 'Post is private' : 'Post is public')),
      );
    } else {
      setState(() => _posts[index] = post);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
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
        title: Text(
          _displayName,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: false,
        scrolledUnderElevation: 0.5,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu),
            tooltip: 'Menu',
            onSelected: (value) async {
              if (value == 'privacy') {
                _toggleAccountPrivacy();
              } else if (value == 'server') {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ServerScreen()),
                );
                _load();
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'privacy',
                child: ListTile(
                  leading: Icon(
                      _accountPrivate ? Icons.lock : Icons.lock_open_outlined),
                  title: Text(_accountPrivate
                      ? 'Account is private'
                      : 'Account is public'),
                  subtitle: Text(
                    _accountPrivate ? 'Tap to make public' : 'Tap to make private',
                    style: const TextStyle(fontSize: 11),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'server',
                child: ListTile(
                  leading: Icon(Icons.dns_outlined),
                  title: Text('Server settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
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
                  if (_accountPrivate)
                    SliverToBoxAdapter(child: _privateBanner(context)),
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
                    ),
                  if (_error == null && _posts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: Row(
                          children: [
                            Icon(Icons.grid_on,
                                size: 15,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            const SizedBox(width: 7),
                            Text(
                              'Posts',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_error == null && _posts.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
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
                            onTogglePrivacy: () =>
                                _togglePostPrivacy(_posts[index]),
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
              GestureDetector(
                onTap: _savingAvatar ? null : _changeAvatar,
                child: Stack(
                  clipBehavior: Clip.none,
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
                          // The key forces a reload after upload; without
                          // it Flutter serves the cached image for the old
                          // URL and the change appears not to have worked.
                          key: ValueKey(avatar ?? 'none'),
                          backgroundImage:
                              (avatar != null && avatar.isNotEmpty)
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

                    if (_savingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                          child: const Center(
                            child: SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary,
                          border:
                              Border.all(color: scheme.surface, width: 2),
                        ),
                        child: Icon(Icons.camera_alt,
                            size: 13, color: scheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest
                        .withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _stat(context, '$postCount', 'POSTS'),
                      _statDivider(context),
                      _stat(context, '0', 'FOLLOWERS'),
                      _statDivider(context),
                      _stat(context, '0', 'FOLLOWING'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // The username reads as the heading here; the app bar carries
          // the full name.
          Row(
            children: [
              Text(
                '@$username',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if ((_user?['is_verified'] ?? 0) == 1) ...[
                const SizedBox(width: 4),
                const Icon(Icons.verified,
                    size: 14, color: Color(0xFF3897F0)),
              ],
              const Spacer(),
              _PrivacyPill(
                isPrivate: _accountPrivate,
                onTap: _toggleAccountPrivacy,
              ),
            ],
          ),

          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              bio,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
            ),
          ],
        ],
      ),
    );
  }

  Widget _privateBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Only you can see these posts, and you are hidden from the '
              'leaderboard.',
              style: TextStyle(
                  fontSize: 12, color: scheme.onTertiaryContainer),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                letterSpacing: 0.2,
              ),
        ),
      ],
    );
  }

  /// A thin vertical rule between the stat columns.
  Widget _statDivider(BuildContext context) => Container(
        width: 1,
        height: 26,
        color: Theme.of(context).colorScheme.outlineVariant,
      );

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

/// A small tappable pill showing whether the account is public or private.
class _PrivacyPill extends StatelessWidget {
  final bool isPrivate;
  final VoidCallback onTap;

  const _PrivacyPill({required this.isPrivate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isPrivate ? scheme.tertiaryContainer : scheme.surfaceContainerHighest;
    final fg = isPrivate ? scheme.onTertiaryContainer : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isPrivate ? Icons.lock : Icons.public, size: 12, color: fg),
              const SizedBox(width: 5),
              Text(
                isPrivate ? 'Private' : 'Public',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
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
  final VoidCallback onTogglePrivacy;
  final bool deleting;

  const _GridTile({
    required this.post,
    required this.onTap,
    required this.onDelete,
    required this.onTogglePrivacy,
    this.deleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = post.imageUrl.startsWith('http')
        ? post.imageUrl
        : '${Config.baseUrl}${post.imageUrl}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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

            // A private post is dimmed, so the grid shows at a glance
            // which posts are hidden.
            if (post.isPrivate)
              Container(color: Colors.black.withValues(alpha: 0.38)),

            if (post.isPrivate)
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 11, color: Colors.white),
                      SizedBox(width: 3),
                      Text(
                        'Private',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // One menu rather than two loose buttons: at grid size the
            // icons crowded each other and were easy to mis-tap.
            Positioned(
              top: 2,
              right: 2,
              child: deleting
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : _TileMenu(
                      post: post,
                      onDelete: onDelete,
                      onTogglePrivacy: onTogglePrivacy,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The per-tile overflow menu: privacy, then delete.
class _TileMenu extends StatelessWidget {
  final Post post;
  final VoidCallback onDelete;
  final VoidCallback onTogglePrivacy;

  const _TileMenu({
    required this.post,
    required this.onDelete,
    required this.onTogglePrivacy,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Post options',
      padding: EdgeInsets.zero,
      // A dark pill behind the dots so they read on a pale photo.
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.more_vert, size: 16, color: Colors.white),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      onSelected: (value) {
        if (value == 'privacy') {
          onTogglePrivacy();
        } else if (value == 'delete') {
          onDelete();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'privacy',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              post.isPrivate ? Icons.public : Icons.lock_outline,
            ),
            title: Text(post.isPrivate ? 'Make public' : 'Make private'),
            subtitle: Text(
              post.isPrivate
                  ? 'Everyone will see this'
                  : 'Only you will see this',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline, color: Colors.red),
            title: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ),
      ],
    );
  }
}
