import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

/// Écran de démarrage animé (« vrai » splash, façon app pro).
///
/// Se place juste après le splash natif (image statique) : le logo apparaît
/// en fondu + léger zoom, le wordmark « Sönaiyaa » et sa signature deux-points
/// glissent ensuite, et trois points de chargement pulsent en bas. À la fin de
/// l'intro (~1,9 s), [onComplete] est appelé pour laisser la main à l'app.
///
/// Le logo est chargé depuis le bundle de l'app hôte (les deux apps déclarent
/// `assets/branding/` avec `logo_mark.png`), donc pas de dépendance d'asset
/// dans `mobile_core`.
class AnimatedSplash extends StatefulWidget {
  final VoidCallback onComplete;
  final String logoAsset;
  final Duration duration;

  const AnimatedSplash({
    super.key,
    required this.onComplete,
    this.logoAsset = 'assets/branding/logo_mark.png',
    this.duration = const Duration(milliseconds: 1900),
  });

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _pulse;

  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _wordFade;
  late final Animation<double> _wordSlide;
  late final Animation<double> _dotsFade;

  bool _completed = false;

  @override
  void initState() {
    super.initState();

    _intro = AnimationController(vsync: this, duration: widget.duration);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();

    Animation<double> curved(double begin, double end, Curve curve) {
      return CurvedAnimation(
        parent: _intro,
        curve: Interval(begin, end, curve: curve),
      );
    }

    _logoFade = curved(0.0, 0.28, Curves.easeOut);
    _logoScale = Tween(begin: 0.82, end: 1.0)
        .animate(curved(0.0, 0.42, Curves.easeOutBack));
    _wordFade = curved(0.30, 0.55, Curves.easeOut);
    _wordSlide = curved(0.30, 0.60, Curves.easeOutCubic);
    _dotsFade = curved(0.46, 0.66, Curves.easeOut);

    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_completed) {
        _completed = true;
        widget.onComplete();
      }
    });

    _intro.forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // ── Lockup central : logo + wordmark ──
          AnimatedBuilder(
            animation: _intro,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: _logoFade.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withValues(
                                  alpha: 0.22 * _logoFade.value.clamp(0.0, 1.0)),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          widget.logoAsset,
                          width: 110,
                          height: 110,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Opacity(
                    opacity: _wordFade.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, (1 - _wordSlide.value) * 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Sönaiyaa',
                            style: GoogleFonts.manrope(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Opacity(
                            opacity: _dotsFade.value.clamp(0.0, 1.0),
                            child: const _SplashDots(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // ── Points de chargement (pulse) en bas ──
          Positioned(
            bottom: 56,
            child: AnimatedBuilder(
              animation: Listenable.merge([_intro, _pulse]),
              builder: (context, _) {
                return Opacity(
                  opacity: _dotsFade.value.clamp(0.0, 1.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      // Onde triangulaire décalée par point → effet « vague ».
                      final phase = ((_pulse.value + i * 0.22) % 1.0);
                      final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accent
                              .withValues(alpha: 0.28 + 0.62 * wave),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Signature deux-points de la marque (déclinaison locale pour le splash,
/// verticalement centrée sur le wordmark).
class _SplashDots extends StatelessWidget {
  const _SplashDots();

  @override
  Widget build(BuildContext context) {
    Widget dot() => Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            color: AppTheme.accent,
            shape: BoxShape.circle,
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [dot(), const SizedBox(width: 3), dot()],
    );
  }
}
