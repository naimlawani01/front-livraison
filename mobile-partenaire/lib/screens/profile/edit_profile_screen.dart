import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_core/mobile_core.dart';

class EditProfileScreen extends StatefulWidget {
  final Expediteur expediteur;
  const EditProfileScreen({super.key, required this.expediteur});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _adresseCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _telSecondaireCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nomCtrl = TextEditingController(text: widget.expediteur.nom);
    _descriptionCtrl = TextEditingController(text: widget.expediteur.description ?? '');
    _adresseCtrl = TextEditingController(text: widget.expediteur.adresse);
    _emailCtrl = TextEditingController(text: widget.expediteur.email ?? '');
    _telSecondaireCtrl = TextEditingController(
      // Affichage local seulement (sans +224) pour le GuineaPhoneField
      text: GuineaPhone.toLocal(widget.expediteur.telephoneSecondaire ?? ''),
    );
  }

  @override
  void dispose() {
    _nomCtrl.dispose();
    _descriptionCtrl.dispose();
    _adresseCtrl.dispose();
    _emailCtrl.dispose();
    _telSecondaireCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Le téléphone secondaire est optionnel : on ne valide qu'en cas de saisie
    String? telNorm;
    final rawTel = _telSecondaireCtrl.text.trim();
    if (rawTel.isNotEmpty) {
      try {
        telNorm = GuineaPhone.normalize(rawTel);
      } on FormatException catch (e) {
        UIUtils.showError(context, 'Téléphone secondaire : ${e.message}');
        return;
      }
    }

    setState(() => _isSaving = true);

    final data = <String, dynamic>{
      'nom': _nomCtrl.text.trim(),
      'adresse': _adresseCtrl.text.trim(),
      'description': _descriptionCtrl.text.trim().isEmpty
          ? null
          : _descriptionCtrl.text.trim(),
      'email': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      'telephone_secondaire': telNorm,
    };

    final auth = context.read<AuthProvider>();
    final success = await auth.updateExpediteur(data);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      UIUtils.showSuccess(context, 'Profil mis à jour');
      Navigator.pop(context);
    } else {
      UIUtils.showError(context, auth.error ?? 'Erreur lors de la mise à jour');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Modifier le profil'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              const _SectionHeader(
                title: 'Informations générales',
                subtitle: 'Visibles par le client et le livreur',
              ),
              AppFormField(
                controller: _nomCtrl,
                label: 'Nom de l’établissement',
                icon: Icons.storefront_rounded,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Minimum 2 caractères'
                    : null,
              ),
              const SizedBox(height: 14),
              AppFormField(
                controller: _descriptionCtrl,
                label: 'Description (optionnel)',
                icon: Icons.description_outlined,
                hint: 'Décrivez votre activité…',
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              const _SectionHeader(
                title: 'Adresse',
                subtitle: 'Utilisée comme point de récupération',
              ),
              AppFormField(
                controller: _adresseCtrl,
                label: 'Adresse complète',
                icon: Icons.location_on_outlined,
                hint: 'Ex : Quartier Almamya, près du marché',
                validator: (v) => (v == null || v.trim().length < 5)
                    ? 'Minimum 5 caractères'
                    : null,
              ),

              const SizedBox(height: 32),

              const _SectionHeader(
                title: 'Contact',
                subtitle: 'Pour les notifications et le support',
              ),
              AppFormField(
                controller: _emailCtrl,
                label: 'Email (optionnel)',
                icon: Icons.email_outlined,
                hint: 'contact@exemple.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 14),
              GuineaPhoneField(
                controller: _telSecondaireCtrl,
                label: 'Téléphone secondaire (optionnel)',
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) return null; // optionnel
                  if (!GuineaPhone.isValidLocal(value)) {
                    return 'Numéro invalide (9 chiffres, commence par 6)';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: AppTheme.white,
                          ),
                        )
                      : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textTertiary,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
