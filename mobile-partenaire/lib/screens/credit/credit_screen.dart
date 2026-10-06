import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_core/mobile_core.dart';
import '../../providers/credit_provider.dart';

/// Commission moyenne indicative — sert à afficher « ≈ N courses couvertes ».
const double _kCommissionMoyenne = 1680;

/// Écran « Crédit » de l'expéditeur.
///
/// Le Crédit se dépense (commission de chaque course) et se recharge via Mobile
/// Money. Il ne se retire pas. La recharge est appliquée après confirmation du
/// paiement par le webhook (le solde se met à jour ensuite).
class CreditScreen extends StatefulWidget {
  const CreditScreen({super.key});

  @override
  State<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends State<CreditScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CreditProvider>().loadCredit();
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
      context.read<CreditProvider>().loadCredit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final credit = context.watch<CreditProvider>();
    final reload = context.read<CreditProvider>().loadCredit;
    final rienAMontrer = credit.solde == 0 && credit.transactions.isEmpty;

    Widget body;
    if (rienAMontrer && credit.isLoading) {
      body = const LoadingState(message: 'Chargement de votre Crédit');
    } else if (rienAMontrer && !NetworkService().isOnline) {
      body = OfflineState(onRetry: reload);
    } else if (rienAMontrer && credit.error != null) {
      body = ErrorState(message: 'Votre Crédit n\'a pas pu être chargé.', onRetry: reload);
    } else {
      final groupes = <(String, List<WalletTransaction>)>[];
      for (final t in credit.transactions) {
        final titre = DateFormatter.jour(t.createdAt).toUpperCase();
        if (groupes.isEmpty || groupes.last.$1 != titre) {
          groupes.add((titre, [t]));
        } else {
          groupes.last.$2.add(t);
        }
      }
      body = RefreshIndicator(
        onRefresh: reload,
        color: AppTheme.accent,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _CarteCredit(solde: credit.solde),
            if (credit.transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Aucun mouvement',
                  message: 'Vos recharges et les commissions de vos courses apparaîtront ici.',
                ),
              )
            else
              for (final g in groupes) ...[
                const SizedBox(height: 24),
                Text(g.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
                  child: Column(
                    children: [
                      for (var i = 0; i < g.$2.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _CreditTile(txn: g.$2[i]),
                      ],
                    ],
                  ),
                ),
              ],
            if (credit.hasMore) ...[
              const SizedBox(height: 16),
              credit.isLoadingMore
                  ? const SizedBox(height: 56, child: LoadingState())
                  : SecondaryButton(
                      label: 'Voir les mouvements plus anciens',
                      onPressed: () => context.read<CreditProvider>().loadMore(),
                    ),
            ],
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
              child: Text('Votre Crédit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ),
            Expanded(child: body),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: PrimaryCta(label: 'Recharger mon Crédit', onPressed: () => _showRechargeSheet(context)),
            ),
          ],
        ),
      ),
    );
  }

  void _showRechargeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<CreditProvider>(),
        child: const _RechargeSheet(),
      ),
    );
  }
}

// ── Carte Crédit (chiffre héros) ─────────────────────────────────────────────

class _CarteCredit extends StatelessWidget {
  final double solde;
  const _CarteCredit({required this.solde});

  @override
  Widget build(BuildContext context) {
    final nbCouvertes = (solde / _kCommissionMoyenne).floor();
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
              Text('Solde', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              SizedBox(width: 8),
              BrandDots(size: 4),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(AppCurrency.format(solde),
                style: AppTheme.mono(size: 40, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -1)),
          ),
          const SizedBox(height: 8),
          Text(
            nbCouvertes > 0 ? '≈ $nbCouvertes courses couvertes' : 'Rechargez pour créer des courses',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: nbCouvertes > 0 ? AppTheme.textPrimary : AppTheme.accentDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Le Crédit couvre la commission Sönaiyaa (12 %) de chaque course. Elle vous est rendue si votre client paie la livraison ou si la course est annulée.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── Mouvement de Crédit ──────────────────────────────────────────────────────

class _CreditTile extends StatelessWidget {
  final WalletTransaction txn;
  const _CreditTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    // Sorties : commission d'une course, indemnité versée au livreur.
    final sortie = txn.type == 'commission' || txn.type == 'indemnite';
    final label = switch (txn.type) {
      'recharge' => txn.description ?? 'Recharge',
      'commission' => txn.description ?? 'Commission d\'une course',
      'remboursement' => txn.description ?? 'Commission rendue',
      'avoir' => txn.description ?? 'Avoir (paiement remboursé)',
      'indemnite' => txn.description ?? 'Indemnité d\'annulation au livreur',
      'ajustement_admin' => txn.description ?? 'Ajustement',
      _ => txn.description ?? txn.type,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: sortie ? AppTheme.accentLight : AppTheme.successLight, shape: BoxShape.circle),
            child: Icon(
              sortie ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
              color: sortie ? AppTheme.accentDark : AppTheme.successDark,
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
                  Text(DateFormatter.timeOnly(txn.createdAt),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ],
              ),
            ),
          ),
          Text(
            '${sortie ? '−' : '+'}${AppCurrency.format(txn.montant)}',
            style: AppTheme.mono(size: 15, weight: FontWeight.w800, color: sortie ? AppTheme.textPrimary : AppTheme.successDark, spacing: 0),
          ),
        ],
      ),
    );
  }
}

// ── Feuille de recharge ──────────────────────────────────────────────────────

class _RechargeSheet extends StatefulWidget {
  const _RechargeSheet();

  @override
  State<_RechargeSheet> createState() => _RechargeSheetState();
}

class _RechargeSheetState extends State<_RechargeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController(text: '25000');
  bool _loading = false;

  @override
  void dispose() {
    _montantCtrl.dispose();
    super.dispose();
  }

  double? get _montant => double.tryParse(_montantCtrl.text.replaceAll(' ', '').replaceAll(',', '.'));

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final url = await context.read<CreditProvider>().rechargeCredit(_montant!);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pop(context);
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!mounted) return;
        UIUtils.showInfo(context, 'Finalisez le paiement : votre Crédit sera mis à jour après confirmation.');
      } else {
        UIUtils.showError(context, 'Lien de paiement indisponible. Réessayez dans un instant.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      UIUtils.showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final montant = _montant;
    return AppSheet(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Recharger le Crédit', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            const Text('Par Mobile Money · minimum 5 000 GNF',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            TextFormField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              style: AppTheme.mono(size: 32, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -0.5),
              decoration: const InputDecoration(labelText: 'Montant', suffixText: 'GNF'),
              validator: (v) {
                final m = _montant;
                if (v == null || v.isEmpty) return 'Indiquez un montant';
                if (m == null || m <= 0) return 'Montant invalide';
                if (m < 5000) return 'Minimum 5 000 GNF';
                return null;
              },
            ),
            const SizedBox(height: 8),
            // Montants préréglés — recharge rapide.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [10000, 25000, 50000, 100000].map((m) {
                final choisi = montant == m;
                return ChoiceChip(
                  label: Text(AppCurrency.format(m.toDouble())),
                  selected: choisi,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _montantCtrl.text = m.toString()),
                  labelStyle: AppTheme.mono(size: 13, weight: FontWeight.w800, color: choisi ? AppTheme.accentDark : AppTheme.textPrimary, spacing: 0),
                  backgroundColor: AppTheme.cardBg,
                  selectedColor: AppTheme.accentLight,
                  side: BorderSide(color: choisi ? AppTheme.accent : AppTheme.divider, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                );
              }).toList(),
            ),
            if (montant != null && montant >= _kCommissionMoyenne) ...[
              const SizedBox(height: 12),
              Text('≈ ${(montant / _kCommissionMoyenne).floor()} courses couvertes',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            ],
            const SizedBox(height: 24),
            PrimaryCta(
              label: montant != null && montant > 0 ? 'Payer ${AppCurrency.format(montant)}' : 'Payer',
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
