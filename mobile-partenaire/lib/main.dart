import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/course_provider.dart';
import 'providers/credit_provider.dart';
import 'package:mobile_core/mobile_core.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Custom global error widget (replaces Flutter's red box / grey screen).
  ErrorWidget.builder = AppErrorScreen.builder;

  // Cache app version once for the whole session (used in profile / support).
  await AppVersion.warmup();

  // Initialiser Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Crashlytics — capture les erreurs Flutter framework
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    // Crashlytics — capture les erreurs Dart asynchrones non catchées
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
    debugPrint('[Firebase] Initialized');
  } catch (e) {
    debugPrint('[Firebase] Init failed: $e');
  }

  // Démarrage du monitoring réseau
  NetworkService().startMonitoring();

  // Non-blocking backend health check at boot. NetworkService already shows an
  // OfflineBanner, but this gives us a visible signal in Crashlytics if the
  // backend itself is down even though the device has connectivity.
  // ignore: unawaited_futures
  ApiService.healthCheck().then((ok) {
    if (!ok) {
      debugPrint('[Health] Backend unreachable at boot');
      try {
        FirebaseCrashlytics.instance.log('Backend health check failed at boot');
      } catch (_) {}
    }
  });

  // Configuration de la barre de statut
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialisation des notifications (Firebase Messaging + Local).
  // Non supporté sur le web (flutter_local_notifications) → garde kIsWeb.
  // Sans effet sur mobile où kIsWeb == false.
  if (!kIsWeb) {
    await NotificationService().initialize();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CourseProvider()),
        ChangeNotifierProvider(create: (_) => CreditProvider()),
      ],
      child: _AppView(),
    );
  }
}

class _AppView extends StatefulWidget {
  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  @override
  void initState() {
    super.initState();
    ApiService.onUnauthorized = () {
      final auth = context.read<AuthProvider>();
      auth.logout();
    };
    // Restaurer la session sauvegardée
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Sönaiyaa Expéditeur',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        navigatorObservers: [AnalyticsService.instance.navigatorObserver],
        home: const AuthWrapper(),
        builder: (context, child) {
          return GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: ColoredBox(
              color: AppTheme.white,
              child: Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  // Bannière hors-ligne positionnée sous la status bar
                  Positioned(
                    top: MediaQuery.of(context).padding.top,
                    left: 0,
                    right: 0,
                    child: const OfflineBanner(),
                  ),
                ],
              ),
            ),
          );
        },
      );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? _onboardingSeen;
  bool _introDone = false;

  @override
  void initState() {
    super.initState();
    OnboardingStorage.hasSeen().then((seen) {
      if (!mounted) return;
      // Native splash must be removed as soon as we've decided what to render
      // next — otherwise the iOS / Android splash stays on top while the
      // onboarding (or login) is rendered underneath, making the app appear
      // frozen on the logo.
      if (!kIsWeb) FlutterNativeSplash.remove();
      setState(() => _onboardingSeen = seen);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Splash animé — laisse la main à l'app une fois l'intro terminée.
    if (!_introDone) {
      return AnimatedSplash(
        onComplete: () {
          if (mounted) setState(() => _introDone = true);
        },
      );
    }
    if (_onboardingSeen == null) {
      return const Scaffold(backgroundColor: AppTheme.white);
    }
    if (_onboardingSeen == false) {
      return OnboardingScreen(
        slides: const [
          OnboardingSlide(
            icon: Icons.storefront_rounded,
            title: 'Bienvenue sur Sönaiyaa Expéditeur',
            description:
                "L'app pensée pour vos livraisons à Conakry. Créez une course, suivez-la en temps réel et gérez toute votre activité en un clin d'œil.",
          ),
          OnboardingSlide(
            icon: Icons.add_circle_outline_rounded,
            title: 'Créez vos livraisons',
            description:
                "Indiquez le destinataire, partagez le lien de suivi, et nos livreurs vérifiés s'occupent du reste. Paiement Cash ou Mobile Money.",
          ),
          OnboardingSlide(
            icon: Icons.timeline_rounded,
            title: 'Suivez en temps réel',
            description:
                "GPS en direct, statut de la livraison, notifications push à chaque étape. Vous savez toujours où en est votre colis.",
          ),
        ],
        onCompleted: () {
          AnalyticsService.instance.logOnboardingCompleted();
          setState(() => _onboardingSeen = true);
        },
      );
    }
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Only show blank scaffold during the initial app boot (token check),
        // NOT during a regular `login()` call — otherwise the LoginScreen
        // gets unmounted mid-login and loses its inline error state.
        if (authProvider.isInitializing) {
          return const Scaffold(backgroundColor: AppTheme.white);
        }
        if (!kIsWeb) FlutterNativeSplash.remove();
        if (authProvider.isAuthenticated) {
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
