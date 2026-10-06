import 'package:flutter/material.dart';

class AppConstants {
  static const String baseUrl = 'https://api.sonaiyaa.fr';
  static const String apiPrefix = '/api/v1';
  static const String wsUrl = 'wss://api.sonaiyaa.fr/ws';
  
  // Timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration wsReconnectDelay = Duration(seconds: 5);
  
  // Storage Keys
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyUserPhone = 'user_phone';
  static const String keyExpediteurId = 'expediteur_id';
}

/// Configuration de la devise — modifier ici pour un autre marché.
/// Exemple : CFA (Sénégal/Côte d'Ivoire), XOF, EUR…
class AppCurrency {
  /// Symbole affiché dans l'UI (ex: "GNF", "CFA", "€")
  static const String symbol = 'GNF';

  /// Formate un montant : "30 000 GNF"
  static String format(num amount) {
    final formatted = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
    return '$formatted $symbol';
  }

  /// Formate avec signe négatif : "-4 500 GNF"
  static String formatNeg(num amount) {
    final formatted = amount.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]} ',
    );
    return '-$formatted $symbol';
  }
}

class AppColors {
  static const Color primary = Color(0xFF2196F3);
  static const Color secondary = Color(0xFFFF9800);
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFFC107);
  
  // Status Colors
  static const Color statusCreated = Color(0xFF9E9E9E);
  static const Color statusDiffused = Color(0xFF2196F3);
  static const Color statusAccepted = Color(0xFF4CAF50);
  static const Color statusInProgress = Color(0xFFFF9800);
  static const Color statusCompleted = Color(0xFF4CAF50);
  static const Color statusCancelled = Color(0xFFF44336);
}

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );
  
  static const TextStyle heading2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 16,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    color: Colors.grey,
  );
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}
