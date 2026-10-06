import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import '../../widgets/course_en_cours_card.dart';
import 'package:mobile_core/mobile_core.dart';
import 'course_active_screen.dart';

/// Onglet « Historique » : courses en cours (frise) puis courses passées,
/// regroupées par jour.
class MesCoursesScreen extends StatefulWidget {
  const MesCoursesScreen({super.key});

  @override
  State<MesCoursesScreen> createState() => _MesCoursesScreenState();
}

class _MesCoursesScreenState extends State<MesCoursesScreen> with WidgetsBindingObserver {
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final courses = context.read<CourseProvider>();
      if (courses.mesCourses.isEmpty) courses.loadMesCourses();
    });
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) context.read<CourseProvider>().loadMesCourses();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<CourseProvider>().loadMesCourses();
    }
  }

  void _ouvrir(Course course) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CourseActiveScreen(course: course)),
    ).then((_) {
      if (mounted) context.read<CourseProvider>().loadMesCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseProvider>();
    bool passee(Course c) {
      final s = c.status.toUpperCase();
      return s == 'TERMINEE' || s == 'ANNULEE';
    }

    final enCours = courses.mesCourses.where((c) => !passee(c)).toList();
    final passees = courses.mesCourses.where(passee).toList();

    // Regroupement par jour (date de livraison, sinon de création).
    final groupes = <(String, List<Course>)>[];
    for (final c in passees) {
      final titre = DateFormatter.jour(c.livreeAt ?? c.createdAt).toUpperCase();
      if (groupes.isEmpty || groupes.last.$1 != titre) {
        groupes.add((titre, [c]));
      } else {
        groupes.last.$2.add(c);
      }
    }

    Widget? etatVide;
    if (courses.mesCourses.isEmpty) {
      if (courses.isLoading) {
        etatVide = const LoadingState(message: 'Chargement de vos courses');
      } else if (!NetworkService().isOnline) {
        etatVide = OfflineState(onRetry: courses.loadMesCourses);
      } else if (courses.error != null) {
        etatVide = ErrorState(message: courses.error, onRetry: courses.loadMesCourses);
      } else {
        etatVide = const EmptyState(
          icon: Icons.history_rounded,
          title: 'Pas encore de course',
          message: 'Acceptez votre première course depuis l\'onglet Courses. Vos livraisons apparaîtront ici.',
        );
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: courses.loadMesCourses,
          color: AppTheme.accent,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: Text('Historique', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                ),
              ),
              if (etatVide != null)
                SliverFillRemaining(hasScrollBody: false, child: etatVide),

              for (final c in enCours)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  sliver: SliverToBoxAdapter(child: CourseEnCoursCard(course: c, onTap: () => _ouvrir(c))),
                ),

              for (final g in groupes)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(g.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < g.$2.length; i++) ...[
                                if (i > 0) const Divider(height: 1),
                                _LignePassee(course: g.$2[i]),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Course passée : livrée (montant gagné) ou annulée ──
class _LignePassee extends StatelessWidget {
  final Course course;
  const _LignePassee({required this.course});

  @override
  Widget build(BuildContext context) {
    final livree = course.status.toUpperCase() == 'TERMINEE';
    final heure = DateFormatter.timeOnly(livree ? (course.livreeAt ?? course.createdAt) : course.createdAt);
    final detail = livree
        ? '$heure · ${course.isMobileMoney ? 'Mobile Money' : 'Espèces'}'
        : '$heure · Annulée';

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: livree ? AppTheme.successLight : AppTheme.background,
              shape: BoxShape.circle,
            ),
            child: Icon(
              livree ? Icons.check_rounded : Icons.close_rounded,
              size: 20,
              color: livree ? AppTheme.successDark : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${course.expediteurNom ?? 'Expéditeur'} → ${course.contactClientNom}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(detail, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
          if (livree)
            Text(
              '+${AppCurrency.format(course.montantLivreur)}',
              style: AppTheme.mono(size: 15, weight: FontWeight.w800, color: AppTheme.successDark, spacing: 0),
            ),
        ],
      ),
    );
  }
}
