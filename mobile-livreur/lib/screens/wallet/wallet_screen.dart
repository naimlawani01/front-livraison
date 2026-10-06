import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_core/mobile_core.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wallet_provider.dart';

/// Écran « Vos gains » du livreur.
///
/// Nouveau modèle : les Gains ne font que monter (courses réglées via la
/// plateforme + indemnités) et se retirent. Plus de recharge, plus de dette —
/// les courses cash sont payées en direct par l'expéditeur, hors de cet écran.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

const double _retraitMinimum = 5000;

class _WalletScreenState extends State<WalletScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadWallet();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<WalletProvider>().loadWallet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final summary = wallet.summary;
    final solde = summary?.soldeDisponible ?? 0;
    final reload = context.read<WalletProvider>().loadWallet;

    Widget body;
    if (summary == null) {
      // Rien à montrer encore : un des 3 états d'attente.
      if (wallet.isLoading) {
        body = const LoadingState(message: 'Chargement de vos gains');
      } else if (!NetworkService().isOnline) {
        body = OfflineState(onRetry: reload);
      } else {
        body = ErrorState(message: wallet.error, onRetry: reload);
      }
    } else {
      body = RefreshIndicator(
        onRefresh: reload,
        color: AppTheme.accent,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              sliver: SliverToBoxAdapter(child: _CarteGains(summary: summary)),
            ),
            if (wallet.transactions.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Aucun mouvement',
                    message: 'Vos gains Mobile Money, indemnités et retraits apparaîtront ici.',
                  ),
                ),
              )
            else
              ..._groupesParJour(wallet.transactions).map(
                (g) => SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  sliver: SliverToBoxAdapter(child: _GroupeJour(titre: g.$1, txns: g.$2)),
                ),
              ),
            if (wallet.hasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: wallet.isLoadingMore
                      ? const SizedBox(height: 56, child: LoadingState())
                      : SecondaryButton(
                          label: 'Voir les mouvements plus anciens',
                          onPressed: () => context.read<WalletProvider>().loadMore(),
                        ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Text('Vos gains', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ),
            Expanded(child: body),
            if (summary != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: PrimaryCta(
                  label: solde >= _retraitMinimum ? 'Retirer mes gains' : 'Retrait possible dès 5 000 GNF',
                  onPressed: solde >= _retraitMinimum ? () => _showRetraitSheet(context) : null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRetraitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: context.read<WalletProvider>()),
          ChangeNotifierProvider.value(value: context.read<AuthProvider>()),
        ],
        child: const _RetraitSheet(),
      ),
    );
  }

  /// Regroupe les mouvements par jour (« Aujourd'hui », « Hier », date).
  List<(String, List<WalletTransaction>)> _groupesParJour(List<WalletTransaction> txns) {
    final groupes = <(String, List<WalletTransaction>)>[];
    for (final t in txns) {
      final titre = DateFormatter.jour(t.createdAt).toUpperCase();
      if (groupes.isEmpty || groupes.last.$1 != titre) {
        groupes.add((titre, [t]));
      } else {
        groupes.last.$2.add(t);
      }
    }
    return groupes;
  }
}

// ── Carte « Gains à retirer » (chiffre héros) ───────────────────────────────

class _CarteGains extends StatelessWidget {
  final WalletSummary summary;
  const _CarteGains({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('Gains à retirer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              SizedBox(width: 8),
              BrandDots(size: 4),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              AppCurrency.format(summary.soldeDisponible),
              style: AppTheme.mono(size: 40, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -1),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Courses payées en Mobile Money et indemnités. Les courses en espèces vous sont payées directement par l\'expéditeur.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Stat(label: 'Total gagné', valeur: AppCurrency.format(summary.totalGains))),
              Expanded(child: _Stat(label: 'Courses livrées', valeur: '${summary.nombreCourses}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String valeur;
  const _Stat({required this.label, required this.valeur});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 4),
        Text(valeur, style: AppTheme.mono(size: 15, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: 0)),
      ],
    );
  }
}

// ── Mouvements groupés par jour ──────────────────────────────────────────────

class _GroupeJour extends StatelessWidget {
  final String titre;
  final List<WalletTransaction> txns;
  const _GroupeJour({required this.titre, required this.txns});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Column(
            children: [
              for (var i = 0; i < txns.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _TransactionTile(txn: txns[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final WalletTransaction txn;
  const _TransactionTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final entree = txn.type != 'retrait';
    final label = switch (txn.type) {
      'credit' => txn.description ?? 'Course',
      'retrait' => txn.description ?? 'Retrait',
      'bonus' => txn.description ?? 'Bonus',
      'indemnite' => txn.description ?? 'Indemnité d\'annulation',
      _ => txn.description ?? txn.type,
    };
    final heure = DateFormatter.timeOnly(txn.createdAt);
    final (String? statut, Color? statutCouleur) = switch (txn.statut) {
      'en_attente' || 'en_cours' => ('En cours', AppTheme.warningDark),
      'refuse' => ('Refusé', AppTheme.error),
      _ => (null, null),
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: entree ? AppTheme.successLight : AppTheme.accentLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              entree ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              color: entree ? AppTheme.successDark : AppTheme.accentDark,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    statut == null ? heure : '$heure · $statut',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: statutCouleur ?? AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          Text(
            '${entree ? '+' : '−'}${AppCurrency.format(txn.montant)}',
            style: AppTheme.mono(
              size: 15,
              weight: FontWeight.w800,
              color: entree ? AppTheme.successDark : AppTheme.textPrimary,
              spacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feuille de retrait ───────────────────────────────────────────────────────

class _RetraitSheet extends StatefulWidget {
  const _RetraitSheet();

  @override
  State<_RetraitSheet> createState() => _RetraitSheetState();
}

class _RetraitSheetState extends State<_RetraitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  final _numCtrl = TextEditingController();
  String _methode = 'orange_money';
  bool _loading = false;
  String? _numeroServerError;
  String? _montantServerError;

  static const _methodes = [
    ('orange_money', 'Orange Money'),
    ('mtn_money', 'MTN MoMo'),
  ];

  @override
  void initState() {
    super.initState();
    // Par défaut : tout le solde, vers le numéro du compte.
    final solde = context.read<WalletProvider>().summary?.soldeDisponible ?? 0;
    _montantCtrl.text = solde.floor().toString();
    final phone = context.read<AuthProvider>().user?.phone;
    if (phone != null && phone.isNotEmpty) _numCtrl.text = GuineaPhone.toLocal(phone);
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _numCtrl.dispose();
    super.dispose();
  }

  double? get _montant => double.tryParse(_montantCtrl.text.replaceAll(' ', '').replaceAll(',', '.'));

  Future<void> _submit() async {
    if (_loading) return;
    setState(() {
      _numeroServerError = null;
      _montantServerError = null;
    });
    if (!_formKey.currentState!.validate()) return;

    final String numero;
    try {
      numero = GuineaPhone.normalize(_numCtrl.text);
    } on FormatException catch (e) {
      setState(() => _numeroServerError = e.message);
      return;
    }

    setState(() => _loading = true);
    try {
      final error = await context.read<WalletProvider>().demanderRetrait(
            montant: _montant!,
            methode: _methode,
            numeroPaiement: numero,
          );
      if (!mounted) return;
      setState(() => _loading = false);
      if (error == null) {
        Navigator.pop(context);
        UIUtils.showSuccess(context, 'Demande de retrait envoyée');
      } else {
        UIUtils.showError(context, error);
      }
    } on ApiValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _numeroServerError = e.fieldErrors['numero_telephone'];
        _montantServerError = e.fieldErrors['montant'];
      });
      final mapped = _numeroServerError != null || _montantServerError != null;
      if (!mapped) UIUtils.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final solde = context.watch<WalletProvider>().summary?.soldeDisponible ?? 0;
    final montant = _montant;

    return AppSheet(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Retirer mes gains', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Text(
              'Disponible : ${AppCurrency.format(solde)} · minimum ${AppCurrency.format(_retraitMinimum)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // ── Montant ──
            TextFormField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              style: AppTheme.mono(size: 32, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -0.5),
              onChanged: (_) => setState(() => _montantServerError = null),
              decoration: InputDecoration(
                labelText: 'Montant',
                suffixText: 'GNF',
                errorText: _montantServerError,
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) {
                final m = _montant;
                if (v == null || v.isEmpty) return 'Indiquez un montant';
                if (m == null || m <= 0) return 'Montant invalide';
                if (m < _retraitMinimum) return 'Minimum ${AppCurrency.format(_retraitMinimum)}';
                if (m > solde) return 'C\'est plus que vos gains disponibles';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (solde >= 10000 && solde != 10000)
                  _Choix(
                    label: AppCurrency.format(10000),
                    choisi: montant == 10000,
                    onTap: () => setState(() => _montantCtrl.text = '10000'),
                  ),
                _Choix(
                  label: 'Tout retirer',
                  choisi: montant == solde.floorToDouble(),
                  onTap: () => setState(() => _montantCtrl.text = solde.floor().toString()),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Opérateur ──
            const Text('Vers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < _methodes.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _Tuile(
                      label: _methodes[i].$2,
                      choisie: _methode == _methodes[i].$1,
                      onTap: () => setState(() => _methode = _methodes[i].$1),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            GuineaPhoneField(
              controller: _numCtrl,
              label: 'Numéro Mobile Money',
              errorText: _numeroServerError,
              onChanged: (_) {
                if (_numeroServerError != null) setState(() => _numeroServerError = null);
              },
            ),
            const SizedBox(height: 24),
            PrimaryCta(
              label: montant != null && montant > 0 ? 'Retirer ${AppCurrency.format(montant)}' : 'Retirer',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 8),
            const Text(
              'L\'argent arrive en général en quelques minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Choix extends StatelessWidget {
  final String label;
  final bool choisi;
  final VoidCallback onTap;
  const _Choix({required this.label, required this.choisi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: choisi,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: choisi ? AppTheme.accentDark : AppTheme.textPrimary),
      backgroundColor: AppTheme.cardBg,
      selectedColor: AppTheme.accentLight,
      side: BorderSide(color: choisi ? AppTheme.accent : AppTheme.divider, width: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

class _Tuile extends StatelessWidget {
  final String label;
  final bool choisie;
  final VoidCallback onTap;
  const _Tuile({required this.label, required this.choisie, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: choisie,
      button: true,
      child: Material(
        color: choisie ? AppTheme.accentLight : AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(color: choisie ? AppTheme.accent : AppTheme.divider, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: SizedBox(
            height: 56,
            child: Center(
              child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ),
          ),
        ),
      ),
    );
  }
}
