import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import '../utils/phone.dart';

/// Champ de saisie de numéro guinéen.
///
/// Affiche le drapeau + `+224` figé à gauche, accepte uniquement 9 chiffres
/// commençant par `6`, et formate visuellement en `626 947 150`.
///
/// La valeur du [controller] reste celle saisie par l'utilisateur (digits
/// formatés). À l'envoi backend, normaliser via `GuineaPhone.normalize(...)`.
class GuineaPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String? label;
  final String? hint;
  final String? Function(String?)? validator;
  final String? errorText;
  final bool enabled;
  final void Function(String)? onChanged;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  const GuineaPhoneField({
    super.key,
    required this.controller,
    this.label,
    this.hint = '6XX XXX XXX',
    this.validator,
    this.errorText,
    this.enabled = true,
    this.onChanged,
    this.textInputAction,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      inputFormatters: [
        // Strip tout ce qui n'est pas un chiffre puis formate "626 947 150"
        _GuineaPhoneFormatter(),
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(GuineaPhone.flag, style: TextStyle(fontSize: 18)),
              SizedBox(width: 6),
              Text(
                GuineaPhone.countryCode,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(width: 8),
              SizedBox(
                height: 24,
                child: VerticalDivider(width: 1, thickness: 1, color: AppTheme.divider),
              ),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      ),
      validator: validator ?? _defaultValidator,
    );
  }

  static String? _defaultValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Numéro requis';
    if (!GuineaPhone.isValidLocal(value)) {
      return 'Numéro invalide (9 chiffres, commence par 6)';
    }
    return null;
  }
}

class _GuineaPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed = digits.length > GuineaPhone.localLength
        ? digits.substring(0, GuineaPhone.localLength)
        : digits;
    final formatted = GuineaPhone.formatLocal(trimmed);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
