import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import '../courses/courses_list_screen.dart';
import '../courses/create_course_screen.dart';
import '../courses/course_detail_screen.dart';
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
      floatingActionButton: _currentIndex == 1
          ? Consumer<AuthProvider>(
              builder: (context, auth, _) {
                final verified = auth.expediteur?.isVerified == true;
                return FloatingActionButton.extended(
                  onPressed: verified
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCourseScreen()))
                      : null,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nouvelle'),
                  backgroundColor: verified ? null : AppTheme.textTertiary,
                );
              },
            )
          : null,
    );
  }
}

// ──────────────────────────────────────────────────────
// DASHBOARD
// ──────────────────────────────────────────────────────
class DashboardScreen extends StatelessWidget {
  final void Function(int)? onNavigateToTab;
  const DashboardScreen({super.key, this.onNavigateToTab});

  Future<void> _onRefresh(BuildContext context) async {
    final auth = context.read<AuthProvider>();
    final cmd = context.read<CourseProvider>();
    await Future.wait([
      auth.loadExpediteur(),
      cmd.loadCourses(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    // Charger les courses en arrière-plan
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseProvider>().loadCourses();
    });

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _onRefresh(context),
          color: AppTheme.black,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bonjour', style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 2),
                        Builder(builder: (_) {
                          final pretty = GuineaPhone.formatPretty(user?.phone);
                          final display = auth.expediteur?.nom
                              ?? (pretty.isEmpty ? 'Expéditeur' : pretty);
                          return Row(
                            children: [
                              Flexible(
                                child: Text(
                                  display,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const BrandDots(size: 5),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppTheme.white, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Stats rapides
              Consumer<CourseProvider>(
                builder: (context, cmd, _) {
                  final total = cmd.courses.length;
                  final enCours = cmd.coursesEnCours.length;
                  final terminees = cmd.coursesTerminees.length;
                  return Row(
                    children: [
                      Expanded(child: _StatCard(value: '$total', label: 'Total', color: AppTheme.black)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(value: '$enCours', label: 'En cours', color: AppTheme.accent)),
                      const SizedBox(width: 12),
                      Expanded(child: _StatCard(value: '$terminees', label: 'Terminées', color: AppTheme.success)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),

              // CTA Principale
              Builder(builder: (ctx) {
                final isVerified = auth.expediteur?.isVerified == true;
                return GestureDetector(
                  onTap: isVerified
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateCourseScreen()))
                      : null,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: isVerified ? AppTheme.accentGradient : null,
                      color: isVerified ? null : AppTheme.textTertiary,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
                      boxShadow: isVerified
                          ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.45), blurRadius: 28, offset: const Offset(0, 14))]
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            isVerified ? Icons.add_rounded : Icons.lock_outline_rounded,
                            color: AppTheme.white, size: 26,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nouvelle course', style: TextStyle(color: AppTheme.white, fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                              const SizedBox(height: 2),
                              Text(
                                isVerified ? 'Créez une livraison en 30 secondes' : 'En attente de vérification',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                          child: Icon(isVerified ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded, color: AppTheme.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),

              // Actions secondaires
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.receipt_long_outlined,
                      label: 'Mes courses',
                      onTap: () => onNavigateToTab?.call(1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.person_outline_rounded,
                      label: 'Mon profil',
                      onTap: () => onNavigateToTab?.call(3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Info verification
              if (auth.expediteur?.isVerified != true)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.hourglass_top_rounded, color: AppTheme.warning, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'En attente de vérification',
                            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Un administrateur doit valider votre compte avant que vous puissiez créer des courses.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),

              // Courses récentes
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Courses récentes', style: Theme.of(context).textTheme.titleMedium),
                  Consumer<CourseProvider>(
                    builder: (context, cmd, _) {
                      if (cmd.courses.isEmpty) return const SizedBox.shrink();
                      return TextButton(
                        onPressed: () => onNavigateToTab?.call(1),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          minimumSize: const Size(0, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Voir tout',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Consumer<CourseProvider>(
                builder: (context, cmd, _) {
                  if (cmd.isLoading && cmd.courses.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: AppTheme.black, strokeWidth: 2),
                      ),
                    );
                  }
                  if (cmd.courses.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 32, color: AppTheme.textTertiary),
                          SizedBox(height: 8),
                          Text(
                            'Aucune course pour l\'instant',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    );
                  }
                  final recents = cmd.courses.take(4).toList();
                  return Column(
                    children: [
                      for (int i = 0; i < recents.length; i++) ...[
                        _RecentCourseCard(course: recents[i]),
                        if (i < recents.length - 1) const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),

              // Mon compte
              const SizedBox(height: 28),
              Text('MON COMPTE', style: AppTheme.mono(size: 11, weight: FontWeight.w600, color: AppTheme.textTertiary, spacing: 1.2)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Column(
                  children: [
                    _AccountTile(
                      icon: Icons.phone_iphone_rounded,
                      label: 'Téléphone',
                      value: GuineaPhone.formatPretty(user?.phone).isEmpty ? '-' : GuineaPhone.formatPretty(user?.phone),
                    ),
                    const Divider(height: 1, color: AppTheme.divider, indent: 64, endIndent: 16),
                    const _AccountTile(
                      icon: Icons.badge_outlined,
                      label: 'Rôle',
                      value: 'Expéditeur',
                    ),
                    const Divider(height: 1, color: AppTheme.divider, indent: 64, endIndent: 16),
                    _AccountTile(
                      icon: Icons.verified_outlined,
                      label: 'Statut',
                      value: auth.expediteur?.isVerified == true ? 'Vérifié' : 'En attente',
                      valueColor: auth.expediteur?.isVerified == true ? AppTheme.success : AppTheme.warning,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
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
  const _StatCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(value, style: AppTheme.mono(size: 24, weight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.onTap});

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
            Icon(icon, size: 20, color: AppTheme.textSecondary),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  const _AccountTile({required this.icon, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Icon(icon, size: 18, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                const SizedBox(height: 1),
                Text(value, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: valueColor ?? AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentCourseCard extends StatelessWidget {
  final Course course;
  const _RecentCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CourseDetailScreen(course: course)),
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusBg(course.status),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _statusIcon(course.status),
                  color: _statusFg(course.status),
                  size: 20,
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
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      course.statusLabel,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppCurrency.format(course.prixPropose),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(String s) {
    switch (s.toUpperCase()) {
      case 'TERMINEE':
        return Icons.check_rounded;
      case 'ANNULEE':
        return Icons.close_rounded;
      case 'CREEE':
      case 'DIFFUSEE':
        return Icons.search_rounded;
      default:
        return Icons.local_shipping_outlined;
    }
  }

  Color _statusBg(String s) {
    switch (s.toUpperCase()) {
      case 'TERMINEE':
        return AppTheme.successLight;
      case 'ANNULEE':
        return AppTheme.errorLight;
      case 'CREEE':
      case 'DIFFUSEE':
        return AppTheme.infoLight;
      default:
        return AppTheme.accentLight;
    }
  }

  Color _statusFg(String s) {
    switch (s.toUpperCase()) {
      case 'TERMINEE':
        return AppTheme.success;
      case 'ANNULEE':
        return AppTheme.error;
      case 'CREEE':
      case 'DIFFUSEE':
        return AppTheme.info;
      default:
        return AppTheme.accent;
    }
  }
}
