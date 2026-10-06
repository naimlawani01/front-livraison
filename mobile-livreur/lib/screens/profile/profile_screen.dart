import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import 'documents_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  String _getDocumentStatusText(Livreur? livreur) {
    if (livreur == null) return '0 sur 3';
    int count = 0;
    if (livreur.pieceIdentiteUrl != null) count++;
    if (livreur.vehiculeDocUrl != null) count++;
    if (livreur.photoProfilUrl != null) count++;
    return '$count sur 3';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final livreur = auth.livreur;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accent,
          onRefresh: () => auth.refreshProfile(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 28),
            Row(
              children: [
                const Text('Profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Modifier'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.accentDark),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Avatar & Name
            Center(
              child: Column(
                children: [
                  UserAvatar(photoUrl: livreur?.photoProfilUrl, name: livreur?.nomComplet, size: 88),
                  const SizedBox(height: 16),
                  Text(
                    livreur?.nomComplet ?? 'Livreur',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  if (livreur != null && livreur.nombreEvaluations > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, size: 16, color: AppTheme.warning),
                        const SizedBox(width: 4),
                        Text(
                          '${livreur.noteMoyenne.toStringAsFixed(1)} (${livreur.nombreEvaluations} avis)',
                          style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    GuineaPhone.formatPretty(user?.phone),
                    style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  if (livreur?.isVerified == true) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 15, color: AppTheme.success),
                          SizedBox(width: 5),
                          Text('Vérifié', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.success)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Stats
            Row(
              children: [
                Expanded(
                  child: _StatCard(label: 'Courses livrées', value: '${livreur?.nombreCoursesCompletees ?? 0}', icon: Icons.delivery_dining_rounded, color: AppTheme.textPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(label: 'Total gagné', value: AppCurrency.format(livreur?.totalGains ?? 0), icon: Icons.payments_rounded, color: AppTheme.successDark),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Vehicle
            if (livreur != null) ...[
              _SectionHeader(title: 'Véhicule'),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Column(
                  children: [
                    if (livreur.typeVehicule != null)
                      _InfoRow(icon: Icons.two_wheeler_rounded, title: 'Type', value: livreur.typeVehicule!),
                    if (livreur.marqueModele != null)
                      _InfoRow(icon: Icons.directions_car_outlined, title: 'Modèle', value: livreur.marqueModele!),
                    _InfoRow(
                      icon: Icons.verified_user_rounded,
                      title: 'Statut du compte',
                      value: livreur.isVerified ? 'Vérifié' : 'En attente',
                      valueColor: livreur.isVerified ? AppTheme.success : AppTheme.warning,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            // Documents
            _SectionHeader(title: 'Documents'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.description_rounded,
                  title: 'Mes documents',
                  value: '${_getDocumentStatusText(livreur)} envoyés',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())),
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Settings
            _SectionHeader(title: 'Aide'),
            _SettingsCard(
              children: [
                _SettingsTile(icon: Icons.support_agent_rounded, title: 'Contacter le support', onTap: () {
                  launchUrl(Uri.parse('mailto:support@sonaiyaa.com?subject=Aide%20Sönaiyaa%20Livreur'), mode: LaunchMode.externalApplication);
                }),
                _InfoRow(icon: Icons.info_outline_rounded, title: 'Version de l\'application', value: AppVersion.short, showDivider: false),
              ],
            ),
            const SizedBox(height: 20),

            // Légal
            _SectionHeader(title: 'Légal & Confidentialité'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.description_outlined,
                  title: "Conditions d'utilisation",
                  onTap: () => launchUrl(Uri.parse('https://www.sonaiyaa.com/conditions-utilisation.html'), mode: LaunchMode.externalApplication),
                ),
                _SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Politique de confidentialité',
                  onTap: () => launchUrl(Uri.parse('https://www.sonaiyaa.com/politique-confidentialite.html'), mode: LaunchMode.externalApplication),
                  showDivider: false,
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Déconnexion / suppression
            SecondaryButton(
              label: 'Se déconnecter',
              icon: Icons.logout_rounded,
              onPressed: () => _confirmerDeconnexion(context, auth),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => _confirmerSuppression(context, auth),
              style: TextButton.styleFrom(foregroundColor: AppTheme.error),
              child: const Text('Supprimer mon compte'),
            ),
            const SizedBox(height: 60),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _confirmerSuppression(BuildContext context, AuthProvider auth) async {
    final ok = await showConfirmAction(
      context,
      icon: Icons.delete_outline_rounded,
      title: 'Supprimer votre compte ?',
      message: 'Toutes vos données personnelles seront supprimées. Retirez vos gains avant : cette action est définitive.',
      confirmLabel: 'Supprimer mon compte',
    );
    if (ok) await auth.deleteAccount();
  }

  Future<void> _confirmerDeconnexion(BuildContext context, AuthProvider auth) async {
    final ok = await showConfirmAction(
      context,
      icon: Icons.logout_rounded,
      title: 'Se déconnecter ?',
      message: 'Vous ne recevrez plus de courses tant que vous ne serez pas reconnecté.',
      confirmLabel: 'Se déconnecter',
    );
    if (ok) auth.logout();
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 14),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: AppTheme.mono(size: 20, weight: FontWeight.w800, color: color, spacing: -0.5))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12),
      child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.shadowSm,
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;
  final bool showDivider;
  const _InfoRow({required this.icon, required this.title, required this.value, this.valueColor, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 18, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: valueColor ?? AppTheme.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 56, endIndent: 16, color: AppTheme.divider),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;
  final bool showDivider;
  const _SettingsTile({required this.icon, required this.title, this.value, required this.onTap, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                if (value != null) ...[
                  Text(value!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 56, endIndent: 16, color: AppTheme.divider),
      ],
    );
  }
}
