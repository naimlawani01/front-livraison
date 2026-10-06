import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'primary_cta.dart';

/// Feuille du bas Sönaiyaa : poignée, coins `radiusXl`, marges 16, suit le
/// clavier. Le contenu met son action principale en dernier (zone du pouce).
class AppSheet extends StatelessWidget {
  final Widget child;
  const AppSheet({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// En-tête commun des feuilles : pastille d'icône, titre, message.
class AppSheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  const AppSheetHeader({super.key, required this.icon, required this.title, this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(color: AppTheme.accentLight, shape: BoxShape.circle),
          child: Icon(icon, color: AppTheme.accentDark, size: 28),
        ),
        const SizedBox(height: 16),
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
      ],
    );
  }
}

/// Demande de confirmation d'une action (changement de statut, annulation…).
/// Renvoie `true` si l'utilisateur confirme. Action principale en bas,
/// « Retour » en lien discret au-dessus.
Future<bool> showConfirmAction(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? message,
  required String confirmLabel,
}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => AppSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSheetHeader(icon: icon, title: title, message: message),
          const SizedBox(height: 24),
          PrimaryCta(label: confirmLabel, onPressed: () => Navigator.pop(ctx, true)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textSecondary,
              minimumSize: const Size.fromHeight(48),
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            child: const Text('Retour'),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}
