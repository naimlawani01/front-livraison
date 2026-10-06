import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/course_provider.dart';
import 'package:mobile_core/mobile_core.dart';

class CreateCourseScreen extends StatefulWidget {
  const CreateCourseScreen({super.key});

  @override
  State<CreateCourseScreen> createState() => _CreateCourseScreenState();
}

class _CreateCourseScreenState extends State<CreateCourseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adresseController = TextEditingController();
  final _nomClientController = TextEditingController();
  final _telClientController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _descriptionColisController = TextEditingController();

  /// Prix de base (provisoire) avant partage GPS du client.
  /// Aligné sur `P_base` du modèle métier — sera ajusté par l'estimation
  /// dès que le client partage sa position GPS via le lien envoyé.
  static const double _prixDefaut = 10000;

  String _modePaiement = 'CASH';
  /// Qui règle la course : 'expediteur' (vous remettez la part livreur) ou
  /// 'client' (il paie le prix complet par Mobile Money).
  String _payeur = 'expediteur';
  double? _latClient;
  double? _lngClient;
  /// Activé par défaut : le code est envoyé au client par SMS, le livreur le
  /// lui demande à la remise (empêche les fausses livraisons).
  bool _exigeCodeLivraison = true;
  String _natureColis = 'standard';
  bool _isEstimating = false;
  Map<String, dynamic>? _estimation;

  // ── Erreurs serveur (mappées depuis 422 backend) ─────────────────────────
  String? _telServerError;
  String? _nomServerError;

  @override
  void dispose() {
    _adresseController.dispose();
    _nomClientController.dispose();
    _telClientController.dispose();
    _instructionsController.dispose();
    _descriptionColisController.dispose();
    super.dispose();
  }

  /// Prix actuellement appliqué : estimation si calculée, sinon prix de base.
  double get _prixCourant {
    final estim = _estimation?['prix_estime'];
    if (estim is num) return estim.toDouble();
    return _prixDefaut;
  }

  /// (commission Sönaiyaa 12 %, part livreur 88 %) — valeurs du backend si
  /// l'estimation est disponible, sinon calcul local sur le prix courant.
  (double, double) get _repartition {
    final c = _estimation?['commission_plateforme'];
    final l = _estimation?['montant_livreur'];
    if (c is num && l is num) return (c.toDouble(), l.toDouble());
    final commission = (_prixCourant * 0.12).roundToDouble();
    return (commission, _prixCourant - commission);
  }

  void _choisirPayeur(String payeur) {
    setState(() {
      _payeur = payeur;
      // Un client ne règle jamais en espèces : la commission ne pourrait pas
      // être récupérée (règle backend : client + cash → refusé).
      if (payeur == 'client') _modePaiement = 'MOBILE_MONEY';
    });
  }

  void _choisirMode(String mode) {
    if (mode == 'CASH' && _payeur == 'client') {
      UIUtils.showError(context, 'Si votre client paie la livraison, c\'est par Mobile Money.');
      return;
    }
    setState(() => _modePaiement = mode);
  }

  void _clearServerErrors() {
    setState(() {
      _telServerError = null;
      _nomServerError = null;
    });
  }

  Future<void> _handleSubmit() async {
    _clearServerErrors();
    if (!_formKey.currentState!.validate()) return;

    final String telClient;
    try {
      telClient = GuineaPhone.normalize(_telClientController.text);
    } on FormatException catch (e) {
      setState(() => _telServerError = e.message);
      return;
    }

    final provider = context.read<CourseProvider>();
    final adresse = _adresseController.text.trim();
    final instructions = _instructionsController.text.trim();
    final data = <String, dynamic>{
      'contact_client_nom': _nomClientController.text.trim(),
      'contact_client_telephone': telClient,
      'prix_propose': _prixCourant,
      'mode_paiement': _modePaiement,
      'payeur': _payeur,
      'exige_code_livraison': _exigeCodeLivraison,
      'nature_colis': _natureColis,
    };
    if (adresse.isNotEmpty) data['adresse_client'] = adresse;
    if (instructions.isNotEmpty) data['instructions_speciales'] = instructions;
    final descColis = _descriptionColisController.text.trim();
    if (descColis.isNotEmpty) data['description_colis'] = descColis;
    if (_latClient != null) data['latitude_client'] = _latClient;
    if (_lngClient != null) data['longitude_client'] = _lngClient;

    try {
      final success = await provider.createCourse(data);
      if (!mounted) return;
      if (success) {
        await _showSuccessSheet(context);
        if (mounted) Navigator.pop(context);
      } else {
        UIUtils.showError(context, provider.error ?? 'Erreur lors de la création');
      }
    } on ApiValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _telServerError = e.fieldErrors['contact_client_telephone'];
        _nomServerError = e.fieldErrors['contact_client_nom'];
      });
      final mapped = _telServerError != null || _nomServerError != null;
      if (!mapped) UIUtils.showError(context, e.message);
    }
  }

  Future<void> _showSuccessSheet(BuildContext context) async {
    final course = context.read<CourseProvider>().lastCreatedCourse;
    final isMM = _modePaiement == 'MOBILE_MONEY';
    final payeurClient = _payeur == 'client';
    final nomClient = _nomClientController.text.trim();
    final partLivreur = course?.montantLivreur ?? _repartition.$2;
    final String ligne1;
    final String ligne2;
    if (payeurClient) {
      ligne1 = 'Un SMS de paiement a été envoyé à $nomClient.';
      ligne2 = 'La course sera proposée aux livreurs dès que votre client a payé. '
          'Votre commission vous sera alors rendue.';
    } else if (isMM) {
      ligne1 = 'Réglez ${AppCurrency.format(partLivreur)} par Mobile Money depuis le détail de la course.';
      ligne2 = 'La course sera proposée aux livreurs dès que le paiement est confirmé.';
    } else {
      ligne1 = 'Un livreur disponible va être assigné à la course.';
      ligne2 = 'Remettez-lui ${AppCurrency.format(partLivreur)} en espèces à la récupération du colis.';
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 28),
            Container(
              width: 64, height: 64,
              decoration: const BoxDecoration(color: AppTheme.successLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppTheme.success, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('Livraison créée !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
            const SizedBox(height: 8),
            Text(
              ligne1,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              ligne2,
              style: const TextStyle(fontSize: 13, color: AppTheme.textTertiary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(_),
                child: const Text('Voir mes courses'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Déclenche l'estimation dès que les coordonnées GPS du client sont disponibles.
  Future<void> _maybeEstimer() async {
    if (_latClient == null || _lngClient == null) return;
    setState(() {
      _isEstimating = true;
      _estimation = null;
    });
    final result = await context.read<CourseProvider>().estimerPrix(
          _latClient!, _lngClient!,
          natureColis: _natureColis,
        );
    if (!mounted) return;
    setState(() {
      _estimation = result;
      _isEstimating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      appBar: AppBar(
        backgroundColor: AppTheme.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Nouvelle livraison'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              // ── Section Client ────────────────────────────────────────
              const _SectionHeader(
                title: 'Client',
                subtitle: 'Personne à livrer',
              ),
              AppFormField(
                controller: _nomClientController,
                label: 'Nom du client',
                icon: Icons.person_outline_rounded,
                hint: 'Ex : Aïssatou Diallo',
                serverError: _nomServerError,
                onChanged: (_) {
                  if (_nomServerError != null) {
                    setState(() => _nomServerError = null);
                  }
                },
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 14),
              GuineaPhoneField(
                controller: _telClientController,
                label: 'Téléphone client',
                errorText: _telServerError,
                onChanged: (_) {
                  if (_telServerError != null) {
                    setState(() => _telServerError = null);
                  }
                },
              ),

              const SizedBox(height: 32),

              // ── Section Colis ─────────────────────────────────────────
              const _SectionHeader(
                title: 'Colis',
                subtitle: 'Aide le livreur à savoir quoi récupérer',
              ),
              AppFormField(
                controller: _descriptionColisController,
                label: 'Description (optionnel)',
                icon: Icons.inventory_2_outlined,
                hint: 'Ex : 2 plats du jour, médicaments, courses…',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Type de colis'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Multiplicateurs cachés + 3 catégories alignées sur le backend
                  // (standard 1.0 · fragile 1.2 · volumineux 1.4).
                  _ColisChip(
                    label: 'Standard',
                    selected: _natureColis == 'standard',
                    onTap: () {
                      setState(() => _natureColis = 'standard');
                      _maybeEstimer();
                    },
                  ),
                  _ColisChip(
                    label: 'Fragile',
                    selected: _natureColis == 'fragile',
                    onTap: () {
                      setState(() => _natureColis = 'fragile');
                      _maybeEstimer();
                    },
                  ),
                  _ColisChip(
                    label: 'Volumineux',
                    selected: _natureColis == 'volumineux',
                    onTap: () {
                      setState(() => _natureColis = 'volumineux');
                      _maybeEstimer();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ── Section Livraison ─────────────────────────────────────
              const _SectionHeader(
                title: 'Livraison',
                subtitle: 'Adresse et instructions',
              ),
              AppFormField(
                controller: _adresseController,
                label: 'Quartier / Zone (optionnel)',
                icon: Icons.location_on_outlined,
                hint: 'Ex : Quartier Almamya, près du marché',
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              AppFormField(
                controller: _instructionsController,
                label: 'Indications (optionnel)',
                icon: Icons.notes_rounded,
                hint: 'Ex : Après le carrefour, portail vert, 2ème maison',
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.infoLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link_rounded, size: 18, color: AppTheme.info),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Après création, envoyez un lien GPS au client. Le prix s'ajustera dès qu'il partage sa position.",
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary.withValues(alpha: 0.75),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ── Section Prix ─────────────────────────────────────────
              const _SectionHeader(
                title: 'Prix de la livraison',
                subtitle: 'Calculé automatiquement, non modifiable',
              ),
              _PriceCard(
                isEstimating: _isEstimating,
                estimation: _estimation,
                prixDefaut: _prixDefaut,
                hasGps: _latClient != null,
              ),

              const SizedBox(height: 32),

              _RepartitionCard(
                commission: _repartition.$1,
                partLivreur: _repartition.$2,
                prix: _prixCourant,
                payeurClient: _payeur == 'client',
                mobileMoney: _modePaiement == 'MOBILE_MONEY',
              ),

              const SizedBox(height: 32),

              // ── Qui paie la livraison ────────────────────────────────
              const _SectionHeader(
                title: 'Qui paie la livraison ?',
                subtitle: 'Vous, ou votre client par Mobile Money',
              ),
              Row(
                children: [
                  Expanded(
                    child: _PaymentOption(
                      icon: Icons.storefront_rounded,
                      label: 'Moi',
                      selected: _payeur == 'expediteur',
                      onTap: () => _choisirPayeur('expediteur'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentOption(
                      icon: Icons.person_rounded,
                      label: 'Mon client',
                      selected: _payeur == 'client',
                      onTap: () => _choisirPayeur('client'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Section Mode de paiement ─────────────────────────────
              _SectionHeader(
                title: 'Mode de paiement',
                subtitle: _payeur == 'client'
                    ? 'Votre client reçoit un lien de paiement par SMS'
                    : 'Comment vous réglez le livreur',
              ),
              Row(
                children: [
                  Expanded(
                    child: Opacity(
                      opacity: _payeur == 'client' ? 0.4 : 1,
                      child: _PaymentOption(
                        icon: Icons.payments_outlined,
                        label: 'Espèces',
                        selected: _modePaiement == 'CASH',
                        onTap: () => _choisirMode('CASH'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _PaymentOption(
                      icon: Icons.phone_android_rounded,
                      label: 'Mobile Money',
                      selected: _modePaiement == 'MOBILE_MONEY',
                      onTap: () => _choisirMode('MOBILE_MONEY'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Option sécurité ───────────────────────────────────────
              GestureDetector(
                onTap: () => setState(() => _exigeCodeLivraison = !_exigeCodeLivraison),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _exigeCodeLivraison
                        ? AppTheme.warning.withValues(alpha: 0.08)
                        : AppTheme.background,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: _exigeCodeLivraison
                          ? AppTheme.warning.withValues(alpha: 0.4)
                          : AppTheme.divider,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22, height: 22,
                        child: Checkbox(
                          value: _exigeCodeLivraison,
                          activeColor: AppTheme.warning,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          onChanged: (val) =>
                              setState(() => _exigeCodeLivraison = val ?? false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Livraison sécurisée (code PIN)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Un code est envoyé à votre client par SMS. Le livreur le lui demande à la remise du colis. Recommandé.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Submit ────────────────────────────────────────────────
              Consumer<CourseProvider>(
                builder: (context, provider, _) {
                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _handleSubmit,
                      child: provider.isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: AppTheme.white,
                              ),
                            )
                          : const Text('Créer et diffuser'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Carte Prix (affichage seul, non modifiable) ────────────────────────────

class _PriceCard extends StatelessWidget {
  final bool isEstimating;
  final Map<String, dynamic>? estimation;
  final double prixDefaut;
  final bool hasGps;

  const _PriceCard({
    required this.isEstimating,
    required this.estimation,
    required this.prixDefaut,
    required this.hasGps,
  });

  @override
  Widget build(BuildContext context) {
    if (isEstimating) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text(
              'Calcul du prix…',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }

    if (estimation != null) {
      final prix = (estimation!['prix_estime'] as num).toDouble();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.success.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.success.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.success),
                const SizedBox(width: 8),
                const Text(
                  'Prix calculé',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
                const Spacer(),
                Text(
                  AppCurrency.format(prix),
                  style: AppTheme.mono(
                    size: 22,
                    weight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    spacing: -0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.route_rounded,
              label: 'Distance',
              value: '${estimation!["distance_km"]} km',
            ),
            const SizedBox(height: 6),
            _DetailRow(
              icon: Icons.timer_outlined,
              label: 'Durée estimée',
              value: '${estimation!["duree_estimee_minutes"]} min',
            ),
          ],
        ),
      );
    }

    // Pas encore d'estimation : prix provisoire
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.gps_not_fixed_rounded,
                size: 18,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Prix provisoire',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textTertiary,
                ),
              ),
              const Spacer(),
              Text(
                AppCurrency.format(prixDefaut),
                style: AppTheme.mono(
                  size: 22,
                  weight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  spacing: -0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Le prix final sera ajusté automatiquement selon la distance dès que le client partage sa position GPS.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepartitionCard extends StatelessWidget {
  final double commission;
  final double partLivreur;
  final double prix;
  final bool payeurClient;
  final bool mobileMoney;

  const _RepartitionCard({
    required this.commission,
    required this.partLivreur,
    required this.prix,
    required this.payeurClient,
    required this.mobileMoney,
  });

  @override
  Widget build(BuildContext context) {
    final String explication;
    if (payeurClient) {
      explication = 'Votre client paie ${AppCurrency.format(prix)} par Mobile Money. '
          'La commission est bloquée sur votre Crédit puis vous est rendue dès qu\'il a payé : '
          'la livraison ne vous coûte rien.';
    } else if (mobileMoney) {
      explication = 'Vous réglez ${AppCurrency.format(partLivreur)} par Mobile Money, '
          'plus la commission prise sur votre Crédit.';
    } else {
      explication = 'Vous remettez ${AppCurrency.format(partLivreur)} en espèces au livreur '
          'à la récupération, plus la commission prise sur votre Crédit.';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailRow(
            icon: Icons.delivery_dining_rounded,
            label: 'Part du livreur (88 %)',
            value: AppCurrency.format(partLivreur),
          ),
          const SizedBox(height: 6),
          _DetailRow(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Commission Sönaiyaa (12 %)',
            value: AppCurrency.format(commission),
          ),
          const SizedBox(height: 10),
          Text(
            explication,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textTertiary),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Composants internes ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textTertiary,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _ColisChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ColisChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppTheme.accent : AppTheme.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppTheme.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppTheme.accentLight : AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: selected ? AppTheme.accent : AppTheme.divider,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: selected ? AppTheme.accentDark : AppTheme.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppTheme.accentDark : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
