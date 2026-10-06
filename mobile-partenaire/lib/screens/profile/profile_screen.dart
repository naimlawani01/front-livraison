import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import 'edit_profile_screen.dart';
import 'documents_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final expediteur = auth.expediteur;

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.black,
          onRefresh: () => auth.loadExpediteur(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          children: [
            const SizedBox(height: 28),
            Text('Profil', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 28),

            // Avatar & Name
            Center(
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 10))],
                    ),
                    child: Center(
                      child: Text(
                        expediteur?.nom.substring(0, 1).toUpperCase() ?? 'R',
                        style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    expediteur?.nom ?? 'Mon établissement',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  if (expediteur != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      expediteur.adresse,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w400),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    GuineaPhone.formatPretty(user?.phone),
                    style: const TextStyle(fontSize: 14, color: AppTheme.textTertiary, fontWeight: FontWeight.w500),
                  ),

                  if (expediteur?.isVerified == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 15, color: AppTheme.success),
                          const SizedBox(width: 5),
                          Text('Vérifié', style: TextStyle(color: AppTheme.success, fontWeight: FontWeight.w700, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],

                  if (expediteur != null) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditProfileScreen(expediteur: expediteur)),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 14, color: AppTheme.textSecondary),
                            SizedBox(width: 8),
                            Text('Modifier le profil', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Expediteur info
            if (expediteur != null) ...[
              const _SectionHeader(title: 'Établissement'),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Column(
                  children: [
                    _InfoRow(icon: Icons.location_on_outlined, title: 'Adresse', value: expediteur.adresse),
                    if (expediteur.email != null) _InfoRow(icon: Icons.email_outlined, title: 'Email', value: expediteur.email!),
                    if (expediteur.telephoneSecondaire != null) _InfoRow(icon: Icons.phone_outlined, title: 'Tel. secondaire', value: GuineaPhone.formatPretty(expediteur.telephoneSecondaire)),
                    _InfoRow(
                      icon: Icons.star_outline_rounded,
                      title: 'Note moyenne',
                      value: expediteur.noteMoyenne > 0 ? '${expediteur.noteMoyenne.toStringAsFixed(1)} (${expediteur.nombreEvaluations} avis)' : 'Pas encore d\'avis',
                    ),
                    _InfoRow(
                      icon: Icons.verified_outlined,
                      title: 'Statut',
                      value: expediteur.isVerified ? 'Vérifié' : 'En attente',
                      valueColor: expediteur.isVerified ? AppTheme.success : AppTheme.warning,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            // Settings
            const _SectionHeader(title: 'Réglages'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.folder_outlined,
                  title: 'Mes documents',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())),
                ),
                _SettingsTile(icon: Icons.language_outlined, title: 'Langue', value: 'Francais', onTap: () {}),
                _SettingsTile(icon: Icons.notifications_outlined, title: 'Notifications', value: 'Activees', onTap: () {}),
                _SettingsTile(icon: Icons.support_agent_outlined, title: 'Aide & Support', onTap: () {
                  launchUrl(Uri.parse('mailto:support@sonaiyaa.com?subject=Aide%20Sönaiyaa%20Expediteur'), mode: LaunchMode.externalApplication);
                }),
                _SettingsTile(icon: Icons.info_outline_rounded, title: 'A propos', value: AppVersion.short, onTap: () {}, showDivider: false),
              ],
            ),
            const SizedBox(height: 20),

            // Légal
            const _SectionHeader(title: 'Légal & Confidentialité'),
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

            // Logout
            GestureDetector(
              onTap: () => _showLogoutDialog(context, auth),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Center(
                  child: Text(
                    'Se déconnecter',
                    style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showDeleteAccountDialog(context, auth),
              child: const Center(
                child: Text(
                  'Supprimer mon compte',
                  style: TextStyle(color: AppTheme.textTertiary, fontWeight: FontWeight.w500, fontSize: 13, decoration: TextDecoration.underline),
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte', style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Toutes vos données personnelles seront supprimées. Cette action est irréversible.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.deleteAccount();
            },
            child: const Text('Supprimer', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deconnexion', style: TextStyle(fontWeight: FontWeight.w600)),
        content: const Text('Voulez-vous vraiment vous deconnecter ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600))),
          TextButton(
            onPressed: () { auth.logout(); Navigator.pop(ctx); },
            child: const Text('Se déconnecter', style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600)),
          ),
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
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
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
        color: AppTheme.white,
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
                    Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textTertiary)),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? AppTheme.textPrimary)),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, size: 18, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                if (value != null) ...[
                  Text(value!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textTertiary)),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textTertiary),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 56, endIndent: 16, color: AppTheme.divider),
      ],
    );
  }
}
