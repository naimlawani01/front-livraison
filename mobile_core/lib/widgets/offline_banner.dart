import 'package:flutter/material.dart';
import '../services/network_service.dart';
import '../theme/app_theme.dart';

/// Bandeau « Pas de connexion » en haut de l'app (réseau faible fréquent).
/// Encre sur fond clair → lisible au soleil, sans alarmer comme un rouge.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NetworkService(),
      builder: (context, _) {
        final isOnline = NetworkService().isOnline;
        return AnimatedSlide(
          offset: isOnline ? const Offset(0, -1) : Offset.zero,
          duration: const Duration(milliseconds: 300),
          child: AnimatedOpacity(
            opacity: isOnline ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.textPrimary,
              child: const SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: AppTheme.white, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pas de connexion internet',
                        style: TextStyle(color: AppTheme.white, fontSize: 13, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
