import 'dart:async';

import 'package:flutter/widgets.dart';

/// Mixin qui rafraîchit automatiquement un écran :
/// - Quand l'app revient en foreground (`AppLifecycleState.resumed`)
/// - Sur intervalle périodique (configurable via [refreshInterval])
///
/// L'écran doit implémenter [onAutoRefresh] qui sera appelé.
/// Pour activer le polling périodique, surcharger [refreshInterval] avec
/// une `Duration` non-nulle. Si null (défaut), seul le refresh foreground est actif.
///
/// Usage :
/// ```dart
/// class _MyScreenState extends State<MyScreen> with AutoRefreshMixin {
///   @override
///   Duration? get refreshInterval => const Duration(seconds: 30);
///
///   @override
///   Future<void> onAutoRefresh() => context.read<MyProvider>().reload();
///
///   @override
///   Widget build(BuildContext context) => ...;
/// }
/// ```
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> implements WidgetsBindingObserver {
  Timer? _autoRefreshTimer;

  /// Intervalle de polling automatique. `null` = pas de polling, juste resume.
  Duration? get refreshInterval => null;

  /// Appelé au retour foreground et à chaque tick du timer (si activé).
  Future<void> onAutoRefresh();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final interval = refreshInterval;
    if (interval != null) {
      _autoRefreshTimer = Timer.periodic(interval, (_) => _safeRefresh());
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _safeRefresh();
    }
  }

  Future<void> _safeRefresh() async {
    if (!mounted) return;
    try {
      await onAutoRefresh();
    } catch (_) {
      // Silencieux — un refresh raté ne doit pas crasher l'app
    }
  }

  // ── Stubs pour WidgetsBindingObserver (les autres callbacks ne nous intéressent pas) ──
  @override void didChangeAccessibilityFeatures() {}
  @override void didChangeLocales(List<Locale>? locales) {}
  @override void didChangeMetrics() {}
  @override void didChangePlatformBrightness() {}
  @override void didChangeTextScaleFactor() {}
  @override void didHaveMemoryPressure() {}
  @override Future<bool> didPopRoute() async => false;
  @override Future<bool> didPushRoute(String route) async => false;
  @override Future<bool> didPushRouteInformation(RouteInformation routeInformation) async => false;
  @override Future<AppExitResponse> didRequestAppExit() async => AppExitResponse.exit;
  @override void didChangeViewFocus(ViewFocusEvent event) {}
  @override void handleCancelBackGesture() {}
  @override void handleCommitBackGesture() {}
  @override bool handleStartBackGesture(PredictiveBackEvent backEvent) => false;
  @override bool handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) => false;
}
