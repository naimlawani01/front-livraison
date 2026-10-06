import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the user has seen the onboarding flow at least once.
/// Stored in SharedPreferences as a single boolean per app — Expediteur
/// and Livreur each have their own SharedPreferences container so the
/// same key is fine for both.
class OnboardingStorage {
  static const String _key = 'onboarding_seen_v1';

  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Useful for QA: clear the flag so onboarding shows again on next launch.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
