import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_core/mobile_core.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late final TextEditingController _marqueController;
  late final TextEditingController _plaqueController;
  String? _typeVehicule;

  static const _vehiculeOptions = ['moto', 'scooter', 'vélo'];

  @override
  void initState() {
    super.initState();
    final livreur = context.read<AuthProvider>().livreur;
    _nomController = TextEditingController(text: livreur?.nomComplet ?? '');
    _marqueController = TextEditingController(text: livreur?.marqueModele ?? '');
    _plaqueController = TextEditingController(text: livreur?.plaqueImmatriculation ?? '');
    final raw = (livreur?.typeVehicule ?? '').toLowerCase();
    _typeVehicule = _vehiculeOptions.contains(raw) ? raw : null;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _marqueController.dispose();
    _plaqueController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final data = <String, dynamic>{};
    final livreur = context.read<AuthProvider>().livreur;
    final nom = _nomController.text.trim();
    final marque = _marqueController.text.trim();
    final plaque = _plaqueController.text.trim();

    if (nom != (livreur?.nomComplet ?? '')) data['nom_complet'] = nom;
    if (_typeVehicule != livreur?.typeVehicule) {
      data['type_vehicule'] = _typeVehicule;
    }
    if (marque != (livreur?.marqueModele ?? '')) {
      data['marque_modele'] = marque.isEmpty ? null : marque;
    }
    if (plaque != (livreur?.plaqueImmatriculation ?? '')) {
      data['plaque_immatriculation'] = plaque.isEmpty ? null : plaque;
    }

    if (data.isEmpty) {
      Navigator.pop(context);
      return;
    }

    final auth = context.read<AuthProvider>();
    final success = await auth.updateLivreurProfile(data);
    if (!mounted) return;

    if (success) {
      UIUtils.showSuccess(context, 'Profil mis à jour');
      Navigator.pop(context);
    } else {
      UIUtils.showError(context, auth.error ?? 'Erreur lors de la mise à jour');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

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
                title: 'Identité',
                subtitle: 'Comment vous apparaissez aux expediteurs',
              ),
              AppFormField(
                controller: _nomController,
                label: 'Nom complet',
                icon: Icons.person_outline_rounded,
                hint: 'Prénom Nom',
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Minimum 2 caractères'
                    : null,
              ),

              const SizedBox(height: 32),

              const _SectionHeader(
                title: 'Véhicule',
                subtitle: 'Pour mieux vous matcher avec les courses',
              ),
              const _FieldLabel('Type de véhicule'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _typeVehicule,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.two_wheeler_rounded, size: 20),
                  hintText: 'Choisir',
                ),
                items: _vehiculeOptions
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v[0].toUpperCase() + v.substring(1)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _typeVehicule = v),
              ),
              const SizedBox(height: 14),
              AppFormField(
                controller: _marqueController,
                label: 'Marque / Modèle (optionnel)',
                icon: Icons.directions_car_outlined,
                hint: 'Ex : Honda CB 125',
              ),
              const SizedBox(height: 14),
              AppFormField(
                controller: _plaqueController,
                label: "Plaque d'immatriculation (optionnel)",
                icon: Icons.pin_outlined,
                hint: 'Ex : RC 1234 A',
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _handleSave,
                  child: isLoading
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

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}
