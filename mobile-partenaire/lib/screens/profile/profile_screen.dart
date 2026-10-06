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
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.accent,
          onRefresh: () => auth.loadExpediteur(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 28),
            const Text('Profil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 28),

            // Avatar & Name
            Center(
              child: Column(
                children: [
                  UserAvatar(name: expediteur?.nom, size: 88),
                  const SizedBox(height: 16),
                  Text(
                    expediteur?.nom ?? 'Mon établissement',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                  if (expediteur != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      expediteur.adresse,
                      style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    GuineaPhone.formatPretty(user?.phone),
                    style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),

                  if (expediteur?.isVerified == true) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.successLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_rounded, size: 16, color: AppTheme.successDark),
                          const SizedBox(width: 5),
                          Text('Vérifié', style: TextStyle(color: AppTheme.successDark, fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],

                  if (expediteur != null) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => EditProfileScreen(expediteur: expediteur)),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Text('Modifier le profil', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.accentDark)),
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
                  color: AppTheme.cardBg,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.divider),
                  boxShadow: AppTheme.shadowSm,
                ),
                child: Column(
                  children: [
                    _InfoRow(icon: Icons.location_on_outlined, title: 'Adresse', value: expediteur.adresse),
                    if (expediteur.email != null) _InfoRow(icon: Icons.email_outlined, title: 'E-mail', value: expediteur.email!),
                    if (expediteur.telephoneSecondaire != null) _InfoRow(icon: Icons.phone_outlined, title: 'Téléphone secondaire', value: GuineaPhone.formatPretty(expediteur.telephoneSecondaire)),
                    _InfoRow(
                      icon: Icons.star_outline_rounded,
                      title: 'Note moyenne',
                      value: expediteur.noteMoyenne > 0 ? '${expediteur.noteMoyenne.toStringAsFixed(1)} (${expediteur.nombreEvaluations} avis)' : 'Pas encore d\'avis',
                    ),
                    _InfoRow(
                      icon: Icons.verified_outlined,
                      title: 'Statut',
                      value: expediteur.isVerified ? 'Vérifié' : 'En attente',
                      valueColor: expediteur.isVerified ? AppTheme.successDark : AppTheme.warningDark,
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            // Settings
            const _SectionHeader(title: 'Compte et aide'),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.folder_outlined,
                  title: 'Mes documents',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DocumentsScreen())),
                ),
                _SettingsTile(icon: Icons.support_agent_outlined, title: 'Contacter le support', onTap: () {
                  launchUrl(Uri.parse('mailto:support@sonaiyaa.com?subject=Aide%20Sönaiyaa%20Expediteur'), mode: LaunchMode.externalApplication);
                }),
                _InfoRow(icon: Icons.info_outline_rounded, title: 'Version de l\'application', value: AppVersion.short, showDivider: false),
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
      message: 'Toutes vos données personnelles seront supprimées. Cette action est définitive.',
      confirmLabel: 'Supprimer mon compte',
    );
    if (ok) await auth.deleteAccount();
  }

  Future<void> _confirmerDeconnexion(BuildContext context, AuthProvider auth) async {
    final ok = await showConfirmAction(
      context,
      icon: Icons.logout_rounded,
      title: 'Se déconnecter ?',
      message: 'Vos courses en cours continuent ; vous les retrouverez à la reconnexion.',
      confirmLabel: 'Se déconnecter',
    );
    if (ok) auth.logout();
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
  final VoidCallback onTap;
  final bool showDivider;
  const _SettingsTile({required this.icon, required this.title, required this.onTap, this.showDivider = true});

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
