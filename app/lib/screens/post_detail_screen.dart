import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/api_service.dart';
import '../widgets/post_card.dart';

/// A single post, opened by tapping a tile in the profile grid.
///
/// Deleting is available here because these are the user's own posts —
/// the server enforces ownership regardless.
class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late Post _post;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
  }

  Future<void> _toggleLike() async {
    final wasLiked = _post.isLiked;

    setState(() {
      _post = _post.copyWith(
        isLiked: !wasLiked,
        likeCount: wasLiked ? _post.likeCount - 1 : _post.likeCount + 1,
      );
    });

    final result = wasLiked
        ? await ApiService.unlikePost(_post.id)
        : await ApiService.likePost(_post.id);

    if (!mounted) return;

    final acceptable =
        result.ok || result.statusCode == 409 || result.statusCode == 404;

    if (!acceptable) {
      setState(() => _post = widget.post);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  Future<void> _confirmDelete() async {
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

    setState(() => _deleting = true);
    final result = await ApiService.deletePost(_post.id);

    if (!mounted) return;

    if (result.ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          IconButton(
            icon: _deleting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _deleting ? null : _confirmDelete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: PostCard(post: _post, onLikeToggle: _toggleLike),
      ),
    );
  }
}
