import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'primary_cta.dart';

/// Les 4 états d'un écran qui charge des données (skill sonaiyaa-design) :
/// chargement, vide, erreur, hors ligne. Même mise en page pour les quatre :
/// pastille d'icône, titre, message qui dit quoi faire, action éventuelle.

/// Chargement : le motif « deux points » de la marque, en accent.
class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandDotsPulse(color: AppTheme.accent),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Liste vide (ou écran bloqué) : toujours avec une explication et, si
/// possible, l'action qui débloque la situation.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  /// Ton de la pastille : accent par défaut, `warning` pour un blocage, etc.
  final Color? tint;
  final Color? tintBackground;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.tint,
    this.tintBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: tintBackground ?? AppTheme.accentLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusXl),
              ),
              child: Icon(icon, color: tint ?? AppTheme.accentDark, size: 36),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.45),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              SecondaryButton(label: actionLabel!, icon: actionIcon, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Erreur : message humain + « Réessayer ».
class ErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  const ErrorState({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Ça n\'a pas marché',
      message: message ?? 'Vérifiez votre connexion puis réessayez.',
      actionLabel: onRetry != null ? 'Réessayer' : null,
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
      tint: AppTheme.error,
      tintBackground: AppTheme.errorLight,
    );
  }
}

/// Hors ligne (pas de réseau) et rien en cache à montrer.
class OfflineState extends StatelessWidget {
  final VoidCallback? onRetry;
  const OfflineState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.wifi_off_rounded,
      title: 'Pas de connexion',
      message: 'Vos données s\'afficheront dès que le réseau revient.',
      actionLabel: onRetry != null ? 'Réessayer' : null,
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
      tint: AppTheme.textPrimary,
      tintBackground: AppTheme.divider,
    );
  }
}
