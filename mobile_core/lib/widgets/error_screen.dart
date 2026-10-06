import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

/// Écran d'erreur affiché à la place du carré rouge de Flutter quand un widget
/// échoue au rendu. Branché via `ErrorWidget.builder = AppErrorScreen.builder`.
class AppErrorScreen extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorScreen({super.key, this.message, this.onRetry});

  static Widget builder(FlutterErrorDetails details) {
    return const AppErrorScreen(
      message: 'Une erreur inattendue s\'est produite. Revenez en arrière puis réessayez.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(child: ErrorState(message: message, onRetry: onRetry)),
    );
  }
}
