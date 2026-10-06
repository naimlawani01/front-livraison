import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();
  FirebaseMessaging? _messaging;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Local notifications
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );
    await _localNotifications.initialize(settings);

    // Firebase Cloud Messaging
    try {
      _messaging = FirebaseMessaging.instance;

      final authStatus = await _messaging!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[FCM] Permission: ${authStatus.authorizationStatus}');

      // Foreground messages -> show local notification
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Background handler
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Get token and send to backend
      await _registerFcmToken();

      // Re-register on token refresh
      _messaging!.onTokenRefresh.listen((token) async {
        debugPrint('[FCM] Token refreshed');
        await _sendTokenToBackend(token);
      });

      debugPrint('[FCM] Firebase Messaging initialized');
    } catch (e) {
      debugPrint('[FCM] Firebase Messaging not available (macOS dev?): $e');
    }

    _initialized = true;
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await _messaging?.getToken();
      if (token != null) {
        debugPrint('[FCM] Token obtained (${token.substring(0, 20)}...)');
        await _sendTokenToBackend(token);
      } else {
        debugPrint('[FCM] No token available (APNs not configured?)');
      }
    } catch (e) {
      debugPrint('[FCM] Could not get token: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await _apiService.updateDeviceToken(token);
      debugPrint('[FCM] Token sent to backend');
    } catch (_) {
      debugPrint('[FCM] Failed to send token to backend (user not logged in?)');
    }
  }

  /// Appeler cette méthode après le login pour enregistrer le token FCM
  Future<void> registerTokenAfterLogin() async {
    try {
      final token = await _messaging?.getToken();
      if (token != null) {
        debugPrint('[FCM] Registering token after login...');
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] registerTokenAfterLogin error: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground: ${message.notification?.title}');
    final notification = message.notification;
    if (notification != null) {
      showLocalNotification(
        title: notification.title ?? 'Livraison',
        body: notification.body ?? '',
        payload: message.data['type'],
      );
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'livraison_fcm',
      'Notifications livraison',
      channelDescription: 'Alertes courses et courses (expediteur ou livreur)',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}
