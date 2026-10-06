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
      _showError("Cochez la case pour accepter les conditions d'utilisation");
      return;
    }

    if (_latitude == null || _longitude == null) {
      _showError('Enregistrez la position de votre commerce avec « Utiliser ma position actuelle »');
      return;
    }

    final auth = context.read<AuthProvider>();

    try {
      final phone = GuineaPhone.normalize(_phoneController.text);
      final registered = await auth.register(phone, _passwordController.text);

      if (!mounted) return;

      if (!registered) {
        _showError(auth.error ?? 'L\'inscription a échoué. Réessayez.');
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
                const Text('Créer votre compte', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.8)),
                const SizedBox(height: 8),
                const Text(
                  'Trouvez un livreur pour vos clients en quelques secondes.',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),

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
                PrimaryCta(
                  label: _currentStep == 0 ? 'Continuer' : 'Créer mon compte',
                  loading: context.watch<AuthProvider>().isLoading,
                  onPressed: _currentStep == 0 ? _nextStep : _handleRegister,
                ),

                if (_currentStep == 1) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _previousStep,
                      style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                      child: const Text('Retour'),
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
        _buildStepDot(1, 'Votre commerce'),
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
                : Text('${step + 1}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: actif ? AppTheme.white : AppTheme.textSecondary)),
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

  Widget _buildStep1({Key? key}) {
    return Form(
      key: _step1Key,
      child: Column(
        key: key,
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
              if (v == null || v.isEmpty) return 'Mot de passe requis';
              if (v.length < 8) return 'Au moins 8 caractères';
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

          // Nom
          Text('Nom de l’établissement',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nomController,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Ex : Chez Mamadou',
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
          FormField<String>(
            initialValue: _typeExpediteur,
            validator: (_) => _typeExpediteur == null ? 'Choisissez votre activité' : null,
            builder: (field) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (valeur, label) in const [
                      ('RESTAURANT', 'Restaurant'),
                      ('PHARMACIE', 'Pharmacie'),
                      ('SUPERMARCHE', 'Supermarché'),
                      ('B2B', 'Grossiste'),
                      ('AUTRE', 'Autre commerce'),
                    ])
                      ChoiceChip(
                        label: Text(label),
                        selected: _typeExpediteur == valeur,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() => _typeExpediteur = valeur);
                          field.didChange(valeur);
                        },
                        labelStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _typeExpediteur == valeur ? AppTheme.accentDark : AppTheme.textPrimary,
                        ),
                        backgroundColor: AppTheme.cardBg,
                        selectedColor: AppTheme.accentLight,
                        side: BorderSide(color: _typeExpediteur == valeur ? AppTheme.accent : AppTheme.divider, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                  ],
                ),
                if (field.hasError) ...[
                  const SizedBox(height: 8),
                  Text(field.errorText!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.error)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Adresse
          Text('Adresse', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: _adresseController,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Ex : Madina, face à la grande mosquée',
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
          const Text('Facultatif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 3,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
          Text('E-mail', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          const Text('Facultatif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'contact@moncommerce.com',
              prefixIcon: Icon(Icons.email_outlined, size: 20),
            ),
          ),
          const SizedBox(height: 20),

          // Position GPS de l’établissement
          Text('Position GPS de l’établissement', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          const Text(
            'Faites-le depuis votre commerce : le prix des courses est calculé à partir de cette position.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 8),
          if (_latitude != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.successLight, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 20, color: AppTheme.successDark),
                  SizedBox(width: 12),
                  Expanded(child: Text('Position enregistrée', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.successDark))),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          SecondaryButton(
            label: _locatingGps
                ? 'Localisation…'
                : (_latitude != null ? 'Mettre à jour la position' : 'Utiliser ma position actuelle'),
            icon: _latitude != null ? Icons.refresh_rounded : Icons.my_location_rounded,
            onPressed: _locatingGps ? null : _getGpsPosition,
          ),
          const SizedBox(height: 20),

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
