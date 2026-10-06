import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';
import 'services/foreground_service.dart';
import 'firebase_options.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/course_provider.dart';
import 'providers/location_provider.dart';
import 'providers/wallet_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import 'screens/auth/profile_setup_screen.dart';

void main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    ForegroundLocationService.init();
  }

  ErrorWidget.builder = AppErrorScreen.builder;
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

  // Non-blocking backend health check at boot.
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

  // Initialisation des notifications (Firebase Messaging + Local)
  if (!kIsWeb) await NotificationService().initialize();

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
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider(ApiService())),
      ],
      child: kIsWeb ? _AppView() : WithForegroundTask(child: _AppView()),
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
    // Quand un 401 non récupérable arrive → logout immédiat
    ApiService.onUnauthorized = () {
      final auth = context.read<AuthProvider>();
      auth.logout();
    };
    // Restaurer la session sauvegardée (tokens dans SharedPreferences)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Sönaiyaa Livreur',
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
      return const Scaffold(backgroundColor: AppTheme.background);
    }
    if (_onboardingSeen == false) {
      return OnboardingScreen(
        slides: const [
          OnboardingSlide(
            icon: Icons.delivery_dining_rounded,
            title: 'Bienvenue sur Sönaiyaa Livreur',
            description:
                "Devenez livreur indépendant à Conakry. Acceptez les courses qui vous conviennent et soyez payé rapidement.",
          ),
          OnboardingSlide(
            icon: Icons.location_on_rounded,
            title: 'Recevez les courses près de vous',
            description:
                "Activez votre mode En ligne, le GPS partage votre position et nous vous proposons les courses les plus proches.",
          ),
          OnboardingSlide(
            icon: Icons.savings_rounded,
            title: 'Suivez vos Gains',
            description:
                "Vos gains s'accumulent à chaque course et se retirent sur Mobile Money (Orange Money, MTN MoMo) à partir de 5 000 GNF.",
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
          return const Scaffold(backgroundColor: AppTheme.background);
        }
        if (!kIsWeb) FlutterNativeSplash.remove();
        if (authProvider.isAuthenticated) {
          if (authProvider.livreur == null) {
            return const ProfileSetupScreen();
          }
          return const HomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
