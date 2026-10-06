import 'package:firebase_analytics/firebase_analytics.dart';

/// Centralised wrapper around `FirebaseAnalytics` that exposes a small typed
/// surface of business events for Sonaiyaa. Use these methods instead of
/// calling `FirebaseAnalytics.instance.logEvent` directly so we keep event
/// names consistent across the two apps.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _fa = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get navigatorObserver =>
      FirebaseAnalyticsObserver(analytics: _fa);

  Future<void> setUserId(String? id) => _fa.setUserId(id: id);
  Future<void> setUserProperty(String name, String? value) =>
      _fa.setUserProperty(name: name, value: value);

  Future<void> logScreen(String name) =>
      _fa.logScreenView(screenName: name);

  // === Auth ===
  Future<void> logLoginSuccess(String role) =>
      _fa.logLogin(loginMethod: 'otp_passeinfo_$role');

  Future<void> logRegister(String role) =>
      _fa.logSignUp(signUpMethod: 'otp_passeinfo_$role');

  // === Expediteur ===
  Future<void> logCourseCreated({required String courseId, num? prix}) =>
      _fa.logEvent(
        name: 'course_creee',
        parameters: {
          'course_id': courseId,
          if (prix != null) 'prix_gnf': prix.round(),
        },
      );

  Future<void> logCourseCancelled(String courseId) =>
      _fa.logEvent(
        name: 'course_annulee',
        parameters: {'course_id': courseId},
      );

  // === Livreur ===
  Future<void> logCourseAccepted(String courseId) =>
      _fa.logEvent(
        name: 'course_acceptee',
        parameters: {'course_id': courseId},
      );

  Future<void> logCourseStatusChange({
    required String courseId,
    required String newStatus,
  }) =>
      _fa.logEvent(
        name: 'course_statut_change',
        parameters: {
          'course_id': courseId,
          'nouveau_statut': newStatus,
        },
      );

  Future<void> logOnlineToggle(bool online) => _fa.logEvent(
        name: online ? 'livreur_online' : 'livreur_offline',
      );

  // === Wallet ===
  Future<void> logWithdrawalRequested({required num amount, required String method}) =>
      _fa.logEvent(
        name: 'retrait_demande',
        parameters: {
          'montant_gnf': amount.round(),
          'methode': method,
        },
      );

  // === KYC ===
  Future<void> logDocumentUploaded(String documentType) => _fa.logEvent(
        name: 'document_uploade',
        parameters: {'type': documentType},
      );

  // === Onboarding ===
  Future<void> logOnboardingCompleted() => _fa.logEvent(name: 'onboarding_completed');
}
