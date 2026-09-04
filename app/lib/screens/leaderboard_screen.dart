import 'package:flutter/material.dart';
import '../config.dart';
import '../models/leaderboard_entry.dart';
import '../services/api_service.dart';

/// Top Natural Beauty — users ranked by average likes per post.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  List<LeaderboardEntry> _entries = [];
  bool _loading = true;
  String? _error;

  /// Drives the entrance: podium bars grow, rows slide in one after
  /// another. Restarted on every successful load so pull-to-refresh
  /// replays it.
  late final AnimationController _entrance = AnimationController(
    duration: const Duration(milliseconds: 900),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // minPosts: 1 while the app has few posts — raise it once there is
    // enough data that a single lucky post could distort the ranking.
    final result = await ApiService.getLeaderboard(limit: 5, minPosts: 1);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.ok) {
        _entries = result.entries;
      } else {
        _error = result.message;
      }
    });

    if (result.ok && result.entries.isNotEmpty) {
      _entrance.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Top Natural Beauty',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        centerTitle: false,
        scrolledUnderElevation: 0.5,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _error != null
                  ? _StateMessage(
                      icon: Icons.cloud_off,
                      title: "Couldn't load the leaderboard",
                      detail: _error!,
                      onRetry: _load,
                    )
                  : _entries.isEmpty
                      ? const _StateMessage(
                          icon: Icons.emoji_events_outlined,
                          title: 'No rankings yet',
                          detail: 'Once people post and like, the top five '
                              'will appear here.',
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            const _Explainer(),
                            if (_entries.length >= 3)
                              _Podium(
                                entries: _entries,
                                animation: _entrance,
                              ),
                            ..._entries.asMap().entries.map(
                                  (e) => _Row(
                                    entry: e.value,
                                    animation: _entrance,
                                    position: e.key,
                                  ),
                                ),
                          ],
                        ),
            ),
    );
  }
}

/// Says what the ranking actually measures, so the order is not a mystery.
class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ranked by average likes per post — quality over quantity.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// The top three, with first place raised in the middle.
class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final Animation<double> animation;

  const _Podium({required this.entries, required this.animation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Silver and bronze rise first, then gold — so the eye lands
          // on first place last.
          Expanded(
            child: _PodiumSpot(
                entry: entries[1],
                height: 74,
                animation: animation,
                delay: 0.05),
          ),
          Expanded(
            child: _PodiumSpot(
                entry: entries[0],
                height: 96,
                animation: animation,
                delay: 0.22),
          ),
          Expanded(
            child: _PodiumSpot(
                entry: entries[2],
                height: 58,
                animation: animation,
                delay: 0.13),
          ),
        ],
      ),
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final LeaderboardEntry entry;
  final double height;
  final Animation<double> animation;
  final double delay;

  const _PodiumSpot({
    required this.entry,
    required this.height,
    required this.animation,
    required this.delay,
  });

  static const _medals = {
    1: Color(0xFFD4AF37), // gold
    2: Color(0xFFA8A9AD), // silver
    3: Color(0xFFCD7F32), // bronze
  };

  @override
  Widget build(BuildContext context) {
    final colour = _medals[entry.rank] ?? Theme.of(context).colorScheme.primary;
    final isFirst = entry.rank == 1;

    // Each spot animates over its own slice of the shared controller.
    final grow = CurvedAnimation(
      parent: animation,
      curve: Interval(delay, (delay + 0.55).clamp(0.0, 1.0),
          curve: Curves.easeOutBack),
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: Interval((delay + 0.15).clamp(0.0, 1.0), 1.0,
          curve: Curves.easeOut),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: fade.value,
        child: child,
      ),
      child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst)
          const Icon(Icons.emoji_events, size: 24, color: Color(0xFFD4AF37)),
        const SizedBox(height: 4),
        _Avatar(entry: entry, radius: isFirst ? 30 : 24, ring: colour),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            entry.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Text(
          entry.avgLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colour,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        AnimatedBuilder(
          animation: grow,
          builder: (context, _) => Container(
            height: height * grow.value.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.18),
              border: Border(top: BorderSide(color: colour, width: 3)),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            alignment: Alignment.center,
            clipBehavior: Clip.hardEdge,
            child: grow.value > 0.55
                ? Text(
                    '${entry.rank}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: colour,
                    ),
                  )
                : null,
          ),
        ),
      ],
      ),
    );
  }
}

/// One full-width row in the ranked list.
class _Row extends StatelessWidget {
  final LeaderboardEntry entry;
  final Animation<double> animation;
  final int position;

  const _Row({
    required this.entry,
    required this.animation,
    required this.position,
  });

  static const _medals = {
    1: Color(0xFFD4AF37),
    2: Color(0xFFA8A9AD),
    3: Color(0xFFCD7F32),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final medal = _medals[entry.rank];

    // Rows enter after the podium, one shortly after the next.
    final start = (0.45 + position * 0.09).clamp(0.0, 0.9);
    final slide = CurvedAnimation(
      parent: animation,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: slide,
      builder: (context, child) => Opacity(
        opacity: slide.value,
        child: Transform.translate(
          offset: Offset((1 - slide.value) * 28, 0),
          child: child,
        ),
      ),
      child: Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: medal != null
            ? Border.all(color: medal.withValues(alpha: 0.45), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${entry.rank}',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: medal ?? scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Avatar(entry: entry, radius: 22, ring: medal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.username,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (entry.isVerified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified,
                          size: 14, color: Color(0xFF3897F0)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.postCount} '
                  '${entry.postCount == 1 ? "post" : "posts"}  ·  '
                  '${entry.totalLikes} '
                  '${entry.totalLikes == 1 ? "like" : "likes"}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Counts up as the row settles, rather than just appearing.
              AnimatedBuilder(
                animation: slide,
                builder: (context, _) => Text(
                  (entry.avgLikes * slide.value).toStringAsFixed(2),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: medal ?? scheme.primary,
                  ),
                ),
              ),
              Text(
                'avg likes',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

/// Avatar with an optional coloured ring for medal positions.
class _Avatar extends StatelessWidget {
  final LeaderboardEntry entry;
  final double radius;
  final Color? ring;

  const _Avatar({required this.entry, required this.radius, this.ring});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pic = entry.profilePicture;
    final hasPic = pic != null && pic.isNotEmpty;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      backgroundImage: hasPic
          ? NetworkImage(
              pic.startsWith('http') ? pic : '${Config.baseUrl}$pic')
          : null,
      child: hasPic
          ? null
          : Text(
              entry.username.isNotEmpty
                  ? entry.username[0].toUpperCase()
                  : '?',
              style: TextStyle(
                fontSize: radius * 0.8,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            ),
    );

    if (ring == null) return avatar;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring!, width: 2.5),
      ),
      child: avatar,
    );
  }
}

/// Empty and error states, both scrollable so pull-to-refresh still works.
class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback? onRetry;

  const _StateMessage({
    required this.icon,
    required this.title,
    required this.detail,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Icon(icon, size: 56, color: scheme.onSurfaceVariant),
        const SizedBox(height: 16),
        Center(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            detail,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
        ],
      ],
    );
  }
}
