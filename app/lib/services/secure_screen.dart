import 'package:flutter/services.dart';

/// Blocks screenshots and screen recording on Android via FLAG_SECURE.
///
/// The flag is set on the whole Activity, so it must be enabled when a
/// protected screen opens and disabled when it closes — otherwise every
/// other screen inherits the block.
///
/// What this does and does not do:
///   - Android: screenshots and screen recording of the app show black,
///     and the app does not appear in the recent-apps thumbnail.
///   - iOS: has no equivalent flag. Screenshots cannot be blocked there.
///   - Neither platform can stop someone photographing the screen with
///     another device. This deters casual sharing; it is not DRM.
class SecureScreen {
  static const _channel = MethodChannel('naturalbeauty/secure');

  static Future<void> enable() async {
    try {
      await _channel.invokeMethod('enableSecure');
    } on PlatformException {
      // Not available on this platform — nothing to do.
    } on MissingPluginException {
      // Host side not registered (e.g. running on web or desktop).
    }
  }

  static Future<void> disable() async {
    try {
      await _channel.invokeMethod('disableSecure');
    } on PlatformException {
      // ignore
    } on MissingPluginException {
      // ignore
    }
  }
}
