import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_core/mobile_core.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
import '../../providers/credit_provider.dart';
import '../../widgets/livreur_map_widget.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  late Course _course;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _course = widget.course;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());

    // Auto-refresh toutes les 10s quand la course est en cours
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isActive) _refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool get _isActive => !_course.isFinie;

  Future<void> _refresh() async {
    final provider = context.read<CourseProvider>();
    await provider.loadCourseDetails(_course.id);
    if (provider.selectedCourse != null && mounted) {
      setState(() => _course = provider.selectedCourse!);
    }
  }

  /// Action principale de l'écran (en bas), selon l'état du paiement.
  (String, VoidCallback)? get _actionPrincipale {
    final enAttente = _course.status.toUpperCase() == 'CREEE';
    if (enAttente && !_course.isPayeurClient && _course.isMobileMoney && !_course.isPaiementConfirme) {
      return ('Payer ${AppCurrency.format(_course.montantAEncaisser ?? _course.montantLivreur)}', _payer);
    }
    if (enAttente && !_course.isMobileMoney && _course.isLocationShared) {
      return ('Relancer la course', _relancerCourse);
    }
    if (_course.isRetour) {
      return ('J\'ai récupéré le colis', _confirmerRetour);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final action = _actionPrincipale;
    final numero = _course.numeroCourse.length > 8
        ? _course.numeroCourse.substring(_course.numeroCourse.length - 8).toUpperCase()
        : _course.numeroCourse.toUpperCase();
    final etapes = <(String, DateTime?)>[
      ('Créée', _course.createdAt),
      ('Proposée aux livreurs', _course.diffuseeAt),
      ('Acceptée par un livreur', _course.accepteeAt),
      ('Colis récupéré', _course.recupereeAt),
      ('Livrée au client', _course.livreeAt),
      ('Livraison impossible${_course.echecLivraisonLabel != null ? ' · ${_course.echecLivraisonLabel}' : ''}', _course.echecLivraisonAt),
      ('Colis rendu', _course.retourneeAt),
    ].where((e) => e.$2 != null).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        title: Text('Course $numero'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppTheme.accent,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // ── Statut + frise ──
                    _Carte(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(_course.statusLabel, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          const SizedBox(height: 4),
                          Text(_statusDescription, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4)),
                          const SizedBox(height: 20),
                          CourseFrise(status: _course.status, expediteurLabel: 'Vous'),
                          if (_course.exigeCodeLivraison && _course.codeLivraison != null && _isActive) ...[
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                              child: Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Code de livraison\nenvoyé à votre client par SMS',
                                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4),
                                    ),
                                  ),
                                  SelectableText(
                                    _course.codeLivraison!,
                                    style: AppTheme.mono(size: 32, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: 6),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Livreur ──
                    if (_course.livreurId != null) ...[
                      const SizedBox(height: 12),
                      _Carte(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                UserAvatar(name: _course.livreurNom, size: 48),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_course.livreurNom ?? 'Livreur',
                                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                                      const SizedBox(height: 2),
                                      Text(
                                        [
                                          _livreurStatusText,
                                          if (_course.livreurVehicule != null) _course.livreurVehicule!,
                                          if (_course.livreurNote != null) '★ ${_course.livreurNote!.toStringAsFixed(1)}',
                                        ].join(' · '),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (_course.livreurTelephone != null && _isActive) ...[
                              const SizedBox(height: 16),
                              SecondaryButton(
                                label: 'Appeler le livreur',
                                icon: Icons.phone_rounded,
                                onPressed: () async {
                                  final uri = Uri(scheme: 'tel', path: _course.livreurTelephone);
                                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],

                    // ── Carte temps réel ──
                    if (_course.livreurId != null && _hasLivreurTrackingStatus) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        child: Builder(
                          builder: (context) {
                            final expediteur = context.read<AuthProvider>().expediteur;
                            return LivreurMapWidget(
                              expediteurLat: expediteur?.latitude,
                              expediteurLng: expediteur?.longitude,
                              livreurLat: _course.livreurLatitude,
                              livreurLng: _course.livreurLongitude,
                              clientLat: _course.latitudeClient,
                              clientLng: _course.longitudeClient,
                            );
                          },
                        ),
                      ),
                    ],

                    // ── Paiement ──
                    const SizedBox(height: 24),
                    const _Titre('Paiement'),
                    _Carte(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(_course.modePaiementLabel,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                              ),
                              Text(
                                _course.isPaiementConfirme ? 'Confirmé' : 'En attente',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: _course.isPaiementConfirme ? AppTheme.successDark : AppTheme.warningDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(_explicationPaiement, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4)),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          _ligneMontant('Part du livreur (88 %)', _course.montantLivreur),
                          const SizedBox(height: 8),
                          _ligneMontant('Commission Sönaiyaa (12 %)', _course.commissionPlateforme),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _course.distanceKm != null
                                      ? 'Prix de la course · ${_course.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km'
                                      : 'Prix de la course',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                ),
                              ),
                              Text(AppCurrency.format(_course.prixPropose),
                                  style: AppTheme.mono(size: 20, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -0.3)),
                            ],
                          ),
                          if (_course.isRetour || _course.fraisRetour != null) ...[
                            const SizedBox(height: 12),
                            _ligneMontant(
                              _course.fraisRetour != null ? 'Frais de retour au livreur (50 %)' : 'Frais de retour à verser (50 %)',
                              _course.fraisRetourEstimes,
                            ),
                          ],
                          ..._messagesPaiement(),
                        ],
                      ),
                    ),

                    // ── Client ──
                    const SizedBox(height: 24),
                    const _Titre('Client'),
                    _Carte(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _InfoTile(icon: Icons.person_outline_rounded, label: 'Nom', value: _course.contactClientNom),
                          _InfoTile(icon: Icons.phone_outlined, label: 'Téléphone', value: GuineaPhone.formatPretty(_course.contactClientTelephone)),
                          if (_course.adresseClient != null && _course.adresseClient!.isNotEmpty)
                            _InfoTile(icon: Icons.location_on_outlined, label: 'Adresse', value: _course.adresseClient!),
                          if (_course.instructionsSpeciales != null && _course.instructionsSpeciales!.isNotEmpty)
                            _InfoTile(icon: Icons.notes_rounded, label: 'Indications', value: _course.instructionsSpeciales!),
                          if (_course.descriptionColis != null && _course.descriptionColis!.isNotEmpty)
                            _InfoTile(icon: Icons.inventory_2_outlined, label: 'Colis', value: _course.descriptionColis!),
                          const SizedBox(height: 4),
                          _LocationWidget(course: _course, onRefresh: _refresh),
                        ],
                      ),
                    ),

                    // ── Historique horodaté ──
                    const SizedBox(height: 24),
                    const _Titre('Historique'),
                    _Carte(
                      child: Column(
                        children: [
                          for (var i = 0; i < etapes.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
                                  child: const Icon(Icons.check_rounded, size: 14, color: AppTheme.white),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(etapes[i].$1, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary))),
                                Text(_fmt(etapes[i].$2!), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    // ── Évaluation ──
                    if (_isDone && _course.noteLivreur == null && _course.livreurId != null) ...[
                      const SizedBox(height: 24),
                      _EvaluerSection(courseId: _course.id, onEvaluated: _refresh),
                    ],
                    if (_course.noteLivreur != null) ...[
                      const SizedBox(height: 24),
                      _Carte(
                        child: Text(
                          'Livreur évalué : ${_course.noteLivreur}/5'
                          '${_course.commentaireLivreur != null && _course.commentaireLivreur!.isNotEmpty ? ' · « ${_course.commentaireLivreur} »' : ''}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],

                    // ── Annulation ──
                    if (_course.status.toUpperCase() == 'EN_LIVRAISON') ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Le colis a été récupéré : pour annuler, contactez le support Sönaiyaa.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.4),
                      ),
                    ] else if (_isActive && !_course.isRetour) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _showCancelDialog,
                        style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                        child: const Text('Annuler la course'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (action != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: PrimaryCta(label: action.$1, onPressed: action.$2),
              ),
          ],
        ),
      ),
    );
  }

  /// Messages complémentaires sous le paiement (crédit insuffisant, remboursement).
  List<Widget> _messagesPaiement() {
    final enAttente = _course.status.toUpperCase() == 'CREEE';
    final messages = <String>[
      if (enAttente && !_course.isMobileMoney && _course.isLocationShared)
        'Course en attente : si votre Crédit était insuffisant, rechargez-le puis relancez la course.',
      if (_course.isRetour)
        'À la réception du colis, ${AppCurrency.format(_course.fraisRetourEstimes)} de frais de retour sont pris sur votre Crédit et versés au livreur.',
      if (_course.fraisRetourRestant > 0)
        'Crédit insuffisant : ${AppCurrency.format(_course.fraisRetourRestant)} de frais de retour restent dus. Rechargez votre Crédit pour créer de nouvelles courses.',
      if (_course.remboursementDu != null)
        'Remboursement de ${AppCurrency.format(_course.remboursementDu!)} dû à votre client : il est traité par Sönaiyaa.',
    ];
    return [
      for (final m in messages) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AppTheme.accentLight, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
          child: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentDark, height: 1.4)),
        ),
      ],
    ];
  }

  void _showCancelDialog() {
    final raisonCtrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AppSheet(
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSheetHeader(
                icon: Icons.cancel_outlined,
                title: 'Annuler la course ?',
                message: _livreurEnRoute
                    ? 'Un livreur est déjà en route : une indemnité de déplacement de 3 000 GNF lui sera versée depuis votre Crédit.'
                    : 'La commission bloquée sur votre Crédit vous sera rendue.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: raisonCtrl,
                maxLines: 2,
                onChanged: (_) => setSheet(() {}),
                decoration: const InputDecoration(hintText: 'Raison de l\'annulation'),
              ),
              const SizedBox(height: 16),
              PrimaryCta(
                label: 'Annuler la course',
                onPressed: raisonCtrl.text.trim().isEmpty
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        final provider = context.read<CourseProvider>();
                        final ok = await provider.cancelCourse(_course.id, raisonCtrl.text.trim());
                        if (ok && mounted) {
                          UIUtils.showSuccess(context, 'Course annulée');
                          await _refresh();
                        } else if (mounted) {
                          UIUtils.showError(context, provider.error ?? 'L\'annulation a échoué. Réessayez.');
                        }
                      },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(foregroundColor: AppTheme.textSecondary),
                child: const Text('Garder la course'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──
  bool get _isDone => _course.status.toUpperCase() == 'TERMINEE';

  bool get _livreurEnRoute {
    final s = _course.status.toUpperCase();
    return s == 'ACCEPTEE' || s == 'EN_RECUPERATION';
  }

  String get _explicationPaiement {
    if (_course.isPayeurClient) {
      return 'Votre client paie ${AppCurrency.format(_course.prixPropose)} par Mobile Money';
    }
    if (_course.isMobileMoney) {
      return 'Vous réglez ${AppCurrency.format(_course.montantLivreur)} par Mobile Money';
    }
    return 'Vous remettez ${AppCurrency.format(_course.montantLivreur)} en espèces au livreur';
  }

  Widget _ligneMontant(String label, double montant) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary))),
        Text(
          AppCurrency.format(montant),
          style: AppTheme.mono(size: 15, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: 0),
        ),
      ],
    );
  }

  Future<void> _payer() async {
    var url = _course.geniuspayCheckoutUrl;
    try {
      url ??= await context.read<CourseProvider>().relancerPaiement(_course.id);
    } catch (e) {
      if (mounted) UIUtils.showError(context, e.toString().replaceFirst('Exception: ', ''));
      return;
    }
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _confirmerRetour() async {
    final ok = await showConfirmAction(
      context,
      icon: Icons.assignment_return_outlined,
      title: 'Colis récupéré ?',
      message: 'Confirmez seulement si vous avez le colis en main. '
          '${AppCurrency.format(_course.fraisRetourEstimes)} de frais de retour seront versés au livreur depuis votre Crédit.',
      confirmLabel: 'Oui, je l\'ai récupéré',
    );
    if (!ok || !mounted) return;
    try {
      final c = await ApiService().confirmerRetourRecu(_course.id);
      if (!mounted) return;
      setState(() => _course = c);
      context.read<CreditProvider>().loadCredit();
      context.read<CourseProvider>().loadCourses();
      UIUtils.showSuccess(context, c.fraisRetourRestant > 0
          ? 'Colis récupéré. Rechargez votre Crédit pour régler les frais de retour.'
          : 'Colis récupéré');
    } catch (e) {
      if (mounted) UIUtils.showError(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _relancerCourse() async {
    final erreur = await context.read<CourseProvider>().rediffuserCourse(_course.id);
    if (!mounted) return;
    if (erreur == null) {
      UIUtils.showSuccess(context, 'Course relancée : recherche d\'un livreur');
      await _refresh();
    } else {
      UIUtils.showError(context, erreur);
    }
  }

  bool get _hasLivreurTrackingStatus {
    final s = _course.status.toUpperCase();
    return s == 'ACCEPTEE' || s == 'EN_RECUPERATION' || s == 'EN_LIVRAISON' || s == 'RETOUR';
  }

  String get _statusDescription {
    switch (_course.status.toUpperCase()) {
      case 'CREEE': return 'La course va être diffusée aux livreurs';
      case 'DIFFUSEE': return 'En attente d\'un livreur à proximité';
      case 'ACCEPTEE': return 'Le livreur est en route vers le point de retrait';
      case 'EN_RECUPERATION': return 'Le livreur est arrivé : remettez-lui le colis';
      case 'EN_LIVRAISON': return 'Le livreur a le colis et livre votre client';
      case 'TERMINEE': return 'Votre client a reçu son colis.';
      case 'ANNULEE': return 'Cette course a été annulée';
      case 'RETOUR': return '${_course.echecLivraisonLabel ?? 'Livraison impossible'} : le livreur vous rapporte le colis. Confirmez dès que vous l\'avez récupéré.';
      case 'RETOURNEE': return 'Le colis vous a été rendu. Contactez votre client pour une nouvelle livraison.';
      default: return '';
    }
  }

  String get _livreurStatusText {
    switch (_course.status.toUpperCase()) {
      case 'ACCEPTEE': return 'En route vers le point de retrait';
      case 'EN_RECUPERATION': return 'Arrivé, attend le colis';
      case 'EN_LIVRAISON': return 'En livraison vers le client';
      case 'TERMINEE': return 'Livraison terminée';
      case 'RETOUR': return 'Vous rapporte le colis';
      default: return 'Assigné';
    }
  }

  String _fmt(DateTime dt) => DateFormatter.dateTime(dt);
}

// ── Section évaluation livreur ──
class _EvaluerSection extends StatefulWidget {
  final String courseId;
  final VoidCallback onEvaluated;
  const _EvaluerSection({required this.courseId, required this.onEvaluated});

  @override
  State<_EvaluerSection> createState() => _EvaluerSectionState();
}

class _EvaluerSectionState extends State<_EvaluerSection> {
  int _note = 0;
  final _commentCtrl = TextEditingController();

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  bool _envoi = false;

  @override
  Widget build(BuildContext context) {
    return _Carte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Évaluer le livreur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 4),
          const Text('Comment s\'est passée la livraison ?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return IconButton(
                onPressed: () => setState(() => _note = i + 1),
                tooltip: '${i + 1} sur 5',
                iconSize: 36,
                constraints: const BoxConstraints.tightFor(width: 56, height: 56),
                icon: Icon(
                  i < _note ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: i < _note ? AppTheme.accent : AppTheme.textSecondary,
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(hintText: 'Un commentaire ? (facultatif)'),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: _envoi ? 'Envoi…' : 'Envoyer l\'évaluation',
            onPressed: _note == 0 || _envoi
                ? null
                : () async {
                    setState(() => _envoi = true);
                    final provider = context.read<CourseProvider>();
                    final ok = await provider.evaluerLivreur(
                      widget.courseId,
                      _note,
                      _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
                    );
                    if (!context.mounted) return;
                    setState(() => _envoi = false);
                    if (ok) {
                      UIUtils.showSuccess(context, 'Merci pour votre évaluation');
                      widget.onEvaluated();
                    } else {
                      UIUtils.showError(context, 'L\'évaluation n\'a pas pu être envoyée. Réessayez.');
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _Carte extends StatelessWidget {
  final Widget child;
  const _Carte({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowMd,
      ),
      child: child,
    );
  }
}

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

// ── INFO TILE ──
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 1),
                SelectableText(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── LOCATION WIDGET ──
class _LocationWidget extends StatefulWidget {
  final Course course;
  final VoidCallback onRefresh;
  const _LocationWidget({required this.course, required this.onRefresh});

  @override
  State<_LocationWidget> createState() => _LocationWidgetState();
}

class _LocationWidgetState extends State<_LocationWidget> {
  bool _generating = false;
  String? _locationLink;

  @override
  void initState() {
    super.initState();
    if (widget.course.locationToken != null) {
      _locationLink = '${AppConstants.baseUrl}/loc/${widget.course.locationToken}';
    }
  }

  Future<void> _generateLink() async {
    setState(() => _generating = true);
    try {
      final api = ApiService();
      final result = await api.generateLocationLink(widget.course.id);
      final token = result['location_token'];
      setState(() {
        _locationLink = '${AppConstants.baseUrl}/loc/$token';
      });
    } catch (e) {
      if (mounted) {
        UIUtils.showError(context, 'Le lien n\'a pas pu être créé. Vérifiez votre connexion puis réessayez.');
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _copyLink() {
    if (_locationLink == null) return;
    Clipboard.setData(ClipboardData(text: _locationLink!));
    UIUtils.showSuccess(context, 'Lien copié — collez-le dans WhatsApp ou SMS');
  }

  Future<void> _shareViaWhatsApp() async {
    if (_locationLink == null) return;
    final phone = widget.course.contactClientTelephone;
    final text = Uri.encodeComponent(
      'Bonjour ${widget.course.contactClientNom}, '
      'veuillez partager votre position pour la livraison en cliquant sur ce lien :\n$_locationLink'
    );
    final whatsappUrl = Uri.parse('https://wa.me/$phone?text=$text');
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
    } else {
      _copyLink();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.course.isLocationShared) {
      return const _Bandeau(
        icon: Icons.check_circle_rounded,
        texte: 'Position GPS du client reçue',
        couleur: AppTheme.successDark,
        fond: AppTheme.successLight,
      );
    }

    if (_locationLink != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Bandeau(
            icon: Icons.hourglass_top_rounded,
            texte: 'En attente de la position du client',
            couleur: AppTheme.warningDark,
            fond: AppTheme.warningLight,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: 'WhatsApp', icon: Icons.chat_rounded, onPressed: _shareViaWhatsApp)),
              const SizedBox(width: 8),
              Expanded(child: SecondaryButton(label: 'Copier le lien', icon: Icons.copy_rounded, onPressed: _copyLink)),
            ],
          ),
        ],
      );
    }

    return SecondaryButton(
      label: _generating ? 'Création du lien…' : 'Envoyer un lien de localisation',
      icon: Icons.link_rounded,
      onPressed: _generating ? null : _generateLink,
    );
  }
}

class _Bandeau extends StatelessWidget {
  final IconData icon;
  final String texte;
  final Color couleur;
  final Color fond;
  const _Bandeau({required this.icon, required this.texte, required this.couleur, required this.fond});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: fond, borderRadius: BorderRadius.circular(AppTheme.radiusSm)),
      child: Row(
        children: [
          Icon(icon, color: couleur, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(texte, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: couleur))),
        ],
      ),
    );
  }
}
