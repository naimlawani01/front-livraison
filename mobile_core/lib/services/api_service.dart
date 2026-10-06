import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/user.dart';
import '../models/course.dart';
import '../models/livreur.dart';
import '../models/wallet_transaction.dart';

/// Exception levée pour les erreurs de validation FastAPI (HTTP 422).
/// Contient un mapping `champ → message` exploitable par les écrans pour
/// afficher l'erreur sous l'input concerné.
class ApiValidationException implements Exception {
  final String message;
  final Map<String, String> fieldErrors;

  ApiValidationException(this.message, this.fieldErrors);

  @override
  String toString() => message;
}

class ApiService {
  final String baseUrl = AppConstants.baseUrl + AppConstants.apiPrefix;

  bool _isRefreshing = false;

  /// Boot-time backend reachability check. Returns `true` if the backend
  /// `/health` endpoint responds with 200 within 5 seconds. Failures are
  /// silent and never throw — the caller can decide what to do
  /// (e.g. show an offline banner). Does not require auth.
  static Future<bool> healthCheck() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConstants.baseUrl}/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Callback déclenché quand le token ne peut plus être rafraîchi.
  /// L'app doit le brancher sur logout() pour rediriger vers le login.
  static void Function()? onUnauthorized;

  /// Extrait un message lisible depuis la réponse d'erreur FastAPI.
  String _extractError(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map) {
          final msg = _humanizePydanticMessage(first['msg']?.toString() ?? '');
          return msg.isNotEmpty ? msg : fallback;
        }
      }
      return fallback;
    } catch (_) {
      return fallback;
    }
  }

  /// Extrait les erreurs de validation FastAPI 422 comme `Map<champ, message>`.
  /// Renvoie `{}` si la réponse n'est pas un 422 structuré.
  Map<String, String> _extractFieldErrors(http.Response response) {
    final result = <String, String>{};
    try {
      final body = jsonDecode(response.body);
      final detail = body['detail'];
      if (detail is List) {
        for (final item in detail) {
          if (item is! Map) continue;
          final msg = item['msg']?.toString() ?? '';
          final loc = item['loc'];
          if (loc is List && loc.length >= 2 && msg.isNotEmpty) {
            // loc = ["body", "phone"] → on garde "phone"
            final field = loc.last.toString();
            result[field] = _humanizePydanticMessage(msg);
          }
        }
      }
    } catch (_) {}
    return result;
  }

  /// Nettoie un message Pydantic (ex: "Value error, ..." → "...").
  String _humanizePydanticMessage(String msg) {
    final cleaned = msg
        .replaceFirst(RegExp(r'^Value error,\s*'), '')
        .replaceFirst(RegExp(r'^value_error\s*,?\s*'), '');
    return cleaned.isEmpty ? msg : cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  /// Lève la bonne exception selon le code HTTP : `ApiValidationException`
  /// pour les 422, `Exception` simple sinon.
  Never _throwHttpError(http.Response response, String fallback) {
    if (response.statusCode == 422) {
      final fields = _extractFieldErrors(response);
      final message = _extractError(response, fallback);
      throw ApiValidationException(message, fields);
    }
    throw Exception(_extractError(response, fallback));
  }

  // Get auth token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyAccessToken);
  }

  // Get headers with auth
  Future<Map<String, String>> getHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Tente de rafraîchir le token d'accès via le refresh token.
  /// Retourne `true` si le refresh a réussi.
  Future<bool> _tryRefreshToken() async {
    if (_isRefreshing) return false;
    _isRefreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString(AppConstants.keyRefreshToken);
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString(AppConstants.keyAccessToken, data['access_token']);
        await prefs.setString(AppConstants.keyRefreshToken, data['refresh_token']);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Exécute [requestFn]. Si la réponse est 401, tente un refresh puis réessaie.
  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function(Map<String, String> headers) requestFn,
  ) async {
    var headers = await getHeaders();
    var response = await requestFn(headers);

    if (response.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        headers = await getHeaders();
        response = await requestFn(headers);
      } else {
        // Refresh échoué → clear session et notifier l'app
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        onUnauthorized?.call();
      }
    }
    return response;
  }

  Future<http.Response> _get(String url) =>
      _authenticatedRequest((h) => http.get(Uri.parse(url), headers: h));

  Future<http.Response> _post(String url, {String? body}) =>
      _authenticatedRequest((h) => http.post(Uri.parse(url), headers: h, body: body));

  Future<http.Response> _patch(String url, {String? body}) =>
      _authenticatedRequest((h) => http.patch(Uri.parse(url), headers: h, body: body));

  Future<http.Response> _delete(String url) =>
      _authenticatedRequest((h) => http.delete(Uri.parse(url), headers: h));

  // AUTH ENDPOINTS
  
  Future<Map<String, dynamic>> login(String phone, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Save tokens
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAccessToken, data['access_token']);
      await prefs.setString(AppConstants.keyRefreshToken, data['refresh_token']);
      await prefs.setString(AppConstants.keyUserId, data['user']['id']);
      await prefs.setString(AppConstants.keyUserPhone, data['user']['phone']);
      return data;
    } else {
      _throwHttpError(response, 'Identifiants incorrects');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  Future<Map<String, dynamic>> register(String phone, String password, String role) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone': phone, 'password': password, 'role': role}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      _throwHttpError(response, 'Inscription échouée');
    }
  }

  Future<Expediteur> createExpediteurProfile(Map<String, dynamic> data) async {
    final response = await _post('$baseUrl/expediteurs/', body: jsonEncode(data));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Expediteur.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Échec de la création du profil expediteur');
    }
  }

  // EXPEDITEUR ENDPOINTS
  
  Future<Expediteur> getMyExpediteur() async {
    final response = await _get('$baseUrl/expediteurs/me');
    if (response.statusCode == 200) {
      return Expediteur.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Impossible de charger le expediteur');
    }
  }

  Future<Expediteur> createExpediteur(Map<String, dynamic> data) async {
    final response = await _post('$baseUrl/expediteurs/', body: jsonEncode(data));
    if (response.statusCode == 201) {
      return Expediteur.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Impossible de créer le expediteur');
    }
  }

  Future<Expediteur> updateMyExpediteur(Map<String, dynamic> data) async {
    final response = await _patch('$baseUrl/expediteurs/me', body: jsonEncode(data));
    if (response.statusCode == 200) {
      return Expediteur.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Échec de la mise à jour');
    }
  }

  Future<void> deleteMyExpediteur() async {
    final response = await _delete('$baseUrl/expediteurs/me');
    if (response.statusCode != 204) {
      _throwHttpError(response, 'Impossible de supprimer le compte');
    }
  }

  // COURSE ENDPOINTS
  
  Future<Course> createCourse(Map<String, dynamic> data) async {
    final response = await _post('$baseUrl/courses/', body: jsonEncode(data));
    if (response.statusCode == 201) {
      return Course.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Impossible de créer la course');
    }
  }

  /// Relance la diffusion d'une course cash restée en attente faute de Crédit
  /// suffisant (après recharge). Lève une exception avec le message du backend
  /// (ex. « Crédit insuffisant… ») sinon.
  Future<Course> rediffuserCourse(String courseId) async {
    final response = await _post('$baseUrl/courses/$courseId/diffuser');
    if (response.statusCode == 200) {
      return Course.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Impossible de relancer la course');
    }
  }

  /// Régénère le lien de paiement Mobile Money d'une course (lien expiré, ou
  /// course en attente de Crédit). Retourne `{reference, checkout_url}`.
  Future<Map<String, dynamic>> relancerPaiement(String courseId) async {
    final response = await _post('$baseUrl/payments/courses/$courseId/relancer');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      _throwHttpError(response, 'Impossible de relancer le paiement');
    }
  }

  Future<Map<String, dynamic>> estimerPrix(double lat, double lng, {String natureColis = 'standard'}) async {
    final response = await _post(
      '$baseUrl/courses/estimer-prix',
      body: jsonEncode({
        'latitude_client': lat,
        'longitude_client': lng,
        'nature_colis': natureColis,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      _throwHttpError(response, 'Échec de l\'estimation du prix');
    }
  }

  Future<List<Course>> getMyCourses({String? statusFilter, int page = 1, int limit = 20}) async {
    var url = '$baseUrl/courses/me?page=$page&limit=$limit';
    if (statusFilter != null) {
      url += '&status_filter=$statusFilter';
    }
    final response = await _get(url);
    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> data = body['courses'] ?? [];
      return data.map((json) => Course.fromJson(json)).toList();
    } else {
      _throwHttpError(response, 'Impossible de charger les courses');
    }
  }

  Future<Course> getCourseDetails(String courseId) async {
    final response = await _get('$baseUrl/courses/$courseId');
    if (response.statusCode == 200) {
      return Course.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Impossible de charger les détails');
    }
  }

  Future<Course> cancelCourse(String courseId, String raison) async {
    final response = await _post(
      '$baseUrl/courses/$courseId/annuler',
      body: jsonEncode({'raison': raison}),
    );
    if (response.statusCode == 200) {
      return Course.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Échec de l\'annulation de la course');
    }
  }

  // LIVRAISON IMPOSSIBLE → RETOUR DU COLIS

  /// Livreur : « Je suis chez le client » (démarre l'attente avant « client absent »).
  Future<Course> signalerArriveeClient(String courseId) async {
    final response = await _post('$baseUrl/courses/$courseId/arrivee-client');
    if (response.statusCode == 200) return Course.fromJson(jsonDecode(response.body));
    _throwHttpError(response, 'Impossible de signaler votre arrivée');
  }

  /// Livreur : livraison impossible. `raison` = `client_absent` ou `refus_client`.
  Future<Course> declarerEchecLivraison(String courseId, String raison) async {
    final response = await _post(
      '$baseUrl/courses/$courseId/echec-livraison',
      body: jsonEncode({'raison': raison}),
    );
    if (response.statusCode == 200) return Course.fromJson(jsonDecode(response.body));
    _throwHttpError(response, 'Impossible de déclarer la livraison impossible');
  }

  /// Expéditeur : il a récupéré son colis (verse les frais de retour au livreur).
  Future<Course> confirmerRetourRecu(String courseId) async {
    final response = await _post('$baseUrl/courses/$courseId/retour-recu');
    if (response.statusCode == 200) return Course.fromJson(jsonDecode(response.body));
    _throwHttpError(response, 'Impossible de confirmer le retour du colis');
  }

  // LOCATION LINK

  Future<Map<String, dynamic>> generateLocationLink(String courseId) async {
    final response = await _post('$baseUrl/courses/$courseId/location-link');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      _throwHttpError(response, 'Échec de la génération du lien');
    }
  }

  // TRACKING LINK

  Future<Map<String, dynamic>> generateTrackingLink(String courseId) async {
    final response = await _post('$baseUrl/courses/$courseId/tracking-link');
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      _throwHttpError(response, 'Échec de la génération du lien de suivi');
    }
  }

  // DEVICE TOKEN

  Future<void> updateDeviceToken(String token) async {
    try {
      await _post('$baseUrl/auth/device-token', body: jsonEncode({'device_token': token}));
    } catch (_) {}
  }

  Future<Course> evaluerLivreur(
    String courseId,
    int note,
    String? commentaire,
  ) async {
    final response = await _post(
      '$baseUrl/courses/$courseId/evaluer',
      body: jsonEncode({
        'note_livreur': note,
        'commentaire_livreur': commentaire,
      }),
    );
    if (response.statusCode == 200) {
      return Course.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Impossible d\'évaluer le livreur');
    }
  }

  // LIVREUR ENDPOINTS

  Future<List<Course>> getCoursesDisponibles({double? lat, double? lon}) async {
    var url = '$baseUrl/courses/livreur/disponibles';
    if (lat != null && lon != null) {
      url += '?lat=$lat&lon=$lon';
    }
    final response = await _get(url);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Course.fromJson(json)).toList();
    } else {
      _throwHttpError(response, 'Impossible de charger les courses disponibles');
    }
  }

  Future<List<Course>> getMesCourses({int page = 1, int limit = 20}) async {
    final response = await _get('$baseUrl/courses/livreur/mes-courses?page=$page&limit=$limit');
    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final List<dynamic> data = body['courses'] ?? [];
      return data.map((json) => Course.fromJson(json)).toList();
    } else {
      _throwHttpError(response, 'Impossible de charger vos courses');
    }
  }

  Future<Course> accepterCourse(String courseId) async {
    final response = await _post('$baseUrl/courses/$courseId/accepter');
    if (response.statusCode == 200) {
      return Course.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Impossible d\'accepter cette course');
    }
  }

  Future<Course> updateCourseStatus(String courseId, String status, {String? codeLivraison}) async {
    var url = '$baseUrl/courses/$courseId/statut?nouveau_statut=$status';
    if (codeLivraison != null) {
      url += '&code_livraison=$codeLivraison';
    }
    final response = await _patch(url);
    if (response.statusCode == 200) {
      return Course.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Impossible de mettre à jour le statut');
    }
  }

  Future<Course> confirmerPaiement(String courseId) async {
    final response = await _post('$baseUrl/courses/$courseId/confirmer-paiement');
    if (response.statusCode == 200) {
      return Course.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Impossible de confirmer le paiement');
    }
  }

  Future<Livreur> updateDisponibilite(bool disponible) async {
    final response = await _patch(
      '$baseUrl/livreurs/me/disponibilite',
      body: jsonEncode({'is_disponible': disponible}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Livreur.fromJson(jsonDecode(response.body));
    } else {
      _throwHttpError(response, 'Impossible de changer la disponibilité');
    }
  }

  Future<void> updateLocation(double lat, double lng) async {
    final response = await _patch(
      '$baseUrl/livreurs/me/location',
      body: jsonEncode({'latitude': lat, 'longitude': lng}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update location');
    }
  }

  /// Upload un document livreur vers Cloudflare R2.
  static MediaType _mediaTypeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':  return MediaType('application', 'pdf');
      case 'png':  return MediaType('image', 'png');
      case 'webp': return MediaType('image', 'webp');
      case 'heic':
      case 'heif': return MediaType('image', 'heic');
      default:     return MediaType('image', 'jpeg');
    }
  }

  /// [type] : "piece_identite" | "vehicule_doc" | "photo_profil"
  /// [vehiculeDocType] : "permis_conduire" | "carte_grise" (requis si type=vehicule_doc)
  Future<void> uploadDocument(String type, String path, {String? vehiculeDocType}) async {
    final uri = Uri.parse('$baseUrl/livreurs/upload-document');
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await getHeaders());
    request.fields['document_type'] = type;
    if (vehiculeDocType != null) request.fields['vehicule_doc_type'] = vehiculeDocType;
    request.files.add(await http.MultipartFile.fromPath(
      'file', path,
      contentType: _mediaTypeFromPath(path),
    ));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwHttpError(response, 'Échec de l\'upload du document');
    }
  }

  /// Upload un document expediteur. [documentType] : "devanture" | "rccm"
  Future<void> uploadDevanture(String path, {String documentType = 'devanture'}) async {
    final uri = Uri.parse('$baseUrl/expediteurs/me/upload-document');
    var request = http.MultipartRequest('POST', uri);
    request.headers.addAll(await getHeaders());
    request.fields['document_type'] = documentType;
    request.files.add(await http.MultipartFile.fromPath(
      'file', path,
      contentType: _mediaTypeFromPath(path),
    ));
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200 && response.statusCode != 201) {
      _throwHttpError(response, 'Échec de l\'upload du document');
    }
  }

  Future<Livreur> getMyProfile() async {
    final response = await _get('$baseUrl/livreurs/me');
    if (response.statusCode == 200) {
      return Livreur.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load profile');
    }
  }

  Future<Livreur> createLivreurProfile(Map<String, dynamic> data) async {
    final response = await _post('$baseUrl/livreurs/', body: jsonEncode(data));
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Livreur.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create profile');
    }
  }

  Future<Livreur> updateMyProfile(Map<String, dynamic> data) async {
    final response = await _patch('$baseUrl/livreurs/me', body: jsonEncode(data));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return Livreur.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update profile : ${response.body}');
    }
  }

  Future<void> deleteMyLivreur() async {
    final response = await _delete('$baseUrl/livreurs/me');
    if (response.statusCode != 204) {
      _throwHttpError(response, 'Impossible de supprimer le compte');
    }
  }

  // ── Wallet ──────────────────────────────────────────────────────────────

  Future<WalletSummary> getWallet() async {
    final response = await _get('$baseUrl/livreurs/me/wallet');
    if (response.statusCode == 200) {
      return WalletSummary.fromJson(json.decode(response.body));
    }
    _throwHttpError(response, 'Impossible de charger le wallet');
  }

  Future<Map<String, dynamic>> getWalletTransactions({int page = 1}) async {
    final response = await _get('$baseUrl/livreurs/me/wallet/transactions?page=$page&limit=20');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final txns = (data['transactions'] as List)
          .map((e) => WalletTransaction.fromJson(e))
          .toList();
      return {
        'total': data['total'],
        'page': data['page'],
        'pages': data['pages'],
        'transactions': txns,
      };
    }
    _throwHttpError(response, 'Impossible de charger les transactions');
  }

  // ── Crédit expéditeur (expediteur) ─────────────────────────────────────────

  /// Solde de Crédit courant de l'expéditeur.
  Future<double> getCredit() async {
    final response = await _get('$baseUrl/expediteurs/me/credit');
    if (response.statusCode == 200) {
      return ((json.decode(response.body)['credit_solde']) as num).toDouble();
    }
    _throwHttpError(response, 'Impossible de charger le Crédit');
  }

  /// Solde du Crédit + frais de retour encore dus (bloquent la création de
  /// course tant qu'ils ne sont pas réglés par une recharge).
  Future<({double solde, double fraisRetourDus})> getCreditDetail() async {
    final response = await _get('$baseUrl/expediteurs/me/credit');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (
        solde: (data['credit_solde'] as num).toDouble(),
        fraisRetourDus: ((data['frais_retour_dus'] ?? 0) as num).toDouble(),
      );
    }
    _throwHttpError(response, 'Impossible de charger le Crédit');
  }

  /// Historique paginé des mouvements de Crédit (réutilise WalletTransaction).
  Future<Map<String, dynamic>> getCreditTransactions({int page = 1}) async {
    final response =
        await _get('$baseUrl/expediteurs/me/credit/transactions?page=$page&limit=20');
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final txns = (data['transactions'] as List)
          .map((e) => WalletTransaction.fromJson(e))
          .toList();
      return {
        'total': data['total'],
        'page': data['page'],
        'pages': data['pages'],
        'transactions': txns,
      };
    }
    _throwHttpError(response, 'Impossible de charger les mouvements');
  }

  /// Initie une recharge du Crédit via Mobile Money. Retourne `{reference, checkout_url, montant}`.
  Future<Map<String, dynamic>> rechargeCredit(double montant) async {
    final response = await _post(
      '$baseUrl/expediteurs/me/credit/recharge',
      body: jsonEncode({'montant': montant}),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    _throwHttpError(response, 'Impossible de lancer la recharge');
  }

  Future<Map<String, dynamic>> demanderRetrait({
    required double montant,
    required String methode,
    required String numeroPaiement,
  }) async {
    final body = json.encode({
      'montant': montant,
      'methode': methode,
      'numero_telephone': numeroPaiement,
    });
    final response = await _post('$baseUrl/livreurs/me/wallet/retrait', body: body);
    if (response.statusCode == 201) {
      return json.decode(response.body);
    }
    _throwHttpError(response, 'Demande de retrait échouée');
  }
}
