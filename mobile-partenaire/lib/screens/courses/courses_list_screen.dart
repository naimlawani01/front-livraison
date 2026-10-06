import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import '../../providers/auth_provider.dart';
import '../../providers/credit_provider.dart';
import '../../widgets/course_card.dart';
import 'create_course_screen.dart';

/// Onglet « Courses » de l'expéditeur : filtres, courses avec leur frise,
/// et « Nouvelle course » en action principale.
class CoursesListScreen extends StatefulWidget {
  const CoursesListScreen({super.key});

  @override
  State<CoursesListScreen> createState() => _CoursesListScreenState();
}

class _CoursesListScreenState extends State<CoursesListScreen> with WidgetsBindingObserver {
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

  void _nouvelleCourse() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCourseScreen()));
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

    Widget liste;
    if (filtered.isEmpty) {
      Widget etat;
      if (cmd.isLoading) {
        etat = const LoadingState(message: 'Chargement de vos courses');
      } else if (cmd.courses.isEmpty && !NetworkService().isOnline) {
        etat = OfflineState(onRetry: cmd.loadCourses);
      } else if (cmd.courses.isEmpty && cmd.error != null) {
        etat = ErrorState(message: cmd.error, onRetry: cmd.loadCourses);
      } else if (_selectedFilter == 'en_cours') {
        etat = const EmptyState(icon: Icons.delivery_dining_rounded, title: 'Aucune course en cours', message: 'Vos courses actives apparaîtront ici.');
      } else if (_selectedFilter == 'terminees') {
        etat = const EmptyState(icon: Icons.task_alt_rounded, title: 'Aucune course terminée', message: 'Vos courses livrées apparaîtront ici.');
      } else {
        etat = const EmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'Aucune course pour le moment',
          message: 'Créez votre première course : un livreur proche viendra chercher le colis.',
        );
      }
      liste = LayoutBuilder(
        builder: (_, c) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [SizedBox(height: c.maxHeight, child: etat)],
        ),
      );
    } else {
      liste = ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => CourseCard(course: filtered[i]),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Courses', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(_subtitle(cmd), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ],
              ),
            ),

            // ── Filtres ──
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final (cle, label, nb) in [
                    ('all', 'Toutes', cmd.courses.length),
                    ('en_cours', 'En cours', cmd.coursesEnCours.length),
                    ('terminees', 'Terminées', cmd.coursesTerminees.length),
                  ]) ...[
                    ChoiceChip(
                      label: Text(nb > 0 ? '$label · $nb' : label),
                      selected: _selectedFilter == cle,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _selectedFilter = cle),
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _selectedFilter == cle ? AppTheme.accentDark : AppTheme.textPrimary,
                      ),
                      backgroundColor: AppTheme.cardBg,
                      selectedColor: AppTheme.accentLight,
                      side: BorderSide(color: _selectedFilter == cle ? AppTheme.accent : AppTheme.divider, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: RefreshIndicator(
                onRefresh: () => cmd.loadCourses(),
                color: AppTheme.accent,
                child: liste,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: context.watch<AuthProvider>().expediteur?.isVerified != true
                  ? const PrimaryCta(label: 'Compte en cours de vérification', onPressed: null)
                  : context.watch<CreditProvider>().fraisRetourDus > 0
                      // Frais de retour impayés : le backend refuserait la création.
                      ? const PrimaryCta(label: 'Frais de retour à régler : rechargez', onPressed: null)
                      : PrimaryCta(label: 'Nouvelle course', onPressed: _nouvelleCourse),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(CourseProvider cmd) {
    final enCours = cmd.coursesEnCours.length;
    if (enCours == 0) return 'Aucune course en cours';
    if (enCours == 1) return '1 course en cours';
    return '$enCours courses en cours';
  }
}
