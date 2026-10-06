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
        final msg = auth.error ?? 'Identifiants incorrects';
        setState(() => _globalError = msg);
        UIUtils.showError(context, msg);
      }
    } on ApiValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _phoneServerError = e.fieldErrors['phone'];
        _passwordServerError = e.fieldErrors['password'];
        if (e.fieldErrors.isEmpty) _globalError = e.message;
      });
      if (e.fieldErrors.isEmpty) UIUtils.showError(context, e.message);
    } on FormatException catch (e) {
      if (mounted) setState(() => _phoneServerError = e.message);
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        setState(() => _globalError = msg);
        UIUtils.showError(context, msg);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),

                // Logo + Title (centrés)
                Center(
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/branding/logo_mark_tight.png',
                        width: 96,
                        height: 96,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Sönaiyaa',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Connectez-vous pour gérer vos courses',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_globalError != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.errorLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _globalError!,
                                  style: const TextStyle(
                                    color: AppTheme.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      GuineaPhoneField(
                        controller: _phoneController,
                        label: 'Numéro de téléphone',
                        errorText: _phoneServerError,
                        onChanged: (_) {
                          if (_phoneServerError != null) {
                            setState(() => _phoneServerError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        controller: _passwordController,
                        label: 'Mot de passe',
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
                            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            size: 20, color: AppTheme.textTertiary,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Mot de passe requis' : null,
                      ),
                      const SizedBox(height: 24),
                      Consumer<AuthProvider>(
                        builder: (context, auth, _) {
                          return SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: auth.isLoading ? null : _handleLogin,
                              child: auth.isLoading
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: AppTheme.white, strokeWidth: 2))
                                  : const Text('Se connecter'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    child: const Text.rich(
                      TextSpan(
                        text: 'Propriétaire ? ',
                        style: TextStyle(color: AppTheme.textTertiary, fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Créer un compte',
                            style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
