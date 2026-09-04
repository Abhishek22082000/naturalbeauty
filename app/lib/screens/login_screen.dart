import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';
import 'signup_screen.dart';
import 'main_shell.dart';
import 'server_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.login(
      email: _email.text.trim(),
      password: _password.text,
    );

    if (!mounted) return;

    if (result.ok) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        height: 84,
                        width: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.tertiary,
                            ],
                          ),
                        ),
                        child: const Icon(Icons.local_florist,
                            size: 44, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Natural Beauty',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Share what you see',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 36),

                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Password is required' : null,
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
                                color: Theme.of(context)
                                    .colorScheme
                                    .onErrorContainer),
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
                          : const Text('Log in'),
                    ),

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                            child: Divider(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                            child: Divider(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              ),
                      child: const Text('Create an account'),
                    ),

                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _loading
                          ? null
                          : () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const ServerScreen(),
                                ),
                              );
                              if (mounted) setState(() {});
                            },
                      icon: const Icon(Icons.dns_outlined, size: 18),
                      label: Text(
                        'Server: ${Config.baseUrl}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
