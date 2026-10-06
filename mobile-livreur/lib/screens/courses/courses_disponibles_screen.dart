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

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  Expanded(child: Text('Disponibles', style: Theme.of(context).textTheme.headlineMedium)),
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
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                            itemCount: list.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _CourseCard(
                              course: list[i],
                              onAccept: () => _accept(list[i]),
                              canAccept: !_isFull(courses),
                            ),
                          ),
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
      backgroundColor: AppTheme.white,
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
    final provider = context.read<CourseProvider>();
    final ok = await provider.accepterCourse(course.id);
    if (!mounted) return;

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
// COURSE CARD — Style Uber, avec décomposition financière
// ──────────────────────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final Course course;
  final VoidCallback onAccept;
  final bool canAccept;
  const _CourseCard({required this.course, required this.onAccept, this.canAccept = true});

  bool get _isCash => course.modePaiement.toUpperCase() == 'CASH';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header : Gain livreur + badge paiement + distance livreur ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vous gagnez',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textTertiary,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppCurrency.format(course.montantLivreur),
                            style: AppTheme.mono(
                              size: 26,
                              weight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              spacing: -0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _PaymentBadge(isCash: _isCash),
                  ],
                ),
                if (course.distanceLivreurKm != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'À ${course.distanceLivreurKm!.toStringAsFixed(1)} km de vous',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Path Indicator ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppTheme.black, shape: BoxShape.circle)),
                    Container(width: 2, height: 30, color: AppTheme.divider),
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: AppTheme.white, shape: BoxShape.circle, border: Border.all(color: AppTheme.black, width: 2))),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LocationInfo(
                        title: course.expediteurNom ?? 'EXPEDITEUR',
                        subtitle: course.expediteurAdresse ?? 'Adresse indisponible',
                        isBold: true,
                      ),
                      const SizedBox(height: 18),
                      _LocationInfo(
                        title: course.contactClientNom.toUpperCase(),
                        subtitle: course.adresseClient ?? 'Localisation client',
                        isBold: true,
                      ),
                      if (course.descriptionColis != null && course.descriptionColis!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.textTertiary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                course.descriptionColis!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Décomposition financière ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Row(
                children: [
                  _FinancialMini(
                    label: 'Course',
                    value: AppCurrency.format(course.prixPropose),
                  ),
                  Container(width: 1, height: 28, color: AppTheme.divider),
                  _FinancialMini(
                    label: 'Commission',
                    value: '−${AppCurrency.format(course.commissionPlateforme)}',
                    valueColor: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),

          // ── Footer : Distance/Durée + bouton ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (course.distanceKm != null)
                  _MiniStat(icon: Icons.route_rounded, label: '${course.distanceKm!.toStringAsFixed(1)} KM'),
                const SizedBox(width: 16),
                if (course.dureeEstimeeMinutes != null)
                  _MiniStat(icon: Icons.timer_outlined, label: '${course.dureeEstimeeMinutes} MIN'),
                const Spacer(),
                GestureDetector(
                  onTap: canAccept ? onAccept : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: canAccept ? AppTheme.accentGradient : null,
                      color: canAccept ? null : AppTheme.divider,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: canAccept
                          ? [
                              BoxShadow(
                                color: AppTheme.accent.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Text(
                      canAccept ? 'Accepter' : 'Max atteint',
                      style: TextStyle(
                        color: canAccept ? AppTheme.white : AppTheme.textTertiary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge mode de paiement ────────────────────────────────────────────────
class _PaymentBadge extends StatelessWidget {
  final bool isCash;
  const _PaymentBadge({required this.isCash});

  @override
  Widget build(BuildContext context) {
    final color = isCash ? AppTheme.warning : AppTheme.success;
    final bg = isCash ? AppTheme.warningLight : AppTheme.successLight;
    final icon = isCash ? Icons.payments_outlined : Icons.phone_android_rounded;
    final label = isCash ? 'Espèces' : 'Mobile Money';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
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

class _FinancialMini extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _FinancialMini({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textTertiary,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTheme.mono(
                size: 13,
                weight: FontWeight.w700,
                color: valueColor ?? AppTheme.textPrimary,
                spacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationInfo extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isBold;
  const _LocationInfo({required this.title, required this.subtitle, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w600 : FontWeight.w500, color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textTertiary),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textTertiary)),
      ],
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
