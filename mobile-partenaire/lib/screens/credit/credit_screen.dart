import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_core/mobile_core.dart';
import '../../providers/credit_provider.dart';

/// Commission moyenne indicative — sert à afficher « ≈ N commissions couvertes ».
const double _kCommissionMoyenne = 1680;

/// Écran « Crédit » de l’expéditeur.
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
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Consumer<CreditProvider>(
          builder: (context, credit, _) {
            if (credit.isLoading && credit.transactions.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (credit.error != null && credit.solde == 0 && credit.transactions.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Impossible de charger le Crédit',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.read<CreditProvider>().loadCredit(),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }
            final solde = credit.solde;
            final nbCouvertes = (solde / _kCommissionMoyenne).floor();

            return RefreshIndicator(
              onRefresh: () => context.read<CreditProvider>().loadCredit(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Crédit',
                              style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 20),

                          // ── Carte solde — claire, mono, orange sobre ─────────
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [AppTheme.white, AppTheme.accentLight],
                              ),
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.18)),
                              boxShadow: AppTheme.shadowSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'CRÉDIT',
                                      style: AppTheme.mono(
                                        size: 11,
                                        weight: FontWeight.w700,
                                        color: AppTheme.accentDark,
                                        spacing: 1.8,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    const _TwoDots(),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  AppCurrency.format(solde),
                                  style: AppTheme.mono(
                                    size: 32,
                                    weight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                    spacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  nbCouvertes > 0
                                      ? '≈ $nbCouvertes commissions couvertes'
                                      : 'Rechargez pour créer des courses',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ── Action : Recharger (orange, seul) ────────────────
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _showRechargeSheet(context),
                              icon: const Icon(Icons.add_rounded, size: 20),
                              label: const Text('Recharger'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 26),
                          Text(
                            'MOUVEMENTS',
                            style: AppTheme.mono(
                              size: 11,
                              weight: FontWeight.w600,
                              color: AppTheme.textTertiary,
                              spacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),

                  // ── Liste des mouvements ─────────────────────────────────────
                  if (credit.transactions.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                        child: Column(
                          children: [
                            Container(
                              width: 84,
                              height: 84,
                              decoration: BoxDecoration(
                                color: AppTheme.white,
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(color: AppTheme.divider),
                              ),
                              child: Icon(Icons.receipt_long_outlined,
                                  size: 38,
                                  color: AppTheme.textTertiary.withValues(alpha: 0.7)),
                            ),
                            const SizedBox(height: 20),
                            const Text('Aucun mouvement',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.2)),
                            const SizedBox(height: 6),
                            Text(
                              'Vos recharges et les commissions de vos courses apparaîtront ici.',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  height: 1.5),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList.separated(
                        itemCount: credit.transactions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: AppTheme.divider),
                        itemBuilder: (context, i) =>
                            _CreditTile(txn: credit.transactions[i]),
                      ),
                    ),
                    if (credit.hasMore)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: credit.isLoadingMore
                              ? const Center(child: CircularProgressIndicator())
                              : TextButton(
                                  onPressed: () =>
                                      context.read<CreditProvider>().loadMore(),
                                  child: const Text('Charger plus'),
                                ),
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showRechargeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<CreditProvider>(),
        child: const _RechargeSheet(),
      ),
    );
  }
}

// ── Motif deux-points (signature du logo) ────────────────────────────────────

class _TwoDots extends StatelessWidget {
  const _TwoDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [_dot(), const SizedBox(width: 3), _dot()],
    );
  }

  Widget _dot() => Container(
        width: 4,
        height: 4,
        decoration:
            const BoxDecoration(color: AppTheme.accent, shape: BoxShape.circle),
      );
}

// ── Tuile mouvement de Crédit ────────────────────────────────────────────────

class _CreditTile extends StatelessWidget {
  final WalletTransaction txn;
  const _CreditTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isOut = txn.type == 'commission';
    final color = isOut ? AppTheme.textSecondary : AppTheme.success;
    final sign = isOut ? '−' : '+';
    final IconData icon = switch (txn.type) {
      'recharge' => Icons.arrow_downward_rounded,
      'commission' => Icons.storefront_outlined,
      'remboursement' => Icons.undo_rounded,
      'ajustement_admin' => Icons.tune_rounded,
      _ => Icons.arrow_downward_rounded,
    };
    final label = switch (txn.type) {
      'recharge' => txn.description ?? 'Recharge',
      'commission' => txn.description ?? 'Commission course',
      'remboursement' => txn.description ?? 'Remboursement',
      'ajustement_admin' => txn.description ?? 'Ajustement',
      _ => txn.description ?? txn.type,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(_formatDate(txn.createdAt),
                    style:
                        TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            '$sign ${AppCurrency.format(txn.montant)}',
            style: AppTheme.mono(
                size: 14, weight: FontWeight.w700, color: color, spacing: 0),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      return "Aujourd'hui ${dt.hour.toString().padLeft(2, '0')}h${dt.minute.toString().padLeft(2, '0')}";
    }
    if (diff.inDays == 1) return 'Hier';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

// ── Sheet de recharge ────────────────────────────────────────────────────────

class _RechargeSheet extends StatefulWidget {
  const _RechargeSheet();

  @override
  State<_RechargeSheet> createState() => _RechargeSheetState();
}

class _RechargeSheetState extends State<_RechargeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _montantCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _montantCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final montant =
        double.parse(_montantCtrl.text.replaceAll(' ', '').replaceAll(',', '.'));
    try {
      final url = await context.read<CreditProvider>().rechargeCredit(montant);
      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.pop(context);
      if (url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        if (!mounted) return;
        UIUtils.showInfo(context,
            'Finalisez le paiement — votre Crédit sera mis à jour après confirmation.');
      } else {
        UIUtils.showError(context, 'Lien de paiement indisponible');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      UIUtils.showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Recharger le Crédit',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Payez via Mobile Money. Votre Crédit couvre la commission de vos courses.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 18),
            // Montants préréglés — recharge rapide (couvre ~6 / 15 / 30 / 60 courses).
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [10000, 25000, 50000, 100000].map((montant) {
                final selected =
                    _montantCtrl.text.replaceAll(' ', '') == montant.toString();
                return GestureDetector(
                  onTap: () => setState(
                      () => _montantCtrl.text = montant.toString()),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.accentLight : AppTheme.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? AppTheme.accent : AppTheme.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      AppCurrency.format(montant.toDouble()),
                      style: AppTheme.mono(
                        size: 13,
                        weight: FontWeight.w700,
                        color: selected ? AppTheme.accentDark : AppTheme.textSecondary,
                        spacing: -0.3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Montant (GNF)',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Montant requis';
                final m =
                    double.tryParse(v.replaceAll(' ', '').replaceAll(',', '.'));
                if (m == null || m <= 0) return 'Montant invalide';
                if (m < 5000) return 'Minimum 5 000 GNF';
                return null;
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Payer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
