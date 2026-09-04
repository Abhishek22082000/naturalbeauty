import 'package:flutter/material.dart';
import 'config.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/server_screen.dart';

void main() {
  runApp(const NaturalBeautyApp());
}

class NaturalBeautyApp extends StatelessWidget {
  const NaturalBeautyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NaturalBeauty',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B4B94)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
        ),
      ),
      home: const _Launcher(),
    );
  }
}

/// Decides the first screen:
///   no server URL saved  -> server setup
///   no token saved       -> login
///   otherwise            -> home
class _Launcher extends StatefulWidget {
  const _Launcher();

  @override
  State<_Launcher> createState() => _LauncherState();
}

class _LauncherState extends State<_Launcher> {
  bool _loading = true;
  bool _needsServer = false;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final hasUrl = await Config.load();
    final token = await ApiService.getToken();

    if (!mounted) return;
    setState(() {
      _needsServer = !hasUrl;
      _loggedIn = token != null;
      _loading = false;
    });
  }

  Future<void> _openSetup() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ServerScreen(isFirstRun: true)),
    );
    if (saved == true && mounted) {
      setState(() => _needsServer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_needsServer) {
      // Show the setup screen immediately on first launch.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _needsServer) _openSetup();
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return _loggedIn ? const MainShell() : const LoginScreen();
  }
}
