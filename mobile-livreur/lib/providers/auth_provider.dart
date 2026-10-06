import 'package:flutter/material.dart';
import 'package:mobile_core/mobile_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class User {
  final String id;
  final String phone;
  final String role;
  final bool isVerified;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.phone,
    required this.role,
    required this.isVerified,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      phone: json['phone'],
      role: json['role'],
      isVerified: json['is_verified'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  User? _user;
  Livreur? _livreur;
  bool _isAuthenticated = false;
  bool _isInitializing = true; // true seulement pendant init() au boot
  bool _isLoading = false;     // true pendant login/register en cours
  String? _error;

  User? get user => _user;
  Livreur? get livreur => _livreur;
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
        // Token présent → charger le profil pour valider la session
        _livreur = await _apiService.getMyProfile();

        // Reconstituer l'objet User depuis le storage (sauvegardé au login).
        // Sans ça, `auth.user.phone` reste null après un app restart.
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString(AppConstants.keyUserId);
        final phone = prefs.getString(AppConstants.keyUserPhone);
        if (userId != null && phone != null) {
          _user = User(
            id: userId,
            phone: phone,
            role: 'LIVREUR',
            isVerified: _livreur?.isVerified ?? false,
          );
        }

        _isAuthenticated = true;

        // Sécurité : au boot, le tracking GPS local n'est pas démarré
        // (l'utilisateur n'a rien tapé). Si la BDD pense encore qu'il est
        // disponible (app fermée brusquement la fois précédente), on
        // réaligne en remettant offline. Il devra retaper le bouton pour
        // passer en ligne. Évite que le matching dispatche des courses
        // à un livreur qui ne les voit même pas.
        if (_livreur != null && _livreur!.isDisponible) {
          try {
            _livreur = await _apiService.updateDisponibilite(false);
          } catch (_) {
            // Si l'API échoue, on continue — le toggle suivant resyncronisera
          }
        }
      }
    } catch (_) {
      // Token expiré ou invalide → rester déconnecté
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

      // Load livreur profile
      await loadProfile();

      // Enregistrer le token FCM maintenant qu'on est connecté
      NotificationService().registerTokenAfterLogin();

      // Analytics
      AnalyticsService.instance.logLoginSuccess('livreur');
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

  Future<void> loadProfile() async {
    try {
      _livreur = await _apiService.getMyProfile();
      notifyListeners();
    } catch (e) {
      _livreur = null;
    }
  }

  /// Rafraîchir le profil livreur (après upload de document, etc.)
  Future<void> refreshProfile() async {
    await loadProfile();
  }

  Future<bool> toggleDisponibilite() async {
    if (_livreur == null) return false;

    try {
      final newAvailability = !_livreur!.isDisponible;
      _livreur = await _apiService.updateDisponibilite(newAvailability);
      AnalyticsService.instance.logOnlineToggle(newAvailability);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String phone, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.register(phone, password, 'LIVREUR');
      // On s'authentifie directement pour récupérer les tokens JWT
      final loginSuccess = await login(phone, password);

      _isLoading = false;
      notifyListeners();
      return loginSuccess;
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

  Future<bool> createLivreurProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _livreur = await _apiService.createLivreurProfile(data);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateLivreurProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _livreur = await _apiService.updateMyProfile(data);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _apiService.logout();
    _user = null;
    _livreur = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    try {
      await _apiService.deleteMyLivreur();
    } catch (_) {}
    await _apiService.logout();
    _user = null;
    _livreur = null;
    _isAuthenticated = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
