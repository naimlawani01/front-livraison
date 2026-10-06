import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import '../../widgets/vehicule_choix.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nomCompletController = TextEditingController();
  final _marqueModeleController = TextEditingController();
  final _emailController = TextEditingController();

  String _selectedVehicule = 'moto';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _nomCompletController.dispose();
    _marqueModeleController.dispose();
    _emailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final data = <String, dynamic>{
      'nom_complet': _nomCompletController.text.trim(),
      'type_vehicule': _selectedVehicule,
    };

    final marque = _marqueModeleController.text.trim();
    if (marque.isNotEmpty) {
      data['marque_modele'] = marque;
    }

    final email = _emailController.text.trim();
    if (email.isNotEmpty) {
      data['email'] = email;
    }

    try {
      final success = await auth.createLivreurProfile(data);
      if (!mounted) return;
      if (success) {
        UIUtils.showSuccess(context, 'Profil enregistré');
      } else {
        UIUtils.showError(context, auth.error ?? 'Le profil n\'a pas pu être enregistré. Réessayez.');
      }
    } catch (e) {
      if (mounted) UIUtils.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => context.read<AuthProvider>().logout(),
            child: const Text('Se déconnecter'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Complétez votre profil', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.8)),
                  const SizedBox(height: 8),
                  const Text(
                    'Ces informations sont nécessaires pour commencer à livrer.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  AppFormField(
                    controller: _nomCompletController,
                    label: 'Nom complet',
                    hint: 'Votre prénom et votre nom',
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez votre nom complet' : null,
                  ),
                  const SizedBox(height: 24),
                  const Text('Votre véhicule', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  VehiculeChoix(value: _selectedVehicule, onChanged: (v) => setState(() => _selectedVehicule = v)),
                  const SizedBox(height: 24),
                  AppFormField(
                    controller: _marqueModeleController,
                    label: 'Marque et modèle (facultatif)',
                    hint: 'Ex : Honda PCX 125',
                    icon: Icons.two_wheeler_rounded,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  AppFormField(
                    controller: _emailController,
                    label: 'E-mail (facultatif)',
                    hint: 'vous@exemple.com',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v != null && v.trim().isNotEmpty && (!v.contains('@') || !v.contains('.'))) {
                        return 'Adresse e-mail invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  PrimaryCta(
                    label: 'Enregistrer mon profil',
                    loading: context.watch<AuthProvider>().isLoading,
                    onPressed: _handleCreateProfile,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
