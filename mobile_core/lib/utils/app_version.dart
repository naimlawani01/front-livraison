import 'package:package_info_plus/package_info_plus.dart';

/// Reads the app version from the platform (Info.plist on iOS,
/// AndroidManifest on Android) so the displayed value never drifts from the
/// real build that the user has installed.
///
/// Cached after first call to avoid repeated platform channel hops.
class AppVersion {
  static PackageInfo? _cached;

  static Future<void> warmup() async {
    _cached ??= await PackageInfo.fromPlatform();
  }

  /// "v1.0.0+1" — full identifier including build number, useful for support.
  static String get full {
    final p = _cached;
    if (p == null) return 'v?';
    return 'v${p.version}+${p.buildNumber}';
  }

  /// "v1.0.0" — short version for display in About screens.
  static String get short {
    final p = _cached;
    if (p == null) return 'v?';
    return 'v${p.version}';
  }

  static String get appName => _cached?.appName ?? 'Sönaiyaa';
  static String get buildNumber => _cached?.buildNumber ?? '?';
}
