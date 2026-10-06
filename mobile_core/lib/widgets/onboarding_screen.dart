import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/onboarding_storage.dart';

class OnboardingSlide {
  final IconData icon;
  final String title;
  final String description;
  final Color? iconColor;
  final Color? iconBg;

  const OnboardingSlide({
    required this.icon,
    required this.title,
    required this.description,
    this.iconColor,
    this.iconBg,
  });
}

/// Generic 3-slide onboarding flow used at first launch.
/// Each app provides its own slides (Expediteur vs Livreur).
class OnboardingScreen extends StatefulWidget {
  final List<OnboardingSlide> slides;
  final VoidCallback onCompleted;

  const OnboardingScreen({
    super.key,
    required this.slides,
    required this.onCompleted,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingStorage.markSeen();
    if (mounted) widget.onCompleted();
  }

  void _next() {
    if (_index < widget.slides.length - 1) {
      _pc.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == widget.slides.length - 1;
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text(
                  'Passer',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // Slides
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: widget.slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _SlideView(slide: widget.slides[i]),
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.slides.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppTheme.accent : AppTheme.divider,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            // Action
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: AppTheme.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    isLast ? 'Commencer' : 'Suivant',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final OnboardingSlide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    final iconColor = slide.iconColor ?? AppTheme.accent;
    final iconBg = slide.iconBg ?? AppTheme.accentLight;
    // Entrée douce (fade + léger glissement vers le haut) à chaque apparition
    // de la slide — donne le rythme « app pro » sans être tape-à-l'œil.
    return TweenAnimationBuilder<double>(
      key: ValueKey(slide.title),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.18),
                    blurRadius: 28,
                    spreadRadius: -6,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(slide.icon, size: 56, color: iconColor),
            ),
            const SizedBox(height: 36),
            Text(
              slide.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.6,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              slide.description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
