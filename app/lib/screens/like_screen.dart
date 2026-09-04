import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Likes and unlikes a post by ID.
///
/// This is a stand-in: normally you would tap a heart on a photo in a
/// feed. The backend has no endpoint that returns posts yet, so there is
/// nothing to render a feed from — the post ID is entered by hand.
class LikeScreen extends StatefulWidget {
  const LikeScreen({super.key});

  @override
  State<LikeScreen> createState() => _LikeScreenState();
}

class _LikeScreenState extends State<LikeScreen> {
  final _postId = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _wasError = false;

  @override
  void dispose() {
    _postId.dispose();
    super.dispose();
  }

  Future<void> _run(Future<ApiResult> Function(int) action) async {
    final id = int.tryParse(_postId.text.trim());
    if (id == null) {
      setState(() {
        _message = 'Enter a numeric post ID';
        _wasError = true;
      });
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    final result = await action(id);

    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = '${result.statusCode}  ${result.message}';
      _wasError = !result.ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Like a post')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _postId,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Post ID',
                  prefixIcon: Icon(Icons.tag),
                  helperText: 'The ID shown after creating a post',
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed:
                          _loading ? null : () => _run(ApiService.likePost),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.favorite),
                      label: const Text('Like'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _loading ? null : () => _run(ApiService.unlikePost),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.favorite_border),
                      label: const Text('Unlike'),
                    ),
                  ),
                ],
              ),

              if (_loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],

              if (_message != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _wasError
                        ? scheme.errorContainer
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _wasError
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Text(
                'Expected responses:\n'
                '  201  Post liked\n'
                '  409  Already liked\n'
                '  404  Post not found / Like not found\n'
                '  401  Token expired — log out and back in',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
