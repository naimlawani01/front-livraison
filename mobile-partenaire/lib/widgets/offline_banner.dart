import 'package:flutter/material.dart';
import 'package:mobile_core/mobile_core.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: NetworkService(),
      builder: (context, _) {
        final isOnline = NetworkService().isOnline;
        return AnimatedSlide(
          offset: isOnline ? const Offset(0, -1) : Offset.zero,
          duration: const Duration(milliseconds: 300),
          child: AnimatedOpacity(
            opacity: isOnline ? 0 : 1,
            duration: const Duration(milliseconds: 300),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: AppTheme.error,
              child: const SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pas de connexion internet',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
