import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Renders a user-friendly error screen instead of Flutter's default red box
/// when a widget fails to build at runtime. Wire this up via
/// `ErrorWidget.builder = AppErrorScreen.builder` in `main()`.
class AppErrorScreen extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorScreen({super.key, this.message, this.onRetry});

  /// Drop-in replacement for `ErrorWidget.builder`.
  static Widget builder(FlutterErrorDetails details) {
    return AppErrorScreen(
      message: 'Une erreur inattendue s\'est produite.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: AppTheme.error,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Oups…',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message ?? 'Une erreur est survenue. Veuillez réessayer.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.black,
                      foregroundColor: AppTheme.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Réessayer'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
