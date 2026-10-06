import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_core/mobile_core.dart';
import '../services/websocket_service.dart';

class CourseProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Course> _coursesDisponibles = [];
  List<Course> _mesCourses = [];
  Course? _currentCourse;
  bool _isLoading = false;
  String? _error;

  List<Course> get coursesDisponibles => _coursesDisponibles;
  List<Course> get mesCourses => _mesCourses;
  Course? get currentCourse => _currentCourse;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // --- WebSocket ---
  WebSocketService? _wsService;
  StreamSubscription? _wsSubscription;
  bool _isDisponible = false;

  /// Synchronisé depuis AuthProvider à chaque changement de disponibilité
  void setDisponible(bool value) {
    _isDisponible = value;
    // Vider la liste si le livreur passe hors ligne
    if (!value && _coursesDisponibles.isNotEmpty) {
      _coursesDisponibles = [];
      notifyListeners();
    }
  }

  Future<void> initWebSocket(String userId, {bool isDisponible = false}) async {
    if (_wsService != null) return;

    // Synchroniser l'état disponibilité dès le départ
    _isDisponible = isDisponible;

    // Récupérer le token depuis le stockage sécurisé
    final token = await ApiService().getToken() ?? '';
    if (token.isEmpty) {
      debugPrint('WS: token manquant, connexion annulée');
      return;
    }
    
    _wsService = WebSocketService(userId: userId, userType: 'livreur', token: token);
    
    _wsSubscription = _wsService!.messages.listen((payload) {
      if (payload['type'] == 'nouvelle_course' && payload['data'] != null) {
        if (!_isDisponible) return;
        try {
          final nouvelleCourse = Course.fromJson(payload['data']);
          if (!_coursesDisponibles.any((c) => c.id == nouvelleCourse.id)) {
            _coursesDisponibles.insert(0, nouvelleCourse);
            // Notification locale pour alerter le livreur même s'il n'est pas sur l'écran
            final gain = AppCurrency.format(nouvelleCourse.montantLivreur);
            final depart = nouvelleCourse.expediteurNom ?? nouvelleCourse.expediteurAdresse ?? 'Départ';
            NotificationService().showLocalNotification(
              title: '🛵 Nouvelle course — $gain',
              body: 'Prise en charge : $depart',
              payload: 'nouvelle_course',
            );
            notifyListeners();
          }
        } catch (e) {
          debugPrint('Erreur lecture course WS : $e');
        }
      }
    });
  }

  /// Reconnecte le WebSocket immédiatement (ex. : retour au premier plan).
  void onAppResumed(String userId) {
    if (_wsService != null) {
      _wsService!.forceReconnect();
    } else {
      initWebSocket(userId, isDisponible: _isDisponible);
    }
  }

  void disconnectWebSocket() {
    _wsSubscription?.cancel();
    _wsService?.disconnect();
    _wsService = null;
  }
  // ----------------

  Course? get courseEnCours {
    try {
      return _mesCourses.firstWhere(
        (c) {
          final s = c.status.toUpperCase();
          return s == 'ACCEPTEE' || s == 'EN_RECUPERATION' || s == 'EN_LIVRAISON';
        },
      );
    } catch (_) {
      return _mesCourses.isNotEmpty ? _mesCourses.first : null;
    }
  }

  Future<void> loadCoursesDisponibles({double? lat, double? lon}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _coursesDisponibles = await _apiService.getCoursesDisponibles(
        lat: lat,
        lon: lon,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '');
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMesCourses() async {
    try {
      _mesCourses = await _apiService.getMesCourses();
      
      // Set current course if exists
      if (_mesCourses.isNotEmpty) {
        _currentCourse = courseEnCours;
      }
      
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '');
      notifyListeners();
    }
  }

  Future<bool> accepterCourse(String courseId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final course = await _apiService.accepterCourse(courseId);

      // Remove from available
      _coursesDisponibles.removeWhere((c) => c.id == courseId);

      // Add to my courses
      _mesCourses.insert(0, course);
      _currentCourse = course;

      AnalyticsService.instance.logCourseAccepted(courseId);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      final raw = e.toString();
      _error = raw.replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '');
      // Si la course est déjà prise, on retire la carte — elle n'est plus disponible
      if ((_error ?? '').toLowerCase().contains('déjà') || (_error ?? '').toLowerCase().contains('prise')) {
        _coursesDisponibles.removeWhere((c) => c.id == courseId);
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCourseStatus(String courseId, String status, {String? codeLivraison}) async {
    try {
      final course = await _apiService.updateCourseStatus(courseId, status, codeLivraison: codeLivraison);
      
      // Update in list
      final index = _mesCourses.indexWhere((c) => c.id == courseId);
      if (index != -1) {
        _mesCourses[index] = course;
      }
      
      if (_currentCourse?.id == courseId) {
        _currentCourse = course;
      }
      
      // Quand une course est terminée, notifier pour recharger le wallet
      if (status.toUpperCase() == 'TERMINEE') {
        onCourseTerminee?.call();
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '');
      notifyListeners();
      return false;
    }
  }

  /// Callback déclenché quand une course passe en TERMINEE.
  /// Brancher sur WalletProvider.loadWallet() dans le widget parent.
  void Function()? onCourseTerminee;

  Future<bool> confirmerPaiement(String courseId) async {
    try {
      final course = await _apiService.confirmerPaiement(courseId);

      // Update in list
      final index = _mesCourses.indexWhere((c) => c.id == courseId);
      if (index != -1) {
        _mesCourses[index] = course;
      }

      if (_currentCourse?.id == courseId) {
        _currentCourse = course;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelCourse(String courseId, String raison) async {
    try {
      await _apiService.cancelCourse(courseId, raison);

      // Retirer la course de la liste
      _mesCourses.removeWhere((c) => c.id == courseId);

      if (_currentCourse?.id == courseId) {
        _currentCourse = _mesCourses.isNotEmpty ? courseEnCours : null;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst(RegExp(r'^Exception:\s*', caseSensitive: false), '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnectWebSocket();
    super.dispose();
  }
}
