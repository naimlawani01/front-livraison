/// Utilitaires de gestion des numéros de téléphone Guinéens.
///
/// Format canonique stocké côté backend : `+224XXXXXXXXX` (12 caractères),
/// où les 9 chiffres locaux commencent obligatoirement par `6`
/// (Orange, MTN, Cellcom mobiles).
class GuineaPhone {
  static const String countryCode = '+224';
  static const String flag = '🇬🇳';
  static const int localLength = 9;

  /// Vrai si [local] est un numéro local guinéen valide (9 chiffres, commence par 6).
  static bool isValidLocal(String local) {
    final cleaned = local.replaceAll(RegExp(r'\s+'), '');
    return RegExp(r'^6\d{8}$').hasMatch(cleaned);
  }

  /// Vrai si [phone] est un numéro complet au format `+224XXXXXXXXX`.
  static bool isValidFull(String phone) {
    return RegExp(r'^\+2246\d{8}$').hasMatch(phone);
  }

  /// Renvoie la version normalisée `+224XXXXXXXXX`. Lève [FormatException]
  /// si le numéro n'est pas un mobile guinéen valide.
  static String normalize(String input) {
    final digits = input.replaceAll(RegExp(r'\D'), '');
    String local;
    if (digits.startsWith('00224')) {
      local = digits.substring(5);
    } else if (digits.startsWith('224')) {
      local = digits.substring(3);
    } else {
      local = digits;
    }
    if (!isValidLocal(local)) {
      throw const FormatException('Numéro guinéen invalide (9 chiffres, commence par 6)');
    }
    return '$countryCode$local';
  }

  /// Affiche un numéro local groupé : `626 947 150`.
  static String formatLocal(String local) {
    final cleaned = local.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < cleaned.length && i < localLength; i++) {
      if (i == 3 || i == 6) buf.write(' ');
      buf.write(cleaned[i]);
    }
    return buf.toString();
  }

  /// Extrait la partie locale (9 chiffres) d'un numéro complet ou partiel.
  static String toLocal(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('00224')) return digits.substring(5);
    if (digits.startsWith('224')) return digits.substring(3);
    return digits;
  }

  /// Affichage lisible : `+224 626 947 150` à partir de `+224626947150`.
  /// Si l'entrée n'est pas un numéro guinéen valide, retourne tel quel.
  static String formatPretty(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    final local = toLocal(phone);
    if (local.length != localLength) return phone;
    return '$countryCode ${formatLocal(local)}';
  }
}
