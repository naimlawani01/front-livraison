import 'package:flutter/foundation.dart';
import 'package:mobile_core/mobile_core.dart';

/// Crédit de l'Expéditeur — solde prépayé qui couvre les commissions.
/// Se recharge via Mobile Money (PSP) ; ne se retire pas.
class CreditProvider extends ChangeNotifier {
  final ApiService _api = ApiService();

  double _solde = 0;
  double _fraisRetourDus = 0;
  List<WalletTransaction> _transactions = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  bool _hasMore = true;

  double get solde => _solde;
  /// Frais de retour impayés : tant que > 0, impossible de créer une course.
  double get fraisRetourDus => _fraisRetourDus;
  List<WalletTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> loadCredit() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final detail = await _api.getCreditDetail();
      _solde = detail.solde;
      _fraisRetourDus = detail.fraisRetourDus;
      _page = 1;
      final result = await _api.getCreditTransactions(page: 1);
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
      final result = await _api.getCreditTransactions(page: next);
      _transactions.addAll(result['transactions'] as List<WalletTransaction>);
      _page = next;
      _hasMore = _page < _totalPages;
    } catch (_) {
      // silencieux
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Initie une recharge. Retourne le `checkout_url` à ouvrir, ou `null`.
  /// Lève une exception (message) en cas d'erreur.
  Future<String?> rechargeCredit(double montant) async {
    final result = await _api.rechargeCredit(montant);
    return result['checkout_url'] as String?;
  }
}
