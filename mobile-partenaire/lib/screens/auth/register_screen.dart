import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_core/mobile_core.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  // Step 1 controllers
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Step 2 controllers
  final _nomController = TextEditingController();
  final _adresseController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  /// Valeurs API : restaurant, pharmacie, supermarche, b2b, autre
  String? _typeExpediteur;
  double? _latitude;
  double? _longitude;
  bool _locatingGps = false;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _currentStep = 0;
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
    _nomController.dispose();
    _adresseController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _nextStep() {
    setState(() {
      _phoneServerError = null;
      _passwordServerError = null;
    });
    if (_step1Key.currentState!.validate()) {
      // On vérifie aussi que le format guinéen est OK avant de passer à l'étape 2
      try {
        GuineaPhone.normalize(_phoneController.text);
      } on FormatException catch (e) {
        setState(() => _phoneServerError = e.message);
        return;
      }
      setState(() => _currentStep = 1);
    }
  }

  void _previousStep() {
    setState(() => _currentStep = 0);
  }

  Future<void> _handleRegister() async {
    if (!_step2Key.currentState!.validate()) return;

    if (!_consentAccepted) {
      _showError("Veuillez accepter les conditions d'utilisation");
      return;
    }

    if (_latitude == null || _longitude == null) {
      _showError('Veuillez partager la position GPS de votre établissement');
      return;
    }

    final auth = context.read<AuthProvider>();

    try {
      final phone = GuineaPhone.normalize(_phoneController.text);
      final registered = await auth.register(phone, _passwordController.text);

      if (!mounted) return;

      if (!registered) {
        _showError(auth.error ?? 'Erreur lors de l\'inscription');
        return;
      }

      final profileData = {
        'nom': _nomController.text.trim(),
        'adresse': _adresseController.text.trim(),
        'latitude': _latitude,
        'longitude': _longitude,
        'type_expediteur': _typeExpediteur,
      };

      if (_descriptionController.text.trim().isNotEmpty) {
        profileData['description'] = _descriptionController.text.trim();
      }
      if (_emailController.text.trim().isNotEmpty) {
        profileData['email'] = _emailController.text.trim();
      }

      final profileCreated = await auth.createExpediteurProfile(profileData);

      if (!mounted) return;

      if (profileCreated) {
        UIUtils.showSuccess(context, 'Expéditeur créé avec succès !');
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        UIUtils.showError(context, auth.error ?? 'Erreur lors de la création du profil');
      }
    } on ApiValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _phoneServerError = e.fieldErrors['phone'];
        _passwordServerError = e.fieldErrors['password'];
        // Si l'erreur concerne un champ de l'étape 1, on y revient
        if (_phoneServerError != null || _passwordServerError != null) {
          _currentStep = 0;
        }
      });
      if (e.fieldErrors.isEmpty) _showError(e.message);
    } on FormatException catch (e) {
      if (mounted) {
        setState(() {
          _phoneServerError = e.message;
          _currentStep = 0;
        });
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    }
  }

  Future<void> _getGpsPosition() async {
    setState(() => _locatingGps = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) _showError('Activez le GPS de votre téléphone');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) _showError('Permission de localisation refusée');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) _showError('Autorisez la localisation dans les réglages');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (mounted) _showError('Impossible d\'obtenir la position');
    } finally {
      if (mounted) setState(() => _locatingGps = false);
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
                  child: const Icon(Icons.storefront_rounded,
                      color: AppTheme.white, size: 28),
                ),
                const SizedBox(height: 32),

                // Title
                Text('Créer un compte',
                    style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Inscrivez votre établissement sur la plateforme',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 32),

                // Step indicator
                _buildStepIndicator(),
                const SizedBox(height: 32),

                // Animated step content
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, animation) {
                    final offsetAnim = Tween<Offset>(
                      begin: Offset(_currentStep == 0 ? -1.0 : 1.0, 0.0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeInOut,
                    ));
                    return SlideTransition(
                      position: offsetAnim,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: _currentStep == 0
                      ? _buildStep1(key: const ValueKey(0))
                      : _buildStep2(key: const ValueKey(1)),
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
                            : (_currentStep == 0 ? _nextStep : _handleRegister),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: AppTheme.white),
                              )
                            : Text(_currentStep == 0
                                ? 'Suivant'
                                : 'Créer mon compte'),
                      ),
                    );
                  },
                ),

                if (_currentStep == 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _previousStep,
                      child: const Text(
                        'Retour',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Link to login
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
                              color: AppTheme.black,
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
            decoration: BoxDecoration(
              color: _currentStep >= 1 ? AppTheme.black : AppTheme.divider,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        _buildStepDot(1, 'Expéditeur'),
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
                fontWeight: FontWeight.w600,
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
            fontWeight: FontWeight.w500,
            color: isActive ? AppTheme.textPrimary : AppTheme.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildStep1({Key? key}) {
    return Form(
      key: _step1Key,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle
          Text(
            'Étape 1/2 — Informations du compte',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 24),

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
            hint: 'Choisissez un mot de passe',
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
              if (v == null || v.isEmpty) return 'Mot de passe requis';
              if (v.length < 8) return '8 caractères minimum';
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
            hint: 'Confirmez votre mot de passe',
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
              if (v == null || v.isEmpty) return 'Confirmation requise';
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

  Widget _buildStep2({Key? key}) {
    return Form(
      key: _step2Key,
      child: Column(
        key: key,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle
          Text(
            'Étape 2/2 — Informations de l’établissement',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 24),

          // Nom
          Text('Nom de l’établissement',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nomController,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              hintText: 'Ex: Chez Mamadou',
              prefixIcon: Icon(Icons.store_outlined, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Nom de l’établissement requis';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          Text('Type d\'activité',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _typeExpediteur,
            decoration: const InputDecoration(
              hintText: 'Sélectionnez votre activité',
              prefixIcon: Icon(Icons.category_outlined, size: 20),
            ),
            items: const [
              DropdownMenuItem(value: 'RESTAURANT', child: Text('Restaurant')),
              DropdownMenuItem(value: 'PHARMACIE', child: Text('Pharmacie')),
              DropdownMenuItem(value: 'SUPERMARCHE', child: Text('Supermarché')),
              DropdownMenuItem(value: 'B2B', child: Text('B2B / grossiste')),
              DropdownMenuItem(value: 'AUTRE', child: Text('Autre commerce')),
            ],
            onChanged: (v) => setState(() => _typeExpediteur = v),
            validator: (v) =>
                v == null || v.isEmpty ? 'Sélectionnez votre activité' : null,
          ),
          const SizedBox(height: 20),

          // Adresse
          Text('Adresse', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _adresseController,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              hintText: 'Ex: 12 rue de la Paix, Dakar',
              prefixIcon: Icon(Icons.location_on_outlined, size: 20),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Adresse requise';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Description (optional)
          Text('Description',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Optionnel',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              hintText: 'Décrivez votre établissement...',
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(Icons.description_outlined, size: 20),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Email (optional)
          Text('Email', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            'Optionnel',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              hintText: 'contact@moncommerce.com',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 20),

          // Position GPS de l’établissement
          Text('Position GPS de l’établissement', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _latitude != null ? AppTheme.successLight : AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _latitude != null ? AppTheme.success.withOpacity(0.3) : AppTheme.divider,
              ),
            ),
            child: Column(
              children: [
                if (_latitude != null) ...[
                  const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, size: 20, color: AppTheme.success),
                      SizedBox(width: 8),
                      Text(
                        'Position enregistrée',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.success),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _locatingGps ? null : _getGpsPosition,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Actualiser'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.location_on_outlined, size: 32, color: AppTheme.textTertiary),
                  const SizedBox(height: 8),
                  const Text(
                    'Ouvrez l\'application depuis votre établissement pour enregistrer sa position exacte',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _locatingGps ? null : _getGpsPosition,
                      icon: _locatingGps
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.white))
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(_locatingGps ? 'Localisation...' : 'Utiliser ma position actuelle'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

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
