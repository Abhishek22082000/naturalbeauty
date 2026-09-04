/// One post in the feed.
///
/// [fromJson] is written against the shape the backend *will* return once
/// `GET /posts/feed` exists:
///
/// ```json
/// {
///   "id": 12,
///   "user_id": 3,
///   "username": "john_doe",
///   "full_name": "John Doe",
///   "profile_picture": "/uploads/avatars/abc.jpg",
///   "image_url": "/uploads/posts/1788501253027-743380924.jpg",
///   "caption": "Sunset at the beach",
///   "location": "Goa",
///   "like_count": 4,
///   "is_liked": 1,
///   "created_at": "2026-09-04T10:22:31.000Z"
/// }
/// ```
class Post {
  final int id;
  final int userId;
  final String username;
  final String? fullName;
  final String? profilePicture;
  final String imageUrl;
  final String? caption;
  final String? location;
  final int likeCount;
  final bool isLiked;
  final bool isVerified;
  final DateTime? createdAt;

  const Post({
    required this.id,
    required this.userId,
    required this.username,
    required this.imageUrl,
    this.fullName,
    this.profilePicture,
    this.caption,
    this.location,
    this.likeCount = 0,
    this.isLiked = false,
    this.isVerified = false,
    this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: _toInt(json['id']),
      userId: _toInt(json['user_id']),
      username: (json['username'] ?? 'unknown').toString(),
      fullName: json['full_name']?.toString(),
      profilePicture: json['profile_picture']?.toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
      caption: json['caption']?.toString(),
      location: json['location']?.toString(),
      likeCount: _toInt(json['like_count']),
      // MySQL sends 0/1, not true/false — never compare with == true.
      isLiked: _toInt(json['is_liked']) == 1,
      isVerified: _toInt(json['is_verified']) == 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is num) return v.toInt();
    return 0;
  }

  Post copyWith({int? likeCount, bool? isLiked}) {
    return Post(
      id: id,
      userId: userId,
      username: username,
      fullName: fullName,
      profilePicture: profilePicture,
      imageUrl: imageUrl,
      caption: caption,
      location: location,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      isVerified: isVerified,
      createdAt: createdAt,
    );
  }

  /// "2h", "3d", "5w" — the short relative time Instagram shows.
  String get timeAgo {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 365) return '${(diff.inDays / 7).floor()}w';
    return '${(diff.inDays / 365).floor()}y';
  }
}

/// Placeholder posts so the feed can be designed before the backend has a
/// `GET /posts/feed` endpoint. Delete this once the endpoint exists.
class MockPosts {
  static List<Post> get sample {
    final now = DateTime.now();
    return [
      Post(
        id: 1,
        userId: 1,
        username: 'priya_shah',
        fullName: 'Priya Shah',
        isVerified: true,
        imageUrl: 'https://picsum.photos/seed/nb1/800/800',
        caption: 'Morning light through the tea gardens. Worth the 5am start.',
        location: 'Munnar, Kerala',
        likeCount: 128,
        isLiked: true,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
      Post(
        id: 2,
        userId: 2,
        username: 'arjun.travels',
        fullName: 'Arjun Mehta',
        imageUrl: 'https://picsum.photos/seed/nb2/800/1000',
        caption: 'Old town rooftops',
        location: 'Jodhpur',
        likeCount: 47,
        isLiked: false,
        createdAt: now.subtract(const Duration(hours: 9)),
      ),
      Post(
        id: 3,
        userId: 3,
        username: 'meera_k',
        fullName: 'Meera Krishnan',
        imageUrl: 'https://picsum.photos/seed/nb3/800/800',
        caption: null,
        location: null,
        likeCount: 12,
        isLiked: false,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      Post(
        id: 4,
        userId: 4,
        username: 'dev.rawat',
        fullName: 'Dev Rawat',
        isVerified: true,
        imageUrl: 'https://picsum.photos/seed/nb4/800/900',
        caption: 'Monsoon finally here 🌧️',
        location: 'Mumbai',
        likeCount: 203,
        isLiked: true,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
    ];
  }
}
