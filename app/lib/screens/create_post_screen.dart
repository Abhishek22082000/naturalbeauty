import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _caption = TextEditingController();
  final _location = TextEditingController();
  final _picker = ImagePicker();

  File? _image;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      // maxWidth keeps uploads under the server's 5MB limit.
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        _image = File(picked.path);
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Could not open ${source.name}: $e');
    }
  }

  Future<void> _submit() async {
    if (_image == null) {
      setState(() => _error = 'Pick an image first');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.createPost(
      image: _image!,
      caption: _caption.text.trim(),
      location: _location.text.trim(),
    );

    if (!mounted) return;

    if (result.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shared')),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _loading = false;
        _error = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create post')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                onTap: _loading || _image != null
                    ? null
                    : () => _pick(ImageSource.camera),
                child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.6),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _image == null
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.camera_alt_outlined, size: 46),
                              SizedBox(height: 10),
                              Text(
                                'Tap to take a photo',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        )
                      : Image.file(_image!, fit: BoxFit.cover),
                ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _pick(ImageSource.camera),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Take photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading
                          ? null
                          : () => _pick(ImageSource.gallery),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _caption,
                maxLines: 3,
                maxLength: 2200,
                decoration: const InputDecoration(
                  labelText: 'Caption',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _location,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline,
                          size: 19,
                          color:
                              Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Share'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
