import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Motif « deux points » — signature du logo Sönaiyaa (le « S » à deux points).
/// Réutilisé sur les en-têtes et à côté des labels d'argent (Crédit / Gains).
class BrandDots extends StatelessWidget {
  final double size;
  final Color? color;
  const BrandDots({super.key, this.size = 4, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.accent;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(c),
        SizedBox(width: size * 0.75),
        _dot(c),
      ],
    );
  }

  Widget _dot(Color c) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}
