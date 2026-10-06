import 'package:flutter/material.dart';
import 'package:mobile_core/mobile_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  User? _user;
  Expediteur? _expediteur;
  bool _isAuthenticated = false;
  bool _isInitializing = true; // true seulement pendant init() au boot
  bool _isLoading = false;     // true pendant login/register en cours
  String? _error;

  User? get user => _user;
  Expediteur? get expediteur => _expediteur;
  bool get isAuthenticated => _isAuthenticated;
  bool get isInitializing => _isInitializing;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Appelé au démarrage — vérifie si un token valide est sauvegardé
  Future<void> init() async {
    _isInitializing = true;
    notifyListeners();
    try {
      final token = await _apiService.getToken();
      if (token != null && token.isNotEmpty) {
        _expediteur = await _apiService.getMyExpediteur();

        // Reconstituer l'objet User depuis le storage (sauvegardé au login).
        // Sans ça, `auth.user.phone` reste null après un app restart.
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString(AppConstants.keyUserId);
        final phone = prefs.getString(AppConstants.keyUserPhone);
        if (userId != null && phone != null) {
          _user = User(
            id: userId,
            phone: phone,
            role: 'EXPEDITEUR',
            isActive: true,
            isVerified: true,
            createdAt: DateTime.now(),
          );
        }

        _isAuthenticated = true;
      }
    } catch (_) {
      _isAuthenticated = false;
    }
    _isInitializing = false;
    notifyListeners();
  }

  Future<bool> login(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.login(phone, password);
      _user = User.fromJson(response['user']);
      _isAuthenticated = true;

      // Load expediteur profile
      await loadExpediteur();

      // Enregistrer le token FCM maintenant qu'on est connecté
      NotificationService().registerTokenAfterLogin();

      // Analytics
      AnalyticsService.instance.logLoginSuccess('expediteur');
      if (_user?.id != null) {
        AnalyticsService.instance.setUserId(_user!.id.toString());
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiValidationException {
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadExpediteur() async {
    try {
      _expediteur = await _apiService.getMyExpediteur();
      notifyListeners();
    } catch (e) {
      // Expediteur profile not created yet
      _expediteur = null;
    }
  }

  Future<bool> register(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.register(phone, password, 'EXPEDITEUR');
      // Auto-login after registration
      final response = await _apiService.login(phone, password);
      _user = User.fromJson(response['user']);
      _isAuthenticated = true;

      NotificationService().registerTokenAfterLogin();

      _isLoading = false;
      notifyListeners();
      return true;
    } on ApiValidationException {
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> createExpediteurProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _expediteur = await _apiService.createExpediteurProfile(data);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateExpediteur(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _expediteur = await _apiService.updateMyExpediteur(data);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    _user = null;
    _expediteur = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    try {
      await _apiService.deleteMyExpediteur();
    } catch (_) {}
    await _apiService.logout();
    _user = null;
    _expediteur = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
