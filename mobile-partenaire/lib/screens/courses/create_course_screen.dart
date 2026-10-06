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
        UIUtils.showError(context, provider.error ?? 'La course n\'a pas pu être créée. Réessayez.');
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
    final String message;
    if (payeurClient) {
      message = '$nomClient a reçu un SMS de paiement. La course sera proposée aux livreurs dès qu\'il a payé, '
          'et votre commission vous sera rendue.';
    } else if (isMM) {
      message = 'Réglez ${AppCurrency.format(partLivreur)} par Mobile Money depuis le détail de la course. '
          'Elle sera proposée aux livreurs dès le paiement confirmé.';
    } else {
      message = 'Elle est proposée aux livreurs proches. Remettez ${AppCurrency.format(partLivreur)} en espèces '
          'au livreur quand il récupère le colis.';
    }
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AppSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppSheetHeader(icon: Icons.check_rounded, title: 'Course créée', message: message),
            const SizedBox(height: 24),
            PrimaryCta(label: 'Voir mes courses', onPressed: () => Navigator.pop(ctx)),
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
    final payeurClient = _payeur == 'client';
    final mobileMoney = _modePaiement == 'MOBILE_MONEY';
    final (commission, partLivreur) = _repartition;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: const Text('Nouvelle course'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // ── 1. Client ──
                    const _Titre('Votre client'),
                    AppFormField(
                      controller: _nomClientController,
                      label: 'Nom du client',
                      icon: Icons.person_outline_rounded,
                      hint: 'Ex : Aïssatou Diallo',
                      textInputAction: TextInputAction.next,
                      serverError: _nomServerError,
                      onChanged: (_) {
                        if (_nomServerError != null) setState(() => _nomServerError = null);
                      },
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Indiquez le nom du client' : null,
                    ),
                    const SizedBox(height: 12),
                    GuineaPhoneField(
                      controller: _telClientController,
                      label: 'Téléphone du client',
                      errorText: _telServerError,
                      onChanged: (_) {
                        if (_telServerError != null) setState(() => _telServerError = null);
                      },
                    ),
                    const SizedBox(height: 8),
                    const _Aide('Il recevra par SMS un lien pour indiquer sa position, puis le code de livraison.'),

                    // ── 2. Qui paie ──
                    const SizedBox(height: 32),
                    const _Titre('Qui paie la livraison ?'),
                    Row(
                      children: [
                        Expanded(
                          child: _Tuile(
                            icon: Icons.storefront_rounded,
                            label: 'Moi',
                            selected: !payeurClient,
                            onTap: () => _choisirPayeur('expediteur'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _Tuile(
                            icon: Icons.person_rounded,
                            label: 'Mon client',
                            selected: payeurClient,
                            onTap: () => _choisirPayeur('client'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (payeurClient)
                      const _Aide('Votre client paie par Mobile Money avec le lien reçu par SMS.')
                    else ...[
                      const Text('Vous réglez le livreur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textSecondary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _Tuile(
                              icon: Icons.payments_outlined,
                              label: 'En espèces',
                              selected: !mobileMoney,
                              onTap: () => _choisirMode('CASH'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Tuile(
                              icon: Icons.phone_android_rounded,
                              label: 'Mobile Money',
                              selected: mobileMoney,
                              onTap: () => _choisirMode('MOBILE_MONEY'),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── 3. Colis ──
                    const SizedBox(height: 32),
                    const _Titre('Le colis'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // 3 catégories alignées sur le backend (standard · fragile · volumineux).
                        for (final (valeur, label) in const [('standard', 'Standard'), ('fragile', 'Fragile'), ('volumineux', 'Volumineux')])
                          ChoiceChip(
                            label: Text(label),
                            selected: _natureColis == valeur,
                            showCheckmark: false,
                            onSelected: (_) {
                              setState(() => _natureColis = valeur);
                              _maybeEstimer();
                            },
                            labelStyle: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _natureColis == valeur ? AppTheme.accentDark : AppTheme.textPrimary,
                            ),
                            backgroundColor: AppTheme.cardBg,
                            selectedColor: AppTheme.accentLight,
                            side: BorderSide(color: _natureColis == valeur ? AppTheme.accent : AppTheme.divider, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          ),
                      ],
                    ),

                    // ── 4. Précisions (facultatives, repliées) ──
                    const SizedBox(height: 16),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        iconColor: AppTheme.textPrimary,
                        collapsedIconColor: AppTheme.textPrimary,
                        title: const Text('Ajouter des précisions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        subtitle: const Text('Contenu, quartier, indications — facultatif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        children: [
                          AppFormField(
                            controller: _descriptionColisController,
                            label: 'Contenu du colis',
                            icon: Icons.inventory_2_outlined,
                            hint: 'Ex : 2 plats du jour, médicaments…',
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          AppFormField(
                            controller: _adresseController,
                            label: 'Quartier',
                            icon: Icons.location_on_outlined,
                            hint: 'Ex : Almamya, près du marché',
                          ),
                          const SizedBox(height: 12),
                          AppFormField(
                            controller: _instructionsController,
                            label: 'Indications pour le livreur',
                            icon: Icons.notes_rounded,
                            hint: 'Ex : après le carrefour, portail vert',
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),

                    // ── 5. Code de livraison ──
                    Material(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                      child: SwitchListTile(
                        value: _exigeCodeLivraison,
                        onChanged: (v) => setState(() => _exigeCodeLivraison = v),
                        activeTrackColor: AppTheme.success,
                        activeThumbColor: AppTheme.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
                        title: const Text('Code de livraison', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        subtitle: const Text(
                          'Le client reçoit un code par SMS ; le livreur le lui demande à la remise. Recommandé.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.35),
                        ),
                      ),
                    ),

                    // ── 6. Ce que ça coûte ──
                    const SizedBox(height: 32),
                    const _Titre('Ce que ça coûte'),
                    _Recapitulatif(
                      prix: _prixCourant,
                      commission: commission,
                      partLivreur: partLivreur,
                      payeurClient: payeurClient,
                      mobileMoney: mobileMoney,
                      provisoire: _estimation == null,
                      estimationEnCours: _isEstimating,
                    ),
                  ],
                ),
              ),

              // ── Prix + action, toujours visibles ──
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                decoration: BoxDecoration(color: AppTheme.cardBg, boxShadow: AppTheme.shadowLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Text(
                            payeurClient
                                ? 'Payé par votre client'
                                : (_estimation == null ? 'Prix de la course · provisoire' : 'Prix de la course'),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                          ),
                        ),
                        Text(AppCurrency.format(_prixCourant),
                            style: AppTheme.mono(size: 20, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -0.3)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    PrimaryCta(
                      label: 'Créer la course',
                      loading: context.watch<CourseProvider>().isLoading,
                      onPressed: _handleSubmit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Récapitulatif : coût et répartition, avant validation ────────────────────

class _Recapitulatif extends StatelessWidget {
  final double prix;
  final double commission;
  final double partLivreur;
  final bool payeurClient;
  final bool mobileMoney;
  final bool provisoire;
  final bool estimationEnCours;

  const _Recapitulatif({
    required this.prix,
    required this.commission,
    required this.partLivreur,
    required this.payeurClient,
    required this.mobileMoney,
    required this.provisoire,
    required this.estimationEnCours,
  });

  @override
  Widget build(BuildContext context) {
    final String explication;
    if (payeurClient) {
      explication = 'Votre client paie ${AppCurrency.format(prix)} par Mobile Money. La commission est bloquée '
          'sur votre Crédit puis vous est rendue dès qu\'il a payé : la course ne vous coûte rien.';
    } else if (mobileMoney) {
      explication = 'Vous réglez ${AppCurrency.format(partLivreur)} par Mobile Money ; la commission est prise sur votre Crédit.';
    } else {
      explication = 'Vous remettez ${AppCurrency.format(partLivreur)} en espèces au livreur quand il récupère le colis ; '
          'la commission est prise sur votre Crédit.';
    }
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Ligne(label: 'Part du livreur (88 %)', valeur: AppCurrency.format(partLivreur)),
          const SizedBox(height: 8),
          _Ligne(label: 'Commission Sönaiyaa (12 %)', valeur: AppCurrency.format(commission)),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _Ligne(label: 'Prix de la course', valeur: AppCurrency.format(prix), fort: true),
          const SizedBox(height: 12),
          Text(explication, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4)),
          if (provisoire) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.accentLight, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
              child: Row(
                children: [
                  if (estimationEnCours) ...[
                    const BrandDotsPulse(color: AppTheme.accentDark),
                    const SizedBox(width: 12),
                  ],
                  const Expanded(
                    child: Text(
                      'Prix provisoire : il s\'ajuste à la distance dès que votre client partage sa position.',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentDark, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  final String label;
  final String valeur;
  final bool fort;
  const _Ligne({required this.label, required this.valeur, this.fort = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: fort ? 15 : 13, fontWeight: fort ? FontWeight.w800 : FontWeight.w600, color: fort ? AppTheme.textPrimary : AppTheme.textSecondary)),
        ),
        Text(valeur, style: AppTheme.mono(size: fort ? 20 : 15, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: 0)),
      ],
    );
  }
}

// ── Composants internes ────────────────────────────────────────────────────

class _Titre extends StatelessWidget {
  final String text;
  const _Titre(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
    );
  }
}

class _Aide extends StatelessWidget {
  final String text;
  const _Aide(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4));
  }
}

class _Tuile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Tuile({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? AppTheme.accentLight : AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(color: selected ? AppTheme.accent : AppTheme.divider, width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: selected ? AppTheme.accentDark : AppTheme.textPrimary),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: selected ? AppTheme.accentDark : AppTheme.textPrimary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
