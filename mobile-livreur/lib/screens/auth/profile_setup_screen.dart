import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_core/mobile_core.dart';

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
  final List<String> _vehiculeOptions = ['moto', 'scooter', 'vélo'];

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
        UIUtils.showSuccess(context, 'Profil complété avec succès !');
      } else {
        UIUtils.showError(context, auth.error ?? 'Erreur lors de la création du profil');
      }
    } catch (e) {
      if (mounted) UIUtils.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        title: const Text('Finaliser l\'inscription'),
        backgroundColor: AppTheme.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.error),
            onPressed: () => context.read<AuthProvider>().logout(),
          )
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complétez votre profil',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Ces informations sont nécessaires pour commencer à livrer',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 32),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom complet
                      Text('Nom complet', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nomCompletController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: 'Votre nom et prénom',
                          prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Le nom complet est requis';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Type véhicule
                      Text('Type de véhicule', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedVehicule,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.two_wheeler_rounded, size: 20),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        items: _vehiculeOptions.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type[0].toUpperCase() + type.substring(1)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedVehicule = value);
                          }
                        },
                      ),
                      const SizedBox(height: 20),

                      // Marque/Modèle
                      Text('Marque / Modèle', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text('Optionnel',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textTertiary)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _marqueModeleController,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: 'Ex: Honda PCX 125',
                          prefixIcon: Icon(Icons.directions_bike_outlined, size: 20),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Email
                      Text('Adresse e-mail', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 4),
                      Text('Optionnel',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.textTertiary)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        decoration: const InputDecoration(
                          hintText: 'votre@email.com',
                          prefixIcon: Icon(Icons.email_outlined, size: 20),
                        ),
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty) {
                            if (!v.contains('@') || !v.contains('.')) {
                              return 'Adresse e-mail invalide';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Action button
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _handleCreateProfile,
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppTheme.white,
                                ),
                              )
                            : const Text('Enregistrer mon profil'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
