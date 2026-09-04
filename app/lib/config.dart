import 'package:shared_preferences/shared_preferences.dart';

/// The backend URL, stored on the device and editable from the app's
/// Server settings screen.
///
/// It is kept in shared_preferences rather than hardcoded because a PC's
/// LAN address changes whenever the router reassigns DHCP leases — this
/// way the URL can be corrected on the phone instead of rebuilding the APK.
class Config {
  static const _urlKey = 'api_base_url';

  /// Used until the user sets one. Change if you like, but the app will
  /// prompt for the real URL on first launch anyway.
  static const String defaultUrl = 'http://192.168.1.16:3000';

  static String _baseUrl = defaultUrl;

  /// The current URL. Call [load] once at startup before reading this.
  static String get baseUrl => _baseUrl;

  /// Reads the saved URL into memory. Returns true if one was saved.
  static Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_urlKey);
    if (saved != null && saved.isNotEmpty) {
      _baseUrl = saved;
      return true;
    }
    return false;
  }

  static Future<void> save(String url) async {
    final cleaned = normalise(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_urlKey, cleaned);
    _baseUrl = cleaned;
  }

  /// Tidies user input into a usable base URL:
  ///   "192.168.1.16:3000"      -> "http://192.168.1.16:3000"
  ///   "http://192.168.1.16:3000/" -> "http://192.168.1.16:3000"
  ///   "192.168.1.16"           -> "http://192.168.1.16:3000"
  static String normalise(String input) {
    var url = input.trim();
    if (url.isEmpty) return url;

    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }

    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }

    // Add the default port if the host has none.
    final uri = Uri.tryParse(url);
    if (uri != null && !uri.hasPort) {
      url = '$url:3000';
    }

    return url;
  }
}
