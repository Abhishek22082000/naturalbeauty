/// One row on the leaderboard: a user ranked by average likes per post.
class LeaderboardEntry {
  final int rank;
  final int userId;
  final String username;
  final String? fullName;
  final String? profilePicture;
  final bool isVerified;
  final int postCount;
  final int totalLikes;
  final double avgLikes;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.postCount,
    required this.totalLikes,
    required this.avgLikes,
    this.fullName,
    this.profilePicture,
    this.isVerified = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: _toInt(json['rank']),
      userId: _toInt(json['id']),
      username: (json['username'] ?? 'unknown').toString(),
      fullName: json['full_name']?.toString(),
      profilePicture: json['profile_picture']?.toString(),
      isVerified: _toInt(json['is_verified']) == 1,
      postCount: _toInt(json['post_count']),
      totalLikes: _toInt(json['total_likes']),
      avgLikes: _toDouble(json['avg_likes']),
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  /// MySQL can return ROUND() on a DECIMAL as a string, so accept both.
  static double _toDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  /// "1.33" — always two decimals, so the column lines up.
  String get avgLabel => avgLikes.toStringAsFixed(2);
}
