import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_core/mobile_core.dart';

/// Le moment « Course livrée » (pic + fin de parcours) : check qui rebondit,
/// montant gagné en grand, message humain. Animation courte et légère
/// (téléphones d'entrée de gamme).
class CourseLivreeScreen extends StatefulWidget {
  final Course course;
  const CourseLivreeScreen({super.key, required this.course});

  @override
  State<CourseLivreeScreen> createState() => _CourseLivreeScreenState();
}

class _CourseLivreeScreenState extends State<CourseLivreeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late final Animation<double> _check = CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.7, curve: Curves.elasticOut));
  late final Animation<double> _texte = CurvedAnimation(parent: _ctrl, curve: const Interval(0.35, 1, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final montant = AppCurrency.format(course.montantLivreur);
    final cash = course.modePaiement.toUpperCase() == 'CASH';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            children: [
              const Spacer(flex: 2),
              ScaleTransition(
                scale: _check,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppTheme.success,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppTheme.success.withValues(alpha: 0.18), spreadRadius: 12)],
                  ),
                  child: const Icon(Icons.check_rounded, size: 56, color: AppTheme.white),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _texte,
                child: Column(
                  children: [
                    const Text(
                      'Course livrée',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        montant,
                        style: AppTheme.mono(size: 48, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -1.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bravo, $montant pour vous',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.accentDark),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      cash
                          ? 'Reçus en espèces chez l\'expéditeur.'
                          : 'Crédités sur vos Gains, à retirer quand vous voulez.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 3),
              PrimaryCta(
                label: 'Voir les courses',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
