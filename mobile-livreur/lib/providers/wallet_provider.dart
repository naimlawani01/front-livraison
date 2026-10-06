import 'package:flutter/foundation.dart';
import 'package:mobile_core/mobile_core.dart';

class WalletProvider extends ChangeNotifier {
  final ApiService _api;

  WalletProvider(this._api);

  WalletSummary? _summary;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  bool _hasMore = true;

  WalletSummary? get summary => _summary;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> loadWallet() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _summary = await _api.getWallet();
      _page = 1;
      final result = await _api.getWalletTransactions(page: 1);
      _transactions = result['transactions'] as List<WalletTransaction>;
      _totalPages = result['pages'] as int;
      _hasMore = _page < _totalPages;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final next = _page + 1;
      final result = await _api.getWalletTransactions(page: next);
      _transactions.addAll(result['transactions'] as List<WalletTransaction>);
      _page = next;
      _hasMore = _page < _totalPages;
    } catch (_) {
      // silencieux — on laisse les données existantes
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Lance une demande de retrait. Retourne `null` en cas de succès,
  /// un message d'erreur sinon. Lève [ApiValidationException] si le backend
  /// renvoie une erreur 422 (mapping champ → message).
  Future<String?> demanderRetrait({
    required double montant,
    required String methode,
    required String numeroPaiement,
  }) async {
    try {
      final result = await _api.demanderRetrait(
        montant: montant,
        methode: methode,
        numeroPaiement: numeroPaiement,
      );
      AnalyticsService.instance.logWithdrawalRequested(
        amount: montant,
        method: methode,
      );
      if (_summary != null) {
        _summary = WalletSummary(
          soldeDisponible: (result['solde_apres'] as num).toDouble(),
          totalGains: _summary!.totalGains,
          nombreCourses: _summary!.nombreCourses,
        );
      }
      final txnResult = await _api.getWalletTransactions(page: 1);
      _transactions = txnResult['transactions'] as List<WalletTransaction>;
      _page = 1;
      _totalPages = txnResult['pages'] as int;
      _hasMore = _page < _totalPages;
      notifyListeners();
      return null;
    } on ApiValidationException {
      rethrow;
    } catch (e) {
      return e.toString().replaceFirst('Exception: ', '');
    }
  }
}
