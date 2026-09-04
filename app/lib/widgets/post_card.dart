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

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------------------------------------------------- author row
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              _Avatar(url: _fullAvatarUrl, username: post.username),
              const SizedBox(width: 11),
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
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.place_outlined,
                              size: 11, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              post.location!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (post.timeAgo.isNotEmpty)
                Text(
                  post.timeAgo,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11.5,
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

        // --------------------------------------- like + count + caption
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LikeButton(
                    isLiked: post.isLiked,
                    onTap: onLikeToggle,
                  ),
                  Text(
                    post.likeCount == 1 ? '1 like' : '${post.likeCount} likes',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (post.caption != null && post.caption!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(height: 1.35, color: scheme.onSurface),
                      children: [
                        TextSpan(
                          text: '${post.username} ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: post.caption),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

      ],
      ),
    );
  }
}

/// A heart that springs when tapped, so a like feels like it registered.
class _LikeButton extends StatefulWidget {
  final bool isLiked;
  final VoidCallback? onTap;

  const _LikeButton({required this.isLiked, this.onTap});

  @override
  State<_LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<_LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 260),
    vsync: this,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 60),
  ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: widget.onTap == null ? null : _handleTap,
      tooltip: widget.isLiked ? 'Unlike' : 'Like',
      icon: ScaleTransition(
        scale: _scale,
        child: Icon(
          widget.isLiked ? Icons.favorite : Icons.favorite_border,
          color: widget.isLiked ? const Color(0xFFE0245E) : null,
          size: 26,
        ),
      ),
    );
  }
}

/// Circular avatar inside a gradient ring, falling back to the first
/// letter of the username when there is no picture.
class _Avatar extends StatelessWidget {
  final String? url;
  final String username;

  const _Avatar({required this.url, required this.username});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final inner = CircleAvatar(
      radius: 18,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: url != null ? NetworkImage(url!) : null,
      onBackgroundImageError: url != null ? (_, __) {} : null,
      child: url == null
          ? Text(
              username.isNotEmpty ? username[0].toUpperCase() : '?',
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.surfaceContainerLow,
        ),
        child: inner,
      ),
    );
  }
}
