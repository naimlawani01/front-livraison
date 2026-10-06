import 'package:flutter/material.dart';
import 'package:mobile_core/mobile_core.dart';

/// Choix du type de véhicule en tuiles (plus rapide qu'une liste déroulante,
/// cibles de 72 px). Utilisé à l'inscription et à la création du profil.
class VehiculeChoix extends StatelessWidget {
  static const options = ['moto', 'scooter', 'vélo'];

  final String value;
  final ValueChanged<String> onChanged;
  const VehiculeChoix({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _tuile(options[i])),
        ],
      ],
    );
  }

  Widget _tuile(String type) {
    final choisi = value == type;
    final icone = switch (type) {
      'vélo' => Icons.pedal_bike_rounded,
      'scooter' => Icons.electric_moped_rounded,
      _ => Icons.two_wheeler_rounded,
    };
    return Semantics(
      selected: choisi,
      button: true,
      child: Material(
        color: choisi ? AppTheme.accentLight : AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(color: choisi ? AppTheme.accent : AppTheme.divider, width: 2),
        ),
        child: InkWell(
          onTap: () => onChanged(type),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, color: choisi ? AppTheme.accentDark : AppTheme.textPrimary),
                const SizedBox(height: 4),
                Text(
                  type[0].toUpperCase() + type.substring(1),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
