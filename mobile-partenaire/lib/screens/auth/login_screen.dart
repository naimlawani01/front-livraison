import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _phoneServerError;
  String? _passwordServerError;
  String? _globalError;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _phoneServerError = null;
      _passwordServerError = null;
      _globalError = null;
    });
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    try {
      final phone = GuineaPhone.normalize(_phoneController.text);
      final success = await auth.login(phone, _passwordController.text);
      if (!mounted) return;
      if (!success) {
        final msg = auth.error ?? 'Numéro ou mot de passe incorrect';
        setState(() => _globalError = msg);
      }
    } on ApiValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _phoneServerError = e.fieldErrors['phone'];
        _passwordServerError = e.fieldErrors['password'];
        if (e.fieldErrors.isEmpty) _globalError = e.message;
      });
    } on FormatException catch (e) {
      if (mounted) setState(() => _phoneServerError = e.message);
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() => _globalError = msg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().isLoading;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          // Défilable : le clavier ne doit jamais masquer le bouton.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(),
                      Image.asset(
                        'assets/branding/logo_mark_tight.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Sönaiyaa Expéditeur',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Connectez-vous pour gérer vos courses',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                      const SizedBox(height: 32),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_globalError != null) ...[
                              _MessageErreur(message: _globalError!),
                              const SizedBox(height: 16),
                            ],
                            GuineaPhoneField(
                              controller: _phoneController,
                              label: 'Numéro de téléphone',
                              errorText: _phoneServerError,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) {
                                if (_phoneServerError != null) setState(() => _phoneServerError = null);
                              },
                            ),
                            const SizedBox(height: 12),
                            AppFormField(
                              controller: _passwordController,
                              label: 'Mot de passe',
                              icon: Icons.lock_outline_rounded,
                              obscureText: _obscurePassword,
                              serverError: _passwordServerError,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _handleLogin(),
                              onChanged: (_) {
                                if (_passwordServerError != null) setState(() => _passwordServerError = null);
                              },
                              suffix: IconButton(
                                tooltip: _obscurePassword ? 'Afficher le mot de passe' : 'Masquer le mot de passe',
                                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Saisissez votre mot de passe' : null,
                            ),
                            const SizedBox(height: 24),
                            PrimaryCta(label: 'Se connecter', loading: loading, onPressed: _handleLogin),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                        child: const Text.rich(
                          TextSpan(
                            text: 'Pas encore de compte ? ',
                            style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                            children: [
                              TextSpan(text: 'Créer un compte', style: TextStyle(color: AppTheme.accentDark, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Message d'erreur global du formulaire (identifiants refusés, réseau…).
class _MessageErreur extends StatelessWidget {
  final String message;
  const _MessageErreur({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppTheme.error, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
