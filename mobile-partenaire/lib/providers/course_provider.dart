import 'package:flutter/material.dart';
import 'package:mobile_core/mobile_core.dart';

class CourseProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Course> _courses = [];
  Course? _selectedCourse;
  Course? _lastCreatedCourse;
  bool _isLoading = false;
  bool _isEstimating = false;
  String? _error;

  List<Course> get courses => _courses;
  Course? get selectedCourse => _selectedCourse;
  /// Dernière course créée (pour adapter le message de confirmation).
  Course? get lastCreatedCourse => _lastCreatedCourse;
  bool get isLoading => _isLoading;
  bool get isEstimating => _isEstimating;
  String? get error => _error;

  Future<Map<String, dynamic>?> estimerPrix(double lat, double lng, {String natureColis = 'standard'}) async {
    _isEstimating = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _apiService.estimerPrix(lat, lng, natureColis: natureColis);
      _isEstimating = false;
      notifyListeners();
      return result;
    } catch (e) {
      _error = e.toString();
      _isEstimating = false;
      notifyListeners();
      return null;
    }
  }

  List<Course> get coursesEnCours {
    return _courses.where((c) => !c.isFinie).toList();
  }

  List<Course> get coursesTerminees {
    return _courses.where((c) => c.isFinie).toList();
  }

  Future<void> loadCourses({String? statusFilter}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _courses = await _apiService.getMyCourses(statusFilter: statusFilter);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createCourse(Map<String, dynamic> data) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final course = await _apiService.createCourse(data);
      _lastCreatedCourse = course;
      _courses.insert(0, course);
      AnalyticsService.instance.logCourseCreated(
        courseId: course.id.toString(),
        prix: course.prixPropose,
      );
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

  void _remplacer(Course course) {
    final index = _courses.indexWhere((c) => c.id == course.id);
    if (index != -1) _courses[index] = course;
    if (_selectedCourse?.id == course.id) _selectedCourse = course;
  }

  /// Relance une course cash restée en attente faute de Crédit (après recharge).
  /// Retourne null si OK, sinon le message d'erreur du backend.
  Future<String?> rediffuserCourse(String courseId) async {
    try {
      final course = await _apiService.rediffuserCourse(courseId);
      _remplacer(course);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }

  /// Régénère le lien de paiement Mobile Money. Retourne l'URL, ou lève une
  /// exception avec le message du backend (ex. Crédit insuffisant).
  Future<String?> relancerPaiement(String courseId) async {
    final res = await _apiService.relancerPaiement(courseId);
    await loadCourseDetails(courseId);
    return res['checkout_url'] as String?;
  }

  Future<void> loadCourseDetails(String courseId) async {
    try {
      _selectedCourse = await _apiService.getCourseDetails(courseId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<bool> cancelCourse(String courseId, String raison) async {
    try {
      final course = await _apiService.cancelCourse(courseId, raison);
      // Update in list
      final index = _courses.indexWhere((c) => c.id == courseId);
      if (index != -1) {
        _courses[index] = course;
      }
      _selectedCourse = course;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> evaluerLivreur(String courseId, int note, String? commentaire) async {
    try {
      final course = await _apiService.evaluerLivreur(courseId, note, commentaire);
      // Update in list
      final index = _courses.indexWhere((c) => c.id == courseId);
      if (index != -1) {
        _courses[index] = course;
      }
      _selectedCourse = course;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
