import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import 'course_active_screen.dart';

class MesCoursesScreen extends StatefulWidget {
  const MesCoursesScreen({super.key});

  @override
  State<MesCoursesScreen> createState() => _MesCoursesScreenState();
}

class _MesCoursesScreenState extends State<MesCoursesScreen>
    with WidgetsBindingObserver {
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

  @override
  Widget build(BuildContext context) {
    final courses = context.watch<CourseProvider>();
    final active = courses.mesCourses.where((c) {
      final s = c.status.toUpperCase();
      return s != 'TERMINEE' && s != 'ANNULEE';
    }).toList();
    final history = courses.mesCourses.where((c) {
      final s = c.status.toUpperCase();
      return s == 'TERMINEE' || s == 'ANNULEE';
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => courses.loadMesCourses(),
          color: AppTheme.accent,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Text('Mes courses',
                      style: Theme.of(context).textTheme.headlineMedium),
                ),
              ),

              // Course active en priorité
              if (active.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text('En cours',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _ActiveCourseCard(
                        course: active[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  CourseActiveScreen(course: active[i])),
                        ).then((_) => courses.loadMesCourses()),
                      ),
                    ),
                    childCount: active.length,
                  ),
                ),
              ],

              // Historique
              if (history.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text('Historique',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: _HistoryRow(course: history[i]),
                    ),
                    childCount: history.length,
                  ),
                ),
              ],

              // Empty
              if (courses.mesCourses.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(40, 60, 40, 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: AppTheme.divider),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.delivery_dining_rounded,
                                size: 42,
                                color: AppTheme.textTertiary
                                    .withValues(alpha: 0.6),
                              ),
                              Positioned(
                                bottom: 18,
                                right: 18,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppTheme.white, width: 2),
                                  ),
                                  child: const Icon(Icons.history_rounded,
                                      size: 12, color: AppTheme.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Pas encore de course',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Acceptez votre première course depuis l\'onglet Disponibles. Vos livraisons et gains apparaîtront ici.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Course active : carte cliquable vers l'écran dédié ──
class _ActiveCourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  const _ActiveCourseCard({required this.course, required this.onTap});

  bool get _isCash => course.modePaiement.toUpperCase() == 'CASH';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Ink(
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.28),
              blurRadius: 18,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── En-tête : status + badge paiement + montant ──
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.success,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.success.withValues(alpha: 0.6),
                            blurRadius: 6,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _stepLabel,
                        style: const TextStyle(
                          color: AppTheme.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _DarkPaymentBadge(isCash: _isCash),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Trajet ──
                Row(
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                            width: 1.5, height: 22, color: Colors.white24),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white54, width: 1.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.expediteurNom ?? 'Expediteur',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            course.contactClientNom,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Montant à droite
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Vous gagnez',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppCurrency.format(course.montantLivreur),
                          style: AppTheme.mono(
                            color: AppTheme.white,
                            size: 18,
                            weight: FontWeight.w800,
                            spacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── CTA "Voir le détail" ──
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Voir le détail',
                        style: TextStyle(
                          color: AppTheme.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded,
                          size: 14, color: AppTheme.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _stepLabel {
    switch (course.status.toUpperCase()) {
      case 'ACCEPTEE':
        return 'En route vers le expediteur';
      case 'EN_RECUPERATION':
        return 'Récupération en cours';
      case 'EN_LIVRAISON':
        return 'En livraison vers le client';
      default:
        return course.statusLabel;
    }
  }
}

// Badge mode paiement adapté pour fond noir
class _DarkPaymentBadge extends StatelessWidget {
  final bool isCash;
  const _DarkPaymentBadge({required this.isCash});

  @override
  Widget build(BuildContext context) {
    final icon = isCash ? Icons.payments_outlined : Icons.phone_android_rounded;
    final label = isCash ? 'Espèces' : 'Mobile Money';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Historique : carte avec décomposition financière ──
class _HistoryRow extends StatelessWidget {
  final Course course;
  const _HistoryRow({required this.course});

  @override
  Widget build(BuildContext context) {
    final done = course.status.toUpperCase() == 'TERMINEE';
    final isCash = course.modePaiement.toUpperCase() == 'CASH';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête : icône status + (nom + date) + montant
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: done ? AppTheme.successLight : AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  done ? Icons.check_rounded : Icons.close_rounded,
                  size: 18,
                  color: done ? AppTheme.success : AppTheme.error,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.contactClientNom,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // Date sur sa propre ligne — elle peut être longue
                    // ("Aujourd'hui 14:32", "Il y a 5 jours", etc.)
                    Text(
                      _formatDate(done
                          ? (course.livreeAt ?? course.createdAt)
                          : course.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (done)
                Text(
                  AppCurrency.format(course.montantLivreur),
                  style: AppTheme.mono(
                    size: 16,
                    weight: FontWeight.w800,
                    color: AppTheme.success,
                    spacing: -0.2,
                  ),
                ),
            ],
          ),
          if (done) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(
              children: [
                _MiniBadge(
                  icon: isCash
                      ? Icons.payments_outlined
                      : Icons.phone_android_rounded,
                  label: isCash ? 'Espèces' : 'Mobile Money',
                  color: isCash ? AppTheme.warning : AppTheme.info,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Course ${AppCurrency.format(course.prixPropose)} · Commission −${AppCurrency.format(course.commissionPlateforme)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              'Annulée',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return "Aujourd'hui ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    }
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniBadge(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
