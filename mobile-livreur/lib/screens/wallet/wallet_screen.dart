import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_core/mobile_core.dart';
import '../../providers/wallet_provider.dart';

/// Écran « Mes Gains » du livreur.
///
/// Nouveau modèle : les Gains ne font que monter (courses réglées via la
/// plateforme + indemnités) et se retirent. Plus de recharge, plus de dette —
/// les courses cash sont payées en direct par l'expéditeur, hors de cet écran.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

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
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Consumer<WalletProvider>(
          builder: (context, wallet, _) {
            if (wallet.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (wallet.error != null && wallet.summary == null) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Impossible de charger vos gains',
                        style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => context.read<WalletProvider>().loadWallet(),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }
            final summary = wallet.summary;
            final solde = summary?.soldeDisponible ?? 0;
            final peutRetirer = solde >= 5000;

            return RefreshIndicator(
              onRefresh: () => context.read<WalletProvider>().loadWallet(),
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Mes Gains',
                              style: Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 20),

                          // ── Carte solde — claire, chiffres mono, orange sobre ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBg,
                              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                              border: Border.all(color: AppTheme.divider),
                              boxShadow: AppTheme.shadowSm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'GAINS À RETIRER',
                                      style: AppTheme.mono(
                                        size: 11,
                                        weight: FontWeight.w700,
                                        color: AppTheme.accentDark,
                                        spacing: 1.5,
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
                                  'Sur la plateforme · retirable',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ── Deux stats secondaires ───────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Total gagné',
                                  value: AppCurrency.format(summary?.totalGains ?? 0),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  label: 'Courses',
                                  value: '${summary?.nombreCourses ?? 0}',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── Action : Retirer (orange, seul) ──────────────────
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  peutRetirer ? () => _showRetraitSheet(context) : null,
                              icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                              label: const Text('Retirer'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusMd),
                                ),
                              ),
                            ),
                          ),
                          if (!peutRetirer) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Minimum 5 000 GNF pour un retrait',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                          ],
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
                  if (wallet.transactions.isEmpty)
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
                              'Vos gains sur les courses Mobile Money et vos retraits apparaîtront ici.',
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
                        itemCount: wallet.transactions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: AppTheme.divider),
                        itemBuilder: (context, i) =>
                            _TransactionTile(txn: wallet.transactions[i]),
                      ),
                    ),
                    if (wallet.hasMore)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: wallet.isLoadingMore
                              ? const Center(child: CircularProgressIndicator())
                              : TextButton(
                                  onPressed: () =>
                                      context.read<WalletProvider>().loadMore(),
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

  void _showRetraitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<WalletProvider>(),
        child: const _RetraitSheet(),
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

// ── Stat secondaire ──────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: AppTheme.mono(
                size: 16, weight: FontWeight.w700, color: AppTheme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
        ],
      ),
    );
  }
}

// ── Tuile mouvement ──────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  final WalletTransaction txn;
  const _TransactionTile({required this.txn});

  @override
  Widget build(BuildContext context) {
    final isIn = txn.type != 'retrait';
    final color = isIn ? AppTheme.success : AppTheme.textSecondary;
    final sign = isIn ? '+' : '−';
    final IconData icon = switch (txn.type) {
      'retrait' => Icons.arrow_upward_rounded,
      'bonus' => Icons.card_giftcard_rounded,
      'indemnite' => Icons.shield_moon_outlined,
      _ => Icons.arrow_downward_rounded,
    };
    final label = switch (txn.type) {
      'credit' => txn.description ?? 'Course',
      'retrait' => txn.description ?? 'Retrait',
      'bonus' => txn.description ?? 'Bonus',
      'indemnite' => txn.description ?? 'Indemnité',
      _ => txn.description ?? txn.type,
    };
    final statutColor = switch (txn.statut) {
      'en_attente' || 'en_cours' => AppTheme.warning,
      'refuse' => AppTheme.error,
      _ => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isIn ? AppTheme.success : AppTheme.textSecondary)
                  .withValues(alpha: 0.10),
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
                Row(
                  children: [
                    Text(_formatDate(txn.createdAt),
                        style: TextStyle(
                            color: AppTheme.textTertiary, fontSize: 12)),
                    if (statutColor != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: statutColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          txn.statut == 'refuse' ? 'Refusé' : 'En cours',
                          style: TextStyle(
                              color: statutColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
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

// ── Sheet de retrait ─────────────────────────────────────────────────────────

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
    ('mtn_money', 'MTN Money'),
  ];

  @override
  void dispose() {
    _montantCtrl.dispose();
    _numCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
    final montant =
        double.parse(_montantCtrl.text.replaceAll(' ', '').replaceAll(',', '.'));
    try {
      final error = await context.read<WalletProvider>().demanderRetrait(
            montant: montant,
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
    final wallet = context.watch<WalletProvider>();
    final solde = wallet.summary?.soldeDisponible ?? 0;

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
            Text('Retirer mes gains',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Disponible : ${AppCurrency.format(solde)}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            AppFormField(
              controller: _montantCtrl,
              label: 'Montant (GNF)',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              serverError: _montantServerError,
              onChanged: (_) {
                if (_montantServerError != null) {
                  setState(() => _montantServerError = null);
                }
              },
              validator: (v) {
                if (v == null || v.isEmpty) return 'Montant requis';
                final m =
                    double.tryParse(v.replaceAll(' ', '').replaceAll(',', '.'));
                if (m == null || m <= 0) return 'Montant invalide';
                if (m < 5000) return 'Minimum 5 000 GNF';
                if (m > solde) return 'Gains insuffisants';
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _methode,
              decoration: const InputDecoration(
                labelText: 'Méthode',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: _methodes
                  .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
                  .toList(),
              onChanged: (v) => setState(() => _methode = v ?? _methode),
            ),
            const SizedBox(height: 14),
            GuineaPhoneField(
              controller: _numCtrl,
              label: 'Numéro Mobile Money',
              errorText: _numeroServerError,
              onChanged: (_) {
                if (_numeroServerError != null) {
                  setState(() => _numeroServerError = null);
                }
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
                    : const Text('Confirmer le retrait'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
