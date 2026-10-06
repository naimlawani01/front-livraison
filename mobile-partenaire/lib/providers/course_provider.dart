import 'package:flutter/material.dart';
import 'package:mobile_core/mobile_core.dart';

class CourseProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Course> _courses = [];
  Course? _selectedCourse;
  bool _isLoading = false;
  bool _isEstimating = false;
  String? _error;

  List<Course> get courses => _courses;
  Course? get selectedCourse => _selectedCourse;
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
    return _courses.where((c) {
      final s = c.status.toUpperCase();
      return s != 'TERMINEE' && s != 'ANNULEE';
    }).toList();
  }

  List<Course> get coursesTerminees {
    return _courses.where((c) {
      final s = c.status.toUpperCase();
      return s == 'TERMINEE' || s == 'ANNULEE';
    }).toList();
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
