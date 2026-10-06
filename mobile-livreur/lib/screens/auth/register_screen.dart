import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import '../../widgets/vehicule_choix.dart';

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
      UIUtils.showError(context, "Cochez la case pour accepter les conditions d'utilisation");
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
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 24, 16, bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset('assets/branding/logo_mark_tight.png', width: 56, height: 56, fit: BoxFit.contain),
                const SizedBox(height: 24),
                const Text('Devenir livreur', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.8)),
                const SizedBox(height: 8),
                const Text(
                  'Recevez des courses près de chez vous et soyez payé à chaque livraison.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4),
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
                PrimaryCta(
                  label: _currentStep == 0 ? 'Continuer' : 'Créer mon profil',
                  loading: context.watch<AuthProvider>().isLoading,
                  onPressed: _currentStep == 0 ? _handleNext : _handleCreateProfile,
                ),
                const SizedBox(height: 16),

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
                              color: AppTheme.accentDark,
                              fontWeight: FontWeight.w800,
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
            height: 3,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _currentStep >= 1 ? AppTheme.success : AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        _buildStepDot(1, 'Vous et votre véhicule'),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    final fait = _currentStep > step;
    final actif = _currentStep == step;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: fait ? AppTheme.success : (actif ? AppTheme.accent : AppTheme.cardBg),
            shape: BoxShape.circle,
            border: fait || actif ? null : Border.all(color: AppTheme.divider, width: 2),
          ),
          child: Center(
            child: fait
                ? const Icon(Icons.check_rounded, size: 18, color: AppTheme.white)
                : Text(
                    '${step + 1}',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: actif ? AppTheme.white : AppTheme.textSecondary),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: actif ? FontWeight.w800 : FontWeight.w600,
            color: actif ? AppTheme.textPrimary : AppTheme.textSecondary,
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
            hint: 'Au moins 8 caractères',
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
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Le mot de passe est requis';
              if (v.length < 8) return 'Au moins 8 caractères';
              if (RegExp(r'^(.)\1+$').hasMatch(v)) return 'Mot de passe trop simple : variez les caractères';
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          VehiculeChoix(value: _selectedVehicule, onChanged: (v) => setState(() => _selectedVehicule = v)),
          const SizedBox(height: 20),

          // Marque/Modèle (optional)
          Text('Marque / Modèle',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          const Text('Facultatif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _marqueModeleController,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          const Text('Facultatif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          InkWell(
            onTap: () => setState(() => _consentAccepted = !_consentAccepted),
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: _consentAccepted,
                  onChanged: (v) => setState(() => _consentAccepted = v ?? false),
                  activeColor: AppTheme.accent,
                  side: const BorderSide(color: AppTheme.textSecondary, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.5),
                      children: [
                        const TextSpan(text: "J'ai lu et j'accepte les "),
                        TextSpan(
                          text: "Conditions d'utilisation",
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, decoration: TextDecoration.underline),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => launchUrl(Uri.parse('https://www.sonaiyaa.com/conditions-utilisation.html'), mode: LaunchMode.externalApplication),
                        ),
                        const TextSpan(text: " et la "),
                        TextSpan(
                          text: "Politique de confidentialité",
                          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, decoration: TextDecoration.underline),
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
