import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_core/mobile_core.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();

  // Step 1 controllers
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 2 controllers
  final _nomCompletController = TextEditingController();
  final _marqueModeleController = TextEditingController();
  final _emailController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _currentStep = 0;
  String _selectedVehicule = 'moto';
  bool _consentAccepted = false;
  String? _phoneServerError;
  String? _passwordServerError;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  final List<String> _vehiculeOptions = ['moto', 'scooter', 'vélo'];

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
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nomCompletController.dispose();
    _marqueModeleController.dispose();
    _emailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleNext() async {
    setState(() {
      _phoneServerError = null;
      _passwordServerError = null;
    });
    if (!_formKeyStep1.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    try {
      final phone = GuineaPhone.normalize(_phoneController.text);
      final success = await auth.register(phone, _passwordController.text);
      if (!mounted) return;
      if (success) {
        setState(() => _currentStep = 1);
      } else {
        _showError(auth.error ?? 'Erreur lors de l\'inscription');
      }
    } on ApiValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _phoneServerError = e.fieldErrors['phone'];
        _passwordServerError = e.fieldErrors['password'];
      });
      if (e.fieldErrors.isEmpty) _showError(e.message);
    } on FormatException catch (e) {
      if (mounted) setState(() => _phoneServerError = e.message);
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _handleCreateProfile() async {
    if (!_formKeyStep2.currentState!.validate()) return;

    if (!_consentAccepted) {
      UIUtils.showError(context, "Veuillez accepter les conditions d'utilisation");
      return;
    }

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
        UIUtils.showSuccess(context, 'Compte créé avec succès !');
        // Retourner à l'AuthWrapper qui redirigera vers HomeScreen
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        UIUtils.showError(context, auth.error ?? 'Erreur lors de la création du profil');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  void _showError(String msg) {
    UIUtils.showError(context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 20, 24, bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.delivery_dining_rounded,
                    color: AppTheme.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text('Créer un compte',
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Devenez livreur sur notre plateforme',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 24),

                // Step indicator
                _buildStepIndicator(),
                const SizedBox(height: 32),

                // Form content
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _currentStep == 0
                      ? _buildStep1()
                      : _buildStep2(),
                ),

                const SizedBox(height: 32),

                // Action button
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: auth.isLoading
                            ? null
                            : (_currentStep == 0
                                ? _handleNext
                                : _handleCreateProfile),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppTheme.white,
                                ),
                              )
                            : Text(_currentStep == 0
                                ? 'Suivant'
                                : 'Créer mon profil'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Login link
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: RichText(
                      text: TextSpan(
                        text: 'Déjà un compte ? ',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppTheme.textSecondary),
                        children: const [
                          TextSpan(
                            text: 'Se connecter',
                            style: TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _buildStepDot(0, 'Compte'),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: _currentStep >= 1 ? AppTheme.black : AppTheme.divider,
          ),
        ),
        _buildStepDot(1, 'Infos livreur'),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _currentStep >= step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.black : AppTheme.background,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '${step + 1}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive ? AppTheme.white : AppTheme.textTertiary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        key: const ValueKey('step1'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Phone
          Text('Téléphone', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          GuineaPhoneField(
            controller: _phoneController,
            errorText: _phoneServerError,
            onChanged: (_) {
              if (_phoneServerError != null) {
                setState(() => _phoneServerError = null);
              }
            },
          ),
          const SizedBox(height: 20),

          // Password
          Text('Mot de passe', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          AppFormField(
            controller: _passwordController,
            label: '',
            hint: 'Minimum 6 caractères',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscurePassword,
            serverError: _passwordServerError,
            onChanged: (_) {
              if (_passwordServerError != null) {
                setState(() => _passwordServerError = null);
              }
            },
            suffix: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppTheme.textTertiary,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Le mot de passe est requis';
              if (v.length < 8) return 'Minimum 8 caractères';
              if (RegExp(r'^(.)\1+$').hasMatch(v)) return 'Mot de passe trop simple';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Confirm password
          Text('Confirmer le mot de passe',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          AppFormField(
            controller: _confirmPasswordController,
            label: '',
            hint: 'Retapez votre mot de passe',
            icon: Icons.lock_outline_rounded,
            obscureText: _obscureConfirm,
            suffix: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppTheme.textTertiary,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'La confirmation est requise';
              if (v != _passwordController.text) {
                return 'Les mots de passe ne correspondent pas';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        key: const ValueKey('step2'),
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
          Text('Type de véhicule',
              style: Theme.of(context).textTheme.labelLarge),
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

          // Marque/Modèle (optional)
          Text('Marque / Modèle',
              style: Theme.of(context).textTheme.labelLarge),
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
              prefixIcon:
                  Icon(Icons.directions_bike_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 20),

          // Email (optional)
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
          const SizedBox(height: 24),

          // Consentement
          GestureDetector(
            onTap: () => setState(() => _consentAccepted = !_consentAccepted),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _consentAccepted,
                    onChanged: (v) => setState(() => _consentAccepted = v ?? false),
                    activeColor: AppTheme.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
                      children: [
                        const TextSpan(text: "J'ai lu et j'accepte les "),
                        TextSpan(
                          text: "Conditions d'utilisation",
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => launchUrl(Uri.parse('https://www.sonaiyaa.com/conditions-utilisation.html'), mode: LaunchMode.externalApplication),
                        ),
                        const TextSpan(text: " et la "),
                        TextSpan(
                          text: "Politique de confidentialité",
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => launchUrl(Uri.parse('https://www.sonaiyaa.com/politique-confidentialite.html'), mode: LaunchMode.externalApplication),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
