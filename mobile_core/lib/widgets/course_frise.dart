import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// La frise de course `Expéditeur → Livreur → Client` (signature Sönaiyaa) :
/// représentation unique du statut d'une course, à utiliser partout à la
/// place d'un simple badge texte. Étapes faites en `success`, étape courante
/// en accent, étapes à venir en contour.
///
/// [livreurLabel] permet d'écrire « Vous » dans l'app livreur.
class CourseFrise extends StatelessWidget {
  final String status;
  final String expediteurLabel;
  final String livreurLabel;
  final String clientLabel;

  /// Affiche le libellé de chaque point sous la frise.
  final bool showLabels;

  const CourseFrise({
    super.key,
    required this.status,
    this.expediteurLabel = 'Expéditeur',
    this.livreurLabel = 'Livreur',
    this.clientLabel = 'Client',
    this.showLabels = true,
  });

  /// Index de l'étape courante (0 = expéditeur, 1 = livreur, 2 = client),
  /// 3 = tout est fait, -1 = course annulée.
  static int etapeCourante(String status) {
    switch (status.toUpperCase()) {
      case 'CREEE':
      case 'DIFFUSEE':
        return 0; // l'expéditeur attend un livreur
      case 'ACCEPTEE':
      case 'EN_RECUPERATION':
        return 1; // le livreur va chercher le colis
      case 'EN_LIVRAISON':
        return 2; // le colis est en route vers le client
      case 'TERMINEE':
        return 3;
      default:
        return -1; // ANNULEE ou inconnu
    }
  }

  @override
  Widget build(BuildContext context) {
    final courante = etapeCourante(status);
    final annulee = courante == -1;
    final labels = [expediteurLabel, livreurLabel, clientLabel];

    _Etat etat(int i) {
      if (annulee) return _Etat.inactive;
      if (i < courante) return _Etat.faite;
      if (i == courante) return _Etat.active;
      return _Etat.aVenir;
    }

    return Semantics(
      label: annulee ? 'Course annulée' : 'Étape ${(courante + 1).clamp(1, 3)} sur 3',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _Point(etat: etat(0)),
              _Trait(faite: !annulee && courante > 0),
              _Point(etat: etat(1)),
              _Trait(faite: !annulee && courante > 1),
              _Point(etat: etat(2)),
            ],
          ),
          if (showLabels) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < 3; i++)
                  Expanded(
                    child: Text(
                      labels[i],
                      textAlign: i == 0 ? TextAlign.left : (i == 1 ? TextAlign.center : TextAlign.right),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: etat(i) == _Etat.active ? FontWeight.w800 : FontWeight.w600,
                        color: etat(i) == _Etat.active ? AppTheme.textPrimary : AppTheme.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _Etat { faite, active, aVenir, inactive }

class _Point extends StatelessWidget {
  final _Etat etat;
  const _Point({required this.etat});

  @override
  Widget build(BuildContext context) {
    switch (etat) {
      case _Etat.faite:
        return Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 14, color: AppTheme.white),
        );
      case _Etat.active:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.2), spreadRadius: 5)],
          ),
        );
      case _Etat.aVenir:
        return Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.textSecondary, width: 3),
          ),
        );
      case _Etat.inactive:
        return Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(color: AppTheme.divider, shape: BoxShape.circle),
        );
    }
  }
}

class _Trait extends StatelessWidget {
  final bool faite;
  const _Trait({required this.faite});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: faite ? AppTheme.success : AppTheme.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
