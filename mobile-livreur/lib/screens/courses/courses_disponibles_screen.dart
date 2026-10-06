import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/location_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import 'course_active_screen.dart';

class CoursesDisponiblesScreen extends StatefulWidget {
  const CoursesDisponiblesScreen({super.key});

  @override
  State<CoursesDisponiblesScreen> createState() => _CoursesDisponiblesScreenState();
}

class _CoursesDisponiblesScreenState extends State<CoursesDisponiblesScreen>
    with WidgetsBindingObserver {
  Timer? _autoRefreshTimer;
  // Course mise en avant (carte détaillée + bouton « Accepter » en bas).
  // Par défaut la première de la liste ; reste choisie tant qu'elle existe.
  String? _selectedId;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
    // Auto-refresh toutes les 15s — important pour les courses dispo qui
    // tournent vite (premier livreur à accepter prend la course).
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) => _loadAll());
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadAll();
  }

  // NE PAS utiliser didChangeDependencies — il serait appelé à chaque
  // notifyListeners() du CourseProvider, créant une boucle infinie d'API calls.

  Future<void> _loadAll() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.livreur?.isVerified != true) return;
    if (auth.livreur?.isDisponible != true) return;
    await _load();
    if (mounted) context.read<CourseProvider>().loadMesCourses();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final loc = context.read<LocationProvider>();
    final pos = loc.currentPosition;
    await context.read<CourseProvider>().loadCoursesDisponibles(lat: pos?.latitude, lon: pos?.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.livreur?.isVerified != true) {
      return _buildBlockedScreen(context, verified: false);
    }
    if (auth.livreur?.isDisponible != true) {
      return _buildBlockedScreen(context, verified: true);
    }

    final courses = context.watch<CourseProvider>();
    final loc = context.watch<LocationProvider>();
    final list = courses.coursesDisponibles;
    final selected = list.where((c) => c.id == _selectedId).firstOrNull ?? list.firstOrNull;
    final full = _isFull(courses);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Courses près de vous', style: Theme.of(context).textTheme.headlineMedium)),
                  // Bouton refresh manuel
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 22),
                    color: AppTheme.textSecondary,
                    tooltip: 'Actualiser',
                  ),
                  // GPS indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: loc.isTracking ? AppTheme.successLight : AppTheme.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          loc.isTracking ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                          size: 14,
                          color: loc.isTracking ? AppTheme.success : AppTheme.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          loc.isTracking ? 'GPS' : 'GPS off',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: loc.isTracking ? AppTheme.success : AppTheme.textTertiary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                '${list.length} course${list.length > 1 ? 's' : ''} ${loc.isTracking ? 'à proximité' : ''}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 12),

            // Bannière info courses actives
            if (_activeCount(courses) > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isFull(courses) ? AppTheme.warningLight : AppTheme.infoLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: (_isFull(courses) ? AppTheme.warning : AppTheme.info).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isFull(courses) ? Icons.info_outline_rounded : Icons.delivery_dining_rounded,
                        size: 18,
                        color: _isFull(courses) ? AppTheme.warning : AppTheme.info,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isFull(courses)
                              ? '${_activeCount(courses)}/2 courses en cours — Terminez-en une pour en accepter une nouvelle.'
                              : '${_activeCount(courses)}/2 course en cours — Vous pouvez encore en accepter une.',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppTheme.accent,
                child: courses.isLoading && list.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                    : list.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [_EmptyState(gpsOn: loc.isTracking)],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => list[i].id == selected?.id
                                ? _CourseCard(course: list[i])
                                : _CourseRow(
                                    course: list[i],
                                    onTap: () => setState(() => _selectedId = list[i].id),
                                  ),
                          ),
              ),
            ),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: PrimaryCta(
                  label: full ? 'Terminez une course en cours' : 'Accepter la course',
                  loading: _accepting,
                  onPressed: full ? null : () => _accept(selected),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockedScreen(BuildContext context, {required bool verified}) {
    final isOffline = verified;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isOffline ? AppTheme.background : AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    isOffline ? Icons.wifi_off_rounded : Icons.lock_outline_rounded,
                    size: 36,
                    color: isOffline ? AppTheme.textTertiary : AppTheme.warning,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isOffline ? 'Vous êtes hors ligne' : 'Compte non vérifié',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  isOffline
                      ? 'Activez votre statut « En ligne » depuis l\'écran principal pour voir les courses disponibles.'
                      : 'Un administrateur doit vérifier votre compte avant que vous puissiez voir et accepter des courses.',
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppTheme.textTertiary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'En attendant, complétez votre profil et vos documents pour accélérer la vérification.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
                        ),
                      ),
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

  static const int _maxCourses = 2;

  int _activeCount(CourseProvider provider) {
    return provider.mesCourses.where((c) {
      final s = c.status.toUpperCase();
      return s == 'ACCEPTEE' || s == 'EN_RECUPERATION' || s == 'EN_LIVRAISON';
    }).length;
  }

  bool _isFull(CourseProvider provider) => _activeCount(provider) >= _maxCourses;

  Future<void> _accept(Course course) async {
    if (_accepting) return;
    setState(() => _accepting = true);
    final provider = context.read<CourseProvider>();
    final ok = await provider.accepterCourse(course.id);
    if (!mounted) return;
    setState(() => _accepting = false);

    if (ok) {
      HapticFeedback.mediumImpact();
      // Récupérer la course acceptée depuis le provider
      final acceptedCourse = provider.currentCourse ?? course;
      // Naviguer directement vers l'écran de course active
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CourseActiveScreen(course: acceptedCourse)),
        ).then((_) {
          // Recharger les disponibles au retour
          if (mounted) _load();
        });
      }
    } else {
      final err = provider.error ?? '';
      final msg = err.toLowerCase().contains('déjà') || err.toLowerCase().contains('prise')
          ? 'Un autre livreur vous a devancé — cette course n\'est plus disponible'
          : err.isNotEmpty
              ? err
              : 'Impossible d\'accepter cette course';
      UIUtils.showError(context, msg);
    }
  }
}

// ──────────────────────────────────────────────────────
// COURSE CARD (direction A « chiffre héros ») — la course sélectionnée.
// Les gains en très grand, distance/durée/paiement en pastilles, trajet
// Expéditeur → Client en deux points reliés. L'action est le bouton du bas.
// ──────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final Course course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final cash = course.montantCashARecuperer;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.accent, width: 2),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Vos gains', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              AppCurrency.format(course.montantLivreur),
              style: AppTheme.mono(size: 40, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -1),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (course.distanceKm != null) _Pill(label: '${course.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km'),
              if (course.dureeEstimeeMinutes != null) _Pill(label: '≈ ${course.dureeEstimeeMinutes} min'),
              _Pill(label: course.isMobileMoney ? 'Mobile Money' : 'Espèces', accent: true),
            ],
          ),
          const SizedBox(height: 20),
          _Trajet(course: course),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              cash > 0
                  ? 'Récupérez ${AppCurrency.format(cash)} en espèces auprès de l\'expéditeur'
                  : 'Payée par Mobile Money : vos gains sont crédités à la livraison',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentDark, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _Trajet extends StatelessWidget {
  final Course course;
  const _Trajet({required this.course});

  @override
  Widget build(BuildContext context) {
    final distance = course.distanceLivreurKm;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Column(
              children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle)),
                Expanded(child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: AppTheme.divider)),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppTheme.textPrimary, width: 3)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Lieu(
                  label: distance != null
                      ? 'Récupération · Expéditeur · à ${distance.toStringAsFixed(1).replaceAll('.', ',')} km'
                      : 'Récupération · Expéditeur',
                  titre: course.expediteurNom ?? 'Expéditeur',
                  detail: course.expediteurAdresse,
                ),
                const SizedBox(height: 16),
                // Données client masquées avant acceptation (backend) : prénom
                // seul, adresse/téléphone/consignes visibles une fois acceptée.
                _Lieu(
                  label: 'Livraison · Client',
                  titre: course.contactClientNom,
                  detail: course.adresseClient ?? 'Adresse exacte visible après acceptation',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Lieu extends StatelessWidget {
  final String label;
  final String titre;
  final String? detail;
  const _Lieu({required this.label, required this.titre, this.detail});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
        if (detail != null && detail!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(detail!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool accent;
  const _Pill({required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent ? AppTheme.accentLight : AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Text(
        label,
        style: AppTheme.mono(size: 15, weight: FontWeight.w800, color: accent ? AppTheme.accentDark : AppTheme.textPrimary, spacing: 0),
      ),
    );
  }
}

// Autre course disponible, en ligne compacte : toucher pour la mettre en avant.
class _CourseRow extends StatelessWidget {
  final Course course;
  final VoidCallback onTap;
  const _CourseRow({required this.course, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final details = [
      if (course.distanceKm != null) '${course.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km',
      if (course.expediteurNom != null) course.expediteurNom!,
      course.isMobileMoney ? 'Mobile Money' : 'Espèces',
    ].join(' · ');
    return Material(
      color: AppTheme.cardBg,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.shadowSm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppCurrency.format(course.montantLivreur),
                      style: AppTheme.mono(size: 20, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -0.3),
                    ),
                    const SizedBox(height: 4),
                    Text(details, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// EMPTY STATE
// ──────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final bool gpsOn;
  const _EmptyState({required this.gpsOn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                   Icon(Icons.delivery_dining_rounded, size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.5)),
                   if (gpsOn)
                     const Positioned(
                       bottom: 20, right: 20,
                       child: Icon(Icons.search_rounded, size: 24, color: AppTheme.accent),
                     ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              gpsOn ? 'Recherche de courses…' : 'GPS désactivé',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              gpsOn 
                ? 'Nous cherchons les meilleures opportunités autour de vous. Restez à l\'écoute !' 
                : 'Activez votre position pour voir les livraisons disponibles à proximité.',
              style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (!gpsOn) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.read<LocationProvider>().startTracking(),
                icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                label: const Text('Activer le GPS'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  minimumSize: const Size(200, 48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
