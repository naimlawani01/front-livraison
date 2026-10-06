import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:mobile_core/mobile_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/foreground_service.dart';

const _kWasOnlineKey = 'livreur_was_online';

class LocationProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  Position? _currentPosition;
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;
  String? _error;

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  String? get error => _error;

  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _error = 'Le service de localisation est désactivé';
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _error = 'Permission de localisation refusée';
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _error = 'Permission de localisation refusée définitivement';
      notifyListeners();
      return false;
    }

    return true;
  }

  Future<void> getCurrentPosition() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await checkPermissions();
    if (!hasPermission) return;

    // 1. Obtenir la position actuelle
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      _error = 'Impossible d\'obtenir la position GPS';
      notifyListeners();
      return;
    }

    // 2. Envoyer la position au backend
    try {
      await _apiService.updateLocation(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    } catch (_) {}

    // 3. Passer en ligne (le backend a maintenant une position valide)
    try {
      await _apiService.updateDisponibilite(true);
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return;
    }

    _isTracking = true;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setBool(_kWasOnlineKey, true));

    // 4. Démarrer le service foreground (maintient le GPS actif en background)
    await ForegroundLocationService.start();

    // 5. Démarrer le suivi continu
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        _currentPosition = position;
        notifyListeners();

        try {
          await _apiService.updateLocation(
            position.latitude,
            position.longitude,
          );
        } catch (e) {
          // Silent fail - will retry on next update
        }
      },
      onError: (error) {
        _error = error.toString();
        notifyListeners();
      },
    );
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    notifyListeners();
    SharedPreferences.getInstance().then((p) => p.setBool(_kWasOnlineKey, false));

    ForegroundLocationService.stop();
    _apiService.updateDisponibilite(false).catchError((_) {});
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
