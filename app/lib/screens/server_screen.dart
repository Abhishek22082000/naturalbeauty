import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api_service.dart';

/// Lets the user point the app at their backend, and test that it answers.
///
/// Shown automatically on first launch; reachable later from the login
/// screen and the home screen.
class ServerScreen extends StatefulWidget {
  /// When true this is the first-run setup, so there is nothing to go
  /// back to and saving continues into the app.
  final bool isFirstRun;

  const ServerScreen({super.key, this.isFirstRun = false});

  @override
  State<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends State<ServerScreen> {
  late final TextEditingController _url;
  bool _testing = false;
  String? _message;
  bool _ok = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: Config.baseUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _test() async {
    final cleaned = Config.normalise(_url.text);
    if (cleaned.isEmpty) {
      setState(() {
        _message = 'Enter a URL first';
        _ok = false;
      });
      return;
    }

    setState(() {
      _testing = true;
      _message = null;
      _url.text = cleaned;
    });

    final result = await ApiService.ping(cleaned);

    if (!mounted) return;
    setState(() {
      _testing = false;
      _ok = result.ok;
      _message = result.message;
    });
  }

  Future<void> _save() async {
    final cleaned = Config.normalise(_url.text);
    if (cleaned.isEmpty) {
      setState(() {
        _message = 'Enter a URL first';
        _ok = false;
      });
      return;
    }

    await Config.save(cleaned);
    if (!mounted) return;

    if (widget.isFirstRun) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved — using $cleaned')),
      );
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Server settings'),
        automaticallyImplyLeading: !widget.isFirstRun,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isFirstRun) ...[
                  Icon(Icons.dns_outlined, size: 56, color: scheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Where is your backend?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the address your Node server is running on.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                ],

                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Backend URL',
                    prefixIcon: Icon(Icons.link),
                    hintText: '192.168.1.16:3000',
                    helperText: 'http:// and port 3000 are added if omitted',
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _testing ? null : _test,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: _testing
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_tethering),
                        label: const Text('Test'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _testing ? null : _save,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('Save'),
                      ),
                    ),
                  ],
                ),

                if (_message != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _ok ? scheme.primaryContainer : scheme.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _ok ? Icons.check_circle_outline : Icons.error_outline,
                          color: _ok
                              ? scheme.onPrimaryContainer
                              : scheme.onErrorContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: _ok
                                  ? scheme.onPrimaryContainer
                                  : scheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "If it can't connect",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '1.  npm run dev is running on the PC\n\n'
                        "2.  The IP is current — run ipconfig on the PC, it\n"
                        '     changes when the router reassigns addresses\n\n'
                        '3.  Phone and PC are on the same Wi-Fi\n\n'
                        '4.  Windows Firewall allows inbound TCP 3000.\n'
                        '     In an admin PowerShell:\n\n'
                        '     New-NetFirewallRule -DisplayName "Node API 3000"\n'
                        '       -Direction Inbound -LocalPort 3000\n'
                        '       -Protocol TCP -Action Allow',
                        style: TextStyle(fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
