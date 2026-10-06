import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import '../courses/course_active_screen.dart';
import '../courses/courses_disponibles_screen.dart';
import '../courses/mes_courses_screen.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

import '../../providers/course_provider.dart';
import '../../widgets/course_en_cours_card.dart';
import '../../providers/wallet_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAfterBoot());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final courses = context.read<CourseProvider>();
    final wallet = context.read<WalletProvider>();
    // Reconnexion WebSocket immédiate (sans attendre les 5 sec de délai)
    if (auth.livreur != null) courses.onAppResumed(auth.livreur!.userId);
    // Rafraîchir toutes les données
    auth.refreshProfile();
    courses.loadMesCourses();
    wallet.loadWallet();
  }

  Future<void> _initAfterBoot() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final courses = context.read<CourseProvider>();
    final loc = context.read<LocationProvider>();
    final wallet = context.read<WalletProvider>();

    if (auth.livreur != null) {
      courses.initWebSocket(
        auth.livreur!.userId,
        isDisponible: auth.livreur!.isDisponible,
      );

      // Restaurer l'état en ligne si le livreur était actif avant le redémarrage.
      // auth.init() remet is_disponible=false côté backend pour la sécurité ;
      // ici on le remet en ligne automatiquement si l'arrêt n'était pas volontaire.
      if (!loc.isTracking && auth.livreur!.isVerified) {
        final prefs = await SharedPreferences.getInstance();
        if (prefs.getBool('livreur_was_online') == true) {
          await loc.startTracking();
          if (loc.isTracking && mounted) courses.setDisponible(true);
        }
      }
    }

    if (mounted) courses.onCourseTerminee = () => wallet.loadWallet();
  }

  void _navigateToTab(int idx) {
    final auth = context.read<AuthProvider>();
    final verified = auth.livreur?.isVerified == true;
    if (!verified && idx == 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Votre compte est en cours de vérification : les courses seront visibles une fois validé.'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Actualiser les courses dispo à chaque fois qu'on tape sur l'onglet
    if (idx == 1 && auth.livreur?.isDisponible == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final loc = context.read<LocationProvider>();
        final pos = loc.currentPosition;
        context.read<CourseProvider>().loadCoursesDisponibles(
          lat: pos?.latitude,
          lon: pos?.longitude,
        );
      });
    }

    setState(() => _currentIndex = idx);
  }

  late final List<Widget> _screens = [
    DashboardScreen(onNavigateToTab: _navigateToTab),
    const CoursesDisponiblesScreen(),
    const MesCoursesScreen(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateToTab,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.space_dashboard_outlined), selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.delivery_dining), selectedIcon: Icon(Icons.delivery_dining_rounded), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'Historique'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings_rounded), label: 'Gains'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  final void Function(int)? onNavigateToTab;
  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _toggling = false;

  static const _statutsActifs = {'ACCEPTEE', 'EN_RECUPERATION', 'EN_LIVRAISON', 'RETOUR'};

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<AuthProvider>().refreshProfile(),
      context.read<CourseProvider>().loadMesCourses(),
      context.read<WalletProvider>().loadWallet(),
    ]);
  }

  Future<void> _basculerEnLigne() async {
    if (_toggling) return;
    final auth = context.read<AuthProvider>();
    if (auth.livreur?.isVerified != true) {
      UIUtils.showError(context, 'Votre compte est en cours de vérification');
      return;
    }
    final loc = context.read<LocationProvider>();
    final courses = context.read<CourseProvider>();
    setState(() => _toggling = true);
    if (loc.isTracking) {
      loc.stopTracking();
      courses.setDisponible(false);
    } else {
      await loc.startTracking();
      if (loc.isTracking) courses.setDisponible(true);
    }
    // Resync de auth.livreur.isDisponible avec la BDD (LocationProvider a
    // appelé updateDisponibilite mais le state local n'est pas notifié).
    await auth.refreshProfile();
    if (mounted) setState(() => _toggling = false);
  }

  void _reprendre(Course course) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CourseActiveScreen(course: course)));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loc = context.watch<LocationProvider>();
    final courses = context.watch<CourseProvider>();
    final wallet = context.watch<WalletProvider>();
    final isOnline = loc.isTracking;

    final active = courses.mesCourses.where((c) => _statutsActifs.contains(c.status.toUpperCase())).firstOrNull;

    // Gains du jour = courses livrées aujourd'hui (espèces + Mobile Money) :
    // le backend ne fournit que le total depuis l'inscription.
    final now = DateTime.now();
    final duJour = courses.mesCourses.where((c) {
      final d = c.livreeAt?.toLocal();
      return c.status.toUpperCase() == 'TERMINEE' && d != null && d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
    final totalJour = duJour.fold<double>(0, (t, c) => t + c.montantLivreur);
    final cashJour = duJour.where((c) => !c.isMobileMoney).fold<double>(0, (t, c) => t + c.montantLivreur);
    final gainsJour = totalJour - cashJour;

    final soldeGains = wallet.summary?.soldeDisponible ?? auth.livreur?.soldeDisponible ?? 0;

    final String ctaLabel;
    final VoidCallback? ctaAction;
    if (active != null) {
      ctaLabel = 'Reprendre la course';
      ctaAction = () => _reprendre(active);
    } else if (!isOnline) {
      ctaLabel = 'Passer en ligne';
      ctaAction = _basculerEnLigne;
    } else {
      ctaLabel = 'Voir les courses disponibles';
      ctaAction = () => widget.onNavigateToTab?.call(1);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppTheme.accent,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  children: [
                    // ── En-tête ──
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => widget.onNavigateToTab?.call(4),
                          child: UserAvatar(
                            photoUrl: auth.livreur?.photoProfilUrl,
                            name: auth.livreur?.nomComplet,
                            size: 48,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Bonjour', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      (auth.livreur?.nomComplet ?? 'Livreur').split(' ').first,
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const BrandDots(size: 5),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── En ligne / hors ligne ──
                    _InterrupteurEnLigne(enLigne: isOnline, enCours: _toggling, onTap: _basculerEnLigne),
                    const SizedBox(height: 12),

                    // ── Aujourd'hui (chiffre héros) ──
                    _Carte(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Aujourd\'hui', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              AppCurrency.format(totalJour),
                              style: AppTheme.mono(size: 40, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -1),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            duJour.isEmpty
                                ? 'Aucune course livrée aujourd\'hui'
                                : '${duJour.length} course${duJour.length > 1 ? 's' : ''} · ${AppCurrency.format(cashJour)} en espèces · ${AppCurrency.format(gainsJour)} sur vos Gains',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.35),
                          ),
                        ],
                      ),
                    ),

                    // ── Course en cours ──
                    if (active != null) ...[
                      const SizedBox(height: 12),
                      CourseEnCoursCard(course: active, onTap: () => _reprendre(active)),
                    ],
                    const SizedBox(height: 12),

                    // ── Gains à retirer ──
                    Material(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      child: InkWell(
                        onTap: () => widget.onNavigateToTab?.call(3),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Gains à retirer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                    const SizedBox(height: 4),
                                    Text(
                                      AppCurrency.format(soldeGains),
                                      style: AppTheme.mono(size: 20, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -0.3),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: PrimaryCta(label: ctaLabel, loading: _toggling, onPressed: ctaAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  final Widget child;
  const _Carte({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowMd,
      ),
      child: child,
    );
  }
}

class _InterrupteurEnLigne extends StatelessWidget {
  final bool enLigne;
  final bool enCours;
  final VoidCallback onTap;
  const _InterrupteurEnLigne({required this.enLigne, required this.enCours, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = enLigne ? AppTheme.successDark : AppTheme.textPrimary;
    return Semantics(
      toggled: enLigne,
      label: enLigne ? 'En ligne' : 'Hors ligne',
      child: Material(
        color: enLigne ? AppTheme.successLight : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: InkWell(
          onTap: enCours ? null : onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: enLigne ? AppTheme.success : AppTheme.textSecondary,
                    shape: BoxShape.circle,
                    boxShadow: enLigne ? [BoxShadow(color: AppTheme.success.withValues(alpha: 0.2), spreadRadius: 5)] : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(enLigne ? 'Vous êtes en ligne' : 'Vous êtes hors ligne',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
                      const SizedBox(height: 2),
                      Text(enLigne ? 'Appuyez pour passer hors ligne' : 'Appuyez pour recevoir des courses',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: enLigne ? fg : AppTheme.textSecondary)),
                    ],
                  ),
                ),
                IgnorePointer(
                  child: Switch(
                    value: enLigne,
                    onChanged: (_) {},
                    activeThumbColor: AppTheme.white,
                    activeTrackColor: AppTheme.success,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
