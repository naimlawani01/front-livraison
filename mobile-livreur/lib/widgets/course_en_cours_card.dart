import 'package:flutter/material.dart';
import 'package:mobile_core/mobile_core.dart';

/// Carte « Course en cours » : frise Expéditeur → Vous → Client et prochaine
/// étape. Identique sur l'Accueil et l'Historique ; ouvre l'écran de course.
class CourseEnCoursCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  const CourseEnCoursCard({super.key, required this.course, required this.onTap});

  String get _prochaineEtape {
    switch (course.status.toUpperCase()) {
      case 'ACCEPTEE':
        return 'Allez chercher le colis · ${course.expediteurNom ?? 'Expéditeur'}';
      case 'EN_RECUPERATION':
        return 'Récupérez le colis chez ${course.expediteurNom ?? 'l\'expéditeur'}';
      case 'RETOUR':
        return 'Livraison impossible : rapportez le colis à ${course.expediteurNom ?? 'l\'expéditeur'}';
      default:
        return 'Livrez ${course.contactClientNom}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            border: Border.all(color: AppTheme.accent, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Course en cours', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  ),
                  Text(AppCurrency.format(course.montantLivreur),
                      style: AppTheme.mono(size: 15, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: 0)),
                ],
              ),
              const SizedBox(height: 16),
              CourseFrise(status: course.status, livreurLabel: 'Vous'),
              const SizedBox(height: 12),
              Text(_prochaineEtape,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
