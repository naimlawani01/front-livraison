import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Champ de formulaire avec affichage d'erreur **inline** sous l'input,
/// utilisé pour homogénéiser les formulaires des deux apps.
///
/// L'erreur peut venir :
///   • du [validator] local (validation Flutter classique)
///   • d'une erreur serveur via [serverError] (mappée depuis un 422 backend)
///
/// Quand [serverError] est non-null, il prime sur la validation locale et
/// reste affichée jusqu'à ce que l'utilisateur modifie le champ (auto-clear
/// via [onChanged]).
class AppFormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? icon;
  final Widget? prefix;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;

  /// Erreur renvoyée par le serveur pour ce champ (ex: 422 FastAPI).
  /// Si non-null, force l'état d'erreur visuel et l'affichage du message.
  final String? serverError;

  const AppFormField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.icon,
    this.prefix,
    this.suffix,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.serverError,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: autofocus,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefix ?? (icon != null ? Icon(icon, size: 20) : null),
        suffixIcon: suffix,
        errorText: serverError,
        // Quand on a une erreur serveur, on force la couleur d'erreur sur le label
        errorMaxLines: 2,
      ),
      validator: serverError != null ? (_) => serverError : validator,
    );
  }
}
