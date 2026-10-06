import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Détecte si le device est en ligne via DNS lookup périodique.
///
/// Pour éviter les faux positifs au retour de background sur Android
/// (le device sort de doze mode, le réseau met 1-2s à se reconnecter),
/// on ne marque "offline" qu'après [_offlineThreshold] échecs consécutifs.
/// Un seul succès remet immédiatement online.
class NetworkService extends ChangeNotifier with WidgetsBindingObserver {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _checkTimer;

  /// Nombre d'échecs consécutifs avant de marquer offline.
  /// Évite que le DNS lookup en cours de wake-up Android ne déclenche
  /// la bannière "pas de connexion" pendant 2-3 secondes.
  static const int _offlineThreshold = 2;
  int _consecutiveFailures = 0;

  bool _observerAttached = false;

  void startMonitoring() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(const Duration(seconds: 15), (_) => checkConnection());
    checkConnection();

    // Re-check immédiatement quand l'app revient en foreground
    if (!_observerAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observerAttached = true;
    }
  }

  void stopMonitoring() {
    _checkTimer?.cancel();
    if (_observerAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _observerAttached = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Petite latence pour laisser le réseau se reconnecter
      Future.delayed(const Duration(milliseconds: 800), checkConnection);
    }
  }

  Future<bool> checkConnection() async {
    try {
      bool online = false;

      if (kIsWeb) {
        online = true;
      } else {
        try {
          final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
          online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } catch (_) {
          online = false;
        }
      }

      if (online) {
        _consecutiveFailures = 0;
        if (!_isOnline) {
          _isOnline = true;
          notifyListeners();
        }
      } else {
        _consecutiveFailures++;
        // Ne marquer offline qu'après plusieurs échecs consécutifs
        if (_consecutiveFailures >= _offlineThreshold && _isOnline) {
          _isOnline = false;
          notifyListeners();
        }
      }
      return _isOnline;
    } catch (_) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= _offlineThreshold && _isOnline) {
        _isOnline = false;
        notifyListeners();
      }
      return _isOnline;
    }
  }

  /// HTTP GET with retry
  Future<http.Response> getWithRetry(
    Uri url, {
    Map<String, String>? headers,
    int maxRetries = 2,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    return _withRetry(() => http.get(url, headers: headers), maxRetries: maxRetries, retryDelay: retryDelay);
  }

  Future<http.Response> postWithRetry(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    int maxRetries = 2,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    return _withRetry(() => http.post(url, headers: headers, body: body), maxRetries: maxRetries, retryDelay: retryDelay);
  }

  Future<http.Response> putWithRetry(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    int maxRetries = 2,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    return _withRetry(() => http.put(url, headers: headers, body: body), maxRetries: maxRetries, retryDelay: retryDelay);
  }

  Future<http.Response> _withRetry(
    Future<http.Response> Function() request, {
    required int maxRetries,
    required Duration retryDelay,
  }) async {
    int attempts = 0;
    while (true) {
      try {
        final response = await request().timeout(const Duration(seconds: 15));
        _setOnline(true);
        return response;
      } catch (e) {
        _setOnline(false);
        attempts++;
        if (attempts > maxRetries) throw Exception('Pas de connexion internet. Vérifiez votre réseau.');
        await Future.delayed(retryDelay * attempts);
      }
    }
  }

  void _setOnline(bool value) {
    if (value) {
      _consecutiveFailures = 0;
    }
    if (value != _isOnline) {
      _isOnline = value;
      notifyListeners();
    }
  }
}
