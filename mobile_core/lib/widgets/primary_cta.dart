import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Bouton d'action principal Sönaiyaa : un seul par écran, en bas (zone du
/// pouce), 64 px de haut (utilisable avec des gants), dégradé accent.
/// Pendant [loading], il affiche `BrandDots` et ignore les appuis : une action
/// d'argent ou de statut ne part jamais deux fois.
class PrimaryCta extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryCta({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: 64,
          decoration: BoxDecoration(
            gradient: onPressed != null ? AppTheme.ctaGradient : null,
            color: onPressed != null ? null : AppTheme.divider,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: onPressed != null ? AppTheme.shadowLg : null,
          ),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            child: Center(
              child: loading
                  ? const BrandDotsPulse()
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: onPressed != null ? AppTheme.white : AppTheme.textSecondary,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Indicateur de chargement « deux points » (motif de la marque), en blanc.
class BrandDotsPulse extends StatefulWidget {
  final Color color;
  const BrandDotsPulse({super.key, this.color = AppTheme.white});

  @override
  State<BrandDotsPulse> createState() => _BrandDotsPulseState();
}

class _BrandDotsPulseState extends State<BrandDotsPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        Widget dot(double phase) {
          final v = ((t + phase) % 1.0);
          final opacity = 0.35 + 0.65 * (v < 0.5 ? v * 2 : (1 - v) * 2);
          return Opacity(
            opacity: opacity,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
            ),
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [dot(0), const SizedBox(width: 8), dot(0.5)],
        );
      },
    );
  }
}
