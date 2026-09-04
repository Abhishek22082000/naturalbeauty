import 'package:flutter/material.dart';
import '../config.dart';
import '../models/post.dart';

/// One post in the feed: author row, image, action buttons, likes, caption.
class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onLikeToggle;

  const PostCard({super.key, required this.post, this.onLikeToggle});

  /// Post images come back as server-relative paths ("/uploads/posts/x.jpg"),
  /// so they need the base URL prepended.
  String get _fullImageUrl {
    if (post.imageUrl.startsWith('http')) return post.imageUrl;
    return '${Config.baseUrl}${post.imageUrl}';
  }

  String? get _fullAvatarUrl {
    final p = post.profilePicture;
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    return '${Config.baseUrl}$p';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------------------------------------------- author row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              _Avatar(url: _fullAvatarUrl, username: post.username),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            post.username,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (post.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            size: 15,
                            color: Color(0xFF3897F0),
                          ),
                        ],
                      ],
                    ),
                    if (post.location != null && post.location!.isNotEmpty)
                      Text(
                        post.location!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // -------------------------------------------------------- image
        GestureDetector(
          onDoubleTap: onLikeToggle,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              width: double.infinity,
              color: scheme.surfaceContainerHighest,
              child: Image.network(
                _fullImageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stack) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 40,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Image unavailable',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ------------------------------------------------------ actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(
                onPressed: onLikeToggle,
                icon: Icon(
                  post.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: post.isLiked ? Colors.red : null,
                ),
                tooltip: post.isLiked ? 'Unlike' : 'Like',
              ),
              const Spacer(),
            ],
          ),
        ),

        // ------------------------------------------- likes + caption
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.likeCount == 1 ? '1 like' : '${post.likeCount} likes',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (post.caption != null && post.caption!.isNotEmpty) ...[
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium,
                    children: [
                      TextSpan(
                        text: '${post.username} ',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: post.caption),
                    ],
                  ),
                ),
              ],
              if (post.timeAgo.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  post.timeAgo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),

        Divider(height: 1, color: scheme.outlineVariant),
      ],
    );
  }
}

/// Circular avatar, falling back to the first letter of the username.
class _Avatar extends StatelessWidget {
  final String? url;
  final String username;

  const _Avatar({required this.url, required this.username});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (url == null) {
      return CircleAvatar(
        radius: 18,
        backgroundColor: scheme.primaryContainer,
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : '?',
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: scheme.surfaceContainerHighest,
      backgroundImage: NetworkImage(url!),
      onBackgroundImageError: (_, __) {},
    );
  }
}
