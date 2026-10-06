import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import 'course_detail_screen.dart';
import 'create_course_screen.dart';

class CoursesListScreen extends StatefulWidget {
  const CoursesListScreen({super.key});

  @override
  State<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen>
    with WidgetsBindingObserver {
  String _selectedFilter = 'all';
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cmd = context.read<CourseProvider>();
      if (cmd.courses.isEmpty) cmd.loadCourses();
    });
    // Auto-refresh toutes les 20s tant que l'écran est actif
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) context.read<CourseProvider>().loadCourses();
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
      context.read<CourseProvider>().loadCourses();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cmd = context.watch<CourseProvider>();

    final List<Course> filtered;
    if (_selectedFilter == 'en_cours') {
      filtered = cmd.coursesEnCours;
    } else if (_selectedFilter == 'terminees') {
      filtered = cmd.coursesTerminees;
    } else {
      filtered = cmd.courses;
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Courses',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(cmd),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bouton "Nouveau"
                  Material(
                    color: AppTheme.black,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateCourseScreen()),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.add_rounded, color: AppTheme.white, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Nouvelle',
                              style: TextStyle(
                                color: AppTheme.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Filtres ──────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _Chip(
                    label: 'Toutes',
                    count: cmd.courses.length,
                    selected: _selectedFilter == 'all',
                    onTap: () => setState(() => _selectedFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: 'En cours',
                    count: cmd.coursesEnCours.length,
                    selected: _selectedFilter == 'en_cours',
                    onTap: () => setState(() => _selectedFilter = 'en_cours'),
                  ),
                  const SizedBox(width: 8),
                  _Chip(
                    label: 'Terminées',
                    count: cmd.coursesTerminees.length,
                    selected: _selectedFilter == 'terminees',
                    onTap: () => setState(() => _selectedFilter = 'terminees'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Liste ────────────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => cmd.loadCourses(),
                color: AppTheme.black,
                child: cmd.isLoading && filtered.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.black))
                    : filtered.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [_Empty()],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, i) => _CourseCard(course: filtered[i]),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(CourseProvider cmd) {
    final enCours = cmd.coursesEnCours.length;
    if (enCours == 0) {
      return 'Aucune livraison en cours';
    }
    if (enCours == 1) return '1 livraison en cours';
    return '$enCours livraisons en cours';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected ? AppTheme.black : AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.black : AppTheme.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.white : AppTheme.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.white.withOpacity(0.2) : AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppTheme.white : AppTheme.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// COURSE CARD
// ─────────────────────────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final Course course;
  const _CourseCard({required this.course});

  bool get _isCash => course.modePaiement.toUpperCase() == 'CASH';
  bool get _isActive {
    final s = course.status.toUpperCase();
    return s != 'TERMINEE' && s != 'ANNULEE';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor;

    return Material(
      color: AppTheme.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Ligne 1 : status + temps écoulé ──
              Row(
                children: [
                  _StatusBadge(label: course.statusLabel, color: statusColor, isActive: _isActive),
                  const Spacer(),
                  Text(
                    _timeAgo(course.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // ── Ligne 2 : Nom client + montant ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.contactClientNom,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 13,
                              color: AppTheme.textTertiary,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                course.adresseClient ?? 'Adresse non précisée',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppCurrency.format(course.prixPropose),
                        style: AppTheme.mono(
                          size: 17,
                          weight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          spacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        course.numeroCourse.length > 8
                            ? course.numeroCourse.substring(course.numeroCourse.length - 8)
                            : course.numeroCourse,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.textTertiary,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // ── Ligne 3 : Badge paiement + paiement confirmé ──
              Row(
                children: [
                  _PaymentBadge(isCash: _isCash),
                  if (course.paiementConfirme == 'oui') ...[
                    const SizedBox(width: 6),
                    _MiniBadge(
                      icon: Icons.check_circle_rounded,
                      label: 'Payé',
                      color: AppTheme.success,
                    ),
                  ],
                  if (course.exigeCodeLivraison) ...[
                    const SizedBox(width: 6),
                    _MiniBadge(
                      icon: Icons.lock_rounded,
                      label: 'PIN',
                      color: AppTheme.warning,
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textTertiary,
                    size: 22,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color get _statusColor {
    switch (course.status.toUpperCase()) {
      case 'CREEE':
        return AppTheme.textSecondary;
      case 'DIFFUSEE':
        return AppTheme.info;
      case 'ACCEPTEE':
      case 'EN_RECUPERATION':
      case 'EN_LIVRAISON':
        return AppTheme.warning;
      case 'TERMINEE':
        return AppTheme.success;
      case 'ANNULEE':
        return AppTheme.error;
      default:
        return AppTheme.textTertiary;
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} j';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────
// STATUS BADGE (avec point pulsant si actif)
// ─────────────────────────────────────────────────────────────────────────
class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool isActive;

  const _StatusBadge({
    required this.label,
    required this.color,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// PAYMENT BADGE
// ─────────────────────────────────────────────────────────────────────────
class _PaymentBadge extends StatelessWidget {
  final bool isCash;
  const _PaymentBadge({required this.isCash});

  @override
  Widget build(BuildContext context) {
    final color = isCash ? AppTheme.warning : AppTheme.info;
    final icon = isCash ? Icons.payments_outlined : Icons.phone_android_rounded;
    final label = isCash ? 'Espèces' : 'Mobile Money';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
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

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _MiniBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
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

// ─────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 40),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: AppTheme.textTertiary.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Aucune course',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Créez votre première livraison pour commencer.',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateCourseScreen()),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Nouvelle livraison'),
          ),
        ],
      ),
    );
  }
}
