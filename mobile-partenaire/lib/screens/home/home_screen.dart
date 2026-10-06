import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import '../courses/courses_list_screen.dart';
import '../courses/create_course_screen.dart';
import '../../providers/credit_provider.dart';
import '../../widgets/course_card.dart';
import '../credit/credit_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int idx) => setState(() => _currentIndex = idx);

  late final List<Widget> _screens = [
    DashboardScreen(onNavigateToTab: _navigateToTab),
    const CoursesListScreen(),
    const CreditScreen(),
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
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Courses'),
          NavigationDestination(icon: Icon(Icons.credit_card_outlined), selectedIcon: Icon(Icons.credit_card_rounded), label: 'Crédit'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────
// DASHBOARD
// ──────────────────────────────────────────────────────
class DashboardScreen extends StatefulWidget {
  final void Function(int)? onNavigateToTab;
  const DashboardScreen({super.key, this.onNavigateToTab});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Une seule fois à l'ouverture (avant : à chaque reconstruction de l'écran).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseProvider>().loadCourses();
      context.read<CreditProvider>().loadCredit();
    });
  }

  Future<void> _onRefresh() async {
    await Future.wait([
      context.read<AuthProvider>().loadExpediteur(),
      context.read<CourseProvider>().loadCourses(),
      context.read<CreditProvider>().loadCredit(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cmd = context.watch<CourseProvider>();
    final credit = context.watch<CreditProvider>();
    final verifie = auth.expediteur?.isVerified == true;
    final pretty = GuineaPhone.formatPretty(auth.user?.phone);
    final nom = auth.expediteur?.nom ?? (pretty.isEmpty ? 'Expéditeur' : pretty);
    final enCours = cmd.coursesEnCours;
    final recentes = enCours.isEmpty ? cmd.courses.take(3).toList() : enCours;

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
                    const Text('Bonjour', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Flexible(
                          child: Text(nom,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 8),
                        const BrandDots(size: 5),
                      ],
                    ),
                    const SizedBox(height: 24),

                    if (!verifie) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: AppTheme.warningLight, borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Compte en cours de vérification',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.warningDark)),
                            SizedBox(height: 4),
                            Text(
                              'Notre équipe valide votre compte. Vous pourrez créer des courses dès la validation.',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Crédit (chiffre héros) ──
                    Material(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      child: InkWell(
                        onTap: () => widget.onNavigateToTab?.call(2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Expanded(
                                    child: Text('Votre Crédit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                  ),
                                  Text('Recharger', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.accentDark)),
                                  Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.accentDark),
                                ],
                              ),
                              const SizedBox(height: 8),
                              credit.isLoading && credit.solde == 0
                                  ? const SizedBox(height: 40, child: Align(alignment: Alignment.centerLeft, child: BrandDotsPulse(color: AppTheme.accent)))
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(AppCurrency.format(credit.solde),
                                          style: AppTheme.mono(size: 40, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -1)),
                                    ),
                              const SizedBox(height: 8),
                              Text(
                                credit.fraisRetourDus > 0
                                    ? '${AppCurrency.format(credit.fraisRetourDus)} de frais de retour à régler : rechargez pour créer des courses.'
                                    : credit.solde < 1200
                                        ? 'Crédit trop bas pour créer une course : rechargez-le.'
                                        : 'Couvre la commission Sönaiyaa (12 %) de vos courses.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: credit.solde < 1200 || credit.fraisRetourDus > 0 ? AppTheme.accentDark : AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // ── Courses ──
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Text(enCours.isEmpty ? 'Courses récentes' : 'En cours',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        ),
                        if (cmd.courses.isNotEmpty)
                          TextButton(onPressed: () => widget.onNavigateToTab?.call(1), child: const Text('Tout voir')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (cmd.courses.isEmpty && cmd.isLoading)
                      const SizedBox(height: 120, child: LoadingState())
                    else if (cmd.courses.isEmpty && !NetworkService().isOnline)
                      OfflineState(onRetry: cmd.loadCourses)
                    else if (cmd.courses.isEmpty && cmd.error != null)
                      ErrorState(message: cmd.error, onRetry: cmd.loadCourses)
                    else if (cmd.courses.isEmpty)
                      const EmptyState(
                        icon: Icons.receipt_long_outlined,
                        title: 'Aucune course pour le moment',
                        message: 'Créez votre première course en moins de 30 secondes.',
                      )
                    else
                      for (final c in recentes) ...[
                        CourseCard(course: c),
                        const SizedBox(height: 12),
                      ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: PrimaryCta(
                label: !verifie
                    ? 'Compte en cours de vérification'
                    : (credit.fraisRetourDus > 0 ? 'Rechargez pour créer une course' : 'Nouvelle course'),
                onPressed: !verifie
                    ? null
                    : credit.fraisRetourDus > 0
                        ? () => widget.onNavigateToTab?.call(2)
                        : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCourseScreen())),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
