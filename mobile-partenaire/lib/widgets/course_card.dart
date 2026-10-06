import 'package:flutter/material.dart';
import 'package:mobile_core/mobile_core.dart';
import '../screens/courses/course_detail_screen.dart';

// ── Carte course : client, prix, frise (si active) ──────────────────────────

/// Carte d'une course (Accueil et liste) : client, prix, frise si active.
class CourseCard extends StatelessWidget {
  final Course course;
  const CourseCard({super.key, required this.course});

  bool get _isActive {
    final s = course.status.toUpperCase();
    return s != 'TERMINEE' && s != 'ANNULEE';
  }

  @override
  Widget build(BuildContext context) {
    final s = course.status.toUpperCase();
    final numero = course.numeroCourse.length > 8
        ? course.numeroCourse.substring(course.numeroCourse.length - 8)
        : course.numeroCourse;
    final details = [
      _timeAgo(course.createdAt),
      course.isMobileMoney ? 'Mobile Money' : 'Espèces',
      numero,
    ].join(' · ');

    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      course.contactClientNom,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(AppCurrency.format(course.prixPropose),
                      style: AppTheme.mono(size: 15, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: 0)),
                ],
              ),
              const SizedBox(height: 4),
              Text(details, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
              if (_isActive) ...[
                CourseFrise(status: course.status, expediteurLabel: 'Vous'),
                const SizedBox(height: 12),
                Text(course.statusLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.accentDark)),
              ] else
                Text(
                  s == 'TERMINEE' ? 'Livrée' : 'Annulée',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: s == 'TERMINEE' ? AppTheme.successDark : AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    return DateFormatter.jour(date);
  }
}
