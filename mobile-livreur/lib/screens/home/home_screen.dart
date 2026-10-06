import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import '../courses/courses_disponibles_screen.dart';
import '../courses/mes_courses_screen.dart';
import '../profile/profile_screen.dart';
import '../wallet/wallet_screen.dart';

import '../../providers/course_provider.dart';
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
          content: const Text('Votre compte doit être vérifié pour voir les courses disponibles'),
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
          NavigationDestination(icon: Icon(Icons.delivery_dining), selectedIcon: Icon(Icons.delivery_dining_rounded), label: 'Disponibles'),
          NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history_rounded), label: 'Mes courses'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings_rounded), label: 'Gains'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  final void Function(int)? onNavigateToTab;
  const DashboardScreen({super.key, this.onNavigateToTab});

  Future<void> _onRefresh(BuildContext context) async {
    await Future.wait([
      context.read<AuthProvider>().refreshProfile(),
      context.read<CourseProvider>().loadMesCourses(),
      context.read<WalletProvider>().loadWallet(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final loc = context.watch<LocationProvider>();
    final isOnline = loc.isTracking;
    final isVerified = auth.livreur?.isVerified == true;

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _onRefresh(context),
          color: AppTheme.accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Header
              Row(
                children: [
                  GestureDetector(
                    onTap: () => onNavigateToTab?.call(4),
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
                        Text(
                          'Bonjour',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                auth.livreur?.nomComplet ?? 'Livreur',
                                style: Theme.of(context).textTheme.headlineMedium,
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.notifications_outlined, color: AppTheme.textSecondary, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Stats
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      value: AppCurrency.format(auth.livreur?.totalGains ?? 0),
                      label: 'Gains du jour',
                      color: AppTheme.accent,
                      filled: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      value: '${auth.livreur?.nombreCoursesCompletees ?? 0}',
                      label: 'Courses',
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Online toggle
              GestureDetector(
                onTap: () async {
                  if (!isVerified) {
                    UIUtils.showError(context, 'Compte en attente de vérification');
                    return;
                  }
                  final courses = context.read<CourseProvider>();
                  final authProvider = context.read<AuthProvider>();
                  if (isOnline) {
                    loc.stopTracking();
                    courses.setDisponible(false);
                  } else {
                    await loc.startTracking();
                    if (loc.isTracking) courses.setDisponible(true);
                  }
                  // Resync de auth.livreur.isDisponible avec la BDD
                  // (LocationProvider a appelé updateDisponibilite mais le
                  // state local n'est pas notifié)
                  await authProvider.refreshProfile();
                },
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.white,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: isOnline ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.divider),
                    boxShadow: AppTheme.shadowSm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isOnline ? AppTheme.successLight : AppTheme.background,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isOnline ? Icons.power_settings_new_rounded : Icons.power_off_rounded,
                          color: isOnline ? AppTheme.success : AppTheme.textTertiary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOnline ? 'Vous êtes en ligne' : 'Vous êtes hors ligne',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isOnline ? AppTheme.success : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOnline ? 'Prêt à recevoir des courses' : 'Appuyez pour commencer',
                              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        activeThumbColor: AppTheme.success,
                        value: isOnline,
                        onChanged: (_) async {
                          final courses = context.read<CourseProvider>();
                          final authProvider = context.read<AuthProvider>();
                          if (loc.isTracking) {
                            loc.stopTracking();
                            courses.setDisponible(false);
                          } else {
                            await loc.startTracking();
                            if (loc.isTracking) courses.setDisponible(true);
                          }
                          await authProvider.refreshProfile();
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),
              Text(
                'Actions rapides',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 14),

              _ActionTile(
                icon: Icons.delivery_dining_rounded,
                title: 'Trouver des courses',
                subtitle: 'Voir les courses à proximité',
                color: AppTheme.accent,
                onTap: () => onNavigateToTab?.call(1),
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.history_rounded,
                title: 'Historique des gains',
                subtitle: 'Détails de vos revenus',
                color: AppTheme.info,
                onTap: () => onNavigateToTab?.call(2),
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.savings_outlined,
                title: 'Mes gains',
                subtitle: 'Solde et retraits',
                color: AppTheme.accent,
                onTap: () => onNavigateToTab?.call(3),
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.person_rounded,
                title: 'Paramètres du profil',
                subtitle: 'Véhicule et informations',
                color: AppTheme.textSecondary,
                onTap: () => onNavigateToTab?.call(4),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool filled;
  const _StatCard({required this.value, required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    // Variante « hero » remplie (dégradé orange + glow) — utilisée pour les Gains.
    if (filled) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        decoration: BoxDecoration(
          gradient: AppTheme.accentGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.28),
              blurRadius: 18,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: AppTheme.mono(size: 22, weight: FontWeight.w800, color: AppTheme.white, spacing: -0.5)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: AppTheme.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTheme.mono(size: 22, weight: FontWeight.w700, color: color, spacing: -0.5)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textTertiary, size: 20),
          ],
        ),
      ),
    );
  }
}
