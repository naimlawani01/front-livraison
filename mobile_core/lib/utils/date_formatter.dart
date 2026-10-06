import 'package:intl/intl.dart';

/// Formats dates and times in **Conakry local time** (GMT+0).
///
/// The backend serializes timestamps in UTC. Guinea is also at UTC offset +0
/// (Africa/Conakry), so no offset conversion is needed — but we make the
/// timezone awareness explicit and centralize formatting so any future
/// market change (e.g. CFA Senegal at GMT+0, Côte d'Ivoire at GMT+0,
/// Algeria at GMT+1…) only requires updating this file.
class DateFormatter {
  /// Locale used for month/day names. French (Guinea is francophone).
  static const String _locale = 'fr_FR';

  /// "14 mai 2026, 10:30"
  static String dateTime(DateTime utc) {
    final local = utc.toLocal();
    return '${DateFormat.yMMMd(_locale).format(local)}, '
        '${DateFormat.Hm(_locale).format(local)}';
  }

  /// "14 mai 2026"
  static String dateOnly(DateTime utc) =>
      DateFormat.yMMMd(_locale).format(utc.toLocal());

  /// "10:30"
  static String timeOnly(DateTime utc) =>
      DateFormat.Hm(_locale).format(utc.toLocal());

  /// Relative time: "il y a 5 min", "il y a 2 h", "hier", or absolute date if older.
  static String relative(DateTime utc) {
    final now = DateTime.now();
    final diff = now.difference(utc.toLocal());

    if (diff.inSeconds < 60) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'hier';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} jours';
    return dateOnly(utc);
  }
}
