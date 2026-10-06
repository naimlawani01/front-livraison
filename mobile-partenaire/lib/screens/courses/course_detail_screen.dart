import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobile_core/mobile_core.dart';
import '../../providers/auth_provider.dart';
import '../../providers/course_provider.dart';
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

  bool get _isActive {
    final s = _course.status.toUpperCase();
    return s != 'TERMINEE' && s != 'ANNULEE';
  }

  Future<void> _refresh() async {
    final provider = context.read<CourseProvider>();
    await provider.loadCourseDetails(_course.id);
    if (provider.selectedCourse != null && mounted) {
      setState(() => _course = provider.selectedCourse!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppTheme.black,
          child: CustomScrollView(
            slivers: [
              // ── Header ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          'COURSE ${_course.numeroCourse.substring(_course.numeroCourse.length - 8).toUpperCase()}', 
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: AppTheme.textSecondary)
                        ),
                      ),
                      _StatusBadge(label: _course.statusLabel.toUpperCase(), color: _statusColor),
                    ],
                  ),
                ),
              ),

              // ── Status Hero ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _isActive
                          ? AppTheme.black
                          : (_isDone
                              ? AppTheme.success
                              : (_course.status.toUpperCase() == 'ANNULEE'
                                  ? AppTheme.error
                                  : AppTheme.background)),
                      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.white.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_statusIcon, color: AppTheme.white, size: 28),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _course.statusLabel,
                          style: const TextStyle(
                            color: AppTheme.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _statusDescription,
                          style: TextStyle(
                            color: AppTheme.white.withOpacity(0.75),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_isActive) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _PulseDot(size: 6, color: AppTheme.white),
                                const SizedBox(width: 6),
                                const Text(
                                  'Suivi en temps réel',
                                  style: TextStyle(
                                    color: AppTheme.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_course.exigeCodeLivraison && _course.codeLivraison != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'CODE DE SÉCURITÉ',
                                  style: TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _course.codeLivraison!,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 8,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'À transmettre au client',
                                  style: TextStyle(
                                    color: AppTheme.textTertiary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // ── Carte livreur (visible si un livreur est assigné) ──
              if (_course.livreurId != null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.white,
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                        boxShadow: AppTheme.shadowMd,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              // Avatar livreur
                              Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  color: AppTheme.black,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.delivery_dining_rounded, color: AppTheme.white, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _course.livreurNom ?? 'Livreur assigné',
                                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _livreurStatusText.toUpperCase(),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: _statusColor, letterSpacing: 0.5),
                                    ),
                                  ],
                                ),
                              ),
                              if (_course.livreurNote != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warning.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded, size: 16, color: AppTheme.warning),
                                      const SizedBox(width: 4),
                                      Text(
                                        _course.livreurNote!.toStringAsFixed(1),
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.warning),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (_course.livreurVehicule != null || _course.livreurCoursesCompletees != null) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                if (_course.livreurVehicule != null) ...[
                                  _MiniInfo(icon: Icons.two_wheeler_rounded, label: _course.livreurVehicule!),
                                  const SizedBox(width: 16),
                                ],
                                if (_course.livreurCoursesCompletees != null) ...[
                                  _MiniInfo(icon: Icons.check_circle_outline_rounded, label: '${_course.livreurCoursesCompletees} courses'),
                                ],
                              ],
                            ),
                          ],
                          if (_course.livreurTelephone != null && _isActive) ...[
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final uri = Uri(scheme: 'tel', path: _course.livreurTelephone);
                                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                                },
                                icon: const Icon(Icons.phone_rounded, size: 18),
                                label: const Text('APPELER LE LIVREUR'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.success,
                                  foregroundColor: AppTheme.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              // ── Carte temps réel du livreur ──
              if (_course.livreurId != null && _hasLivreurTrackingStatus) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.map_rounded, size: 18, color: AppTheme.textSecondary),
                            const SizedBox(width: 6),
                            Text('Suivi en temps réel', style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Builder(
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
                      ],
                    ),
                  ),
                ),
              ],

              // ── Timeline / Progression ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progression', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 16),
                      _Step(
                        label: 'Course créée',
                        time: _fmt(_course.createdAt),
                        done: true,
                        idx: 0,
                        current: _statusIndex,
                      ),
                      _Step(
                        label: 'Diffusée aux livreurs',
                        time: _course.diffuseeAt != null ? _fmt(_course.diffuseeAt!) : null,
                        done: _statusIndex >= 1,
                        idx: 1,
                        current: _statusIndex,
                      ),
                      _Step(
                        label: 'Acceptée par un livreur',
                        time: _course.accepteeAt != null ? _fmt(_course.accepteeAt!) : null,
                        done: _statusIndex >= 2,
                        idx: 2,
                        current: _statusIndex,
                      ),
                      _Step(
                        label: 'Le livreur est arrivé au point de retrait',
                        time: _course.recupereeAt != null ? _fmt(_course.recupereeAt!) : null,
                        done: _statusIndex >= 3,
                        idx: 3,
                        current: _statusIndex,
                      ),
                      _Step(
                        label: 'Course récupérée — en livraison',
                        done: _statusIndex >= 4,
                        idx: 4,
                        current: _statusIndex,
                      ),
                      _Step(
                        label: 'Livrée au client',
                        time: _course.livreeAt != null ? _fmt(_course.livreeAt!) : null,
                        done: _statusIndex >= 5,
                        idx: 5,
                        current: _statusIndex,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Divider ──
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Divider())),

              // ── Infos client ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Client', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _InfoTile(icon: Icons.person_outline_rounded, label: 'Nom', value: _course.contactClientNom),
                      _InfoTile(icon: Icons.phone_outlined, label: 'Téléphone', value: GuineaPhone.formatPretty(_course.contactClientTelephone)),
                      if (_course.adresseClient != null && _course.adresseClient!.isNotEmpty)
                        _InfoTile(icon: Icons.location_on_outlined, label: 'Adresse', value: _course.adresseClient!),
                      if (_course.instructionsSpeciales != null && _course.instructionsSpeciales!.isNotEmpty)
                        _InfoTile(icon: Icons.notes_rounded, label: 'Instructions', value: _course.instructionsSpeciales!),
                      if (_course.descriptionColis != null && _course.descriptionColis!.isNotEmpty)
                        _InfoTile(icon: Icons.inventory_2_outlined, label: 'Colis / course', value: _course.descriptionColis!),

                      // Localisation GPS du client (partage via WhatsApp si besoin)
                      const SizedBox(height: 12),
                      _LocationWidget(course: _course, onRefresh: _refresh),

                      // Note : le lien de suivi est envoyé automatiquement au
                      // client par SMS dès la création de la course.
                      // Plus de bouton manuel ici.
                    ],
                  ),
                ),
              ),

              // ── Divider ──
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Divider())),

              // ── Mode de paiement ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Paiement', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _course.modePaiement == 'CASH'
                                    ? AppTheme.success.withOpacity(0.1)
                                    : AppTheme.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _course.modePaiement == 'CASH'
                                    ? Icons.payments_outlined
                                    : Icons.phone_android_rounded,
                                size: 20,
                                color: _course.modePaiement == 'CASH'
                                    ? AppTheme.success
                                    : AppTheme.info,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _course.modePaiementLabel,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _explicationPaiement,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _course.paiementConfirme == 'oui'
                                    ? AppTheme.successLight
                                    : AppTheme.warningLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _course.paiementConfirme == 'oui'
                                        ? Icons.check_circle_rounded
                                        : Icons.schedule_rounded,
                                    size: 14,
                                    color: _course.paiementConfirme == 'oui'
                                        ? AppTheme.success
                                        : AppTheme.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _course.paiementConfirme == 'oui'
                                        ? 'Confirmé'
                                        : 'En attente',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _course.paiementConfirme == 'oui'
                                          ? AppTheme.success
                                          : AppTheme.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Actions liées au paiement (payer, relancer, remboursement) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _actionsPaiement(context),
                ),
              ),

              // ── Divider ──
              const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Divider())),

              // ── Prix de la livraison ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Prix de la livraison', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(color: AppTheme.divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: AppTheme.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.local_shipping_outlined,
                                color: AppTheme.textPrimary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Frais de livraison',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  if (_course.distanceKm != null)
                                    Text(
                                      '${_course.distanceKm!.toStringAsFixed(1)} km · ~${_course.dureeEstimeeMinutes ?? 0} min',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textTertiary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              AppCurrency.format(_course.prixPropose),
                              style: AppTheme.mono(
                                size: 18,
                                weight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                spacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ligneMontant('Part du livreur (88 %)', _course.montantLivreur),
                      const SizedBox(height: 4),
                      _ligneMontant('Commission Sönaiyaa (12 %)', _course.commissionPlateforme),
                    ],
                  ),
                ),
              ),

              // ── Évaluation du livreur (si terminée et pas encore évaluée) ──
              if (_isDone && _course.noteLivreur == null && _course.livreurId != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: _EvaluerSection(
                      courseId: _course.id,
                      onEvaluated: _refresh,
                    ),
                  ),
                ),

              // ── Évaluation déjà faite ──
              if (_course.noteLivreur != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.warningLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppTheme.warning, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Livreur évalué : ${_course.noteLivreur}/5',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          if (_course.commentaireLivreur != null && _course.commentaireLivreur!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '« ${_course.commentaireLivreur} »',
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Colis en main : annulation via le support uniquement ──
              if (_course.status.toUpperCase() == 'EN_LIVRAISON')
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Text(
                      'Le colis a été récupéré : pour annuler, contactez le support Sönaiyaa.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              // ── Bouton annuler la course ──
              if (_isActive && _course.status.toUpperCase() != 'EN_LIVRAISON')
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: () => _showCancelDialog(),
                        icon: const Icon(Icons.cancel_outlined, size: 18, color: AppTheme.error),
                        label: const Text(
                          'Annuler cette course',
                          style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppTheme.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                        ),
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelDialog() {
    final raisonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Annuler la course'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_livreurEnRoute) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Un livreur est déjà en route : une indemnité de déplacement de '
                    '3 000 GNF lui sera versée depuis votre Crédit.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                'Veuillez indiquer la raison de l\'annulation :',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: raisonCtrl,
                decoration: const InputDecoration(
                  hintText: 'Raison de l\'annulation',
                ),
                maxLines: 3,
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Retour'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
              ),
              onPressed: () async {
                final raison = raisonCtrl.text.trim();
                if (raison.isEmpty) return;
                Navigator.pop(ctx);
                final provider = context.read<CourseProvider>();
                final ok = await provider.cancelCourse(_course.id, raison);
                if (ok && mounted) {
                  UIUtils.showSuccess(context, 'Course annulée avec succès');
                  await _refresh();
                } else if (mounted) {
                  UIUtils.showError(context, provider.error ?? 'Erreur lors de l\'annulation');
                }
              },
              child: const Text('Confirmer l\'annulation'),
            ),
          ],
        );
      },
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
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        const Spacer(),
        Text(
          AppCurrency.format(montant),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
      ],
    );
  }

  Widget _actionsPaiement(BuildContext context) {
    final enAttente = _course.status.toUpperCase() == 'CREEE';
    final children = <Widget>[];

    // Mobile Money réglé par l'expéditeur : bouton « Payer ».
    if (enAttente && !_course.isPayeurClient && _course.isMobileMoney && !_course.isPaiementConfirme) {
      children.add(SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _payer,
          icon: const Icon(Icons.phone_android_rounded, size: 18),
          label: Text('Payer ${AppCurrency.format(_course.montantAEncaisser ?? _course.montantLivreur)}'),
        ),
      ));
    }

    // Course cash en attente (ex. Crédit insuffisant après le partage GPS).
    if (enAttente && !_course.isMobileMoney && _course.isLocationShared) {
      children.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Course en attente : si votre Crédit était insuffisant, rechargez-le puis relancez la course.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _relancerCourse,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Relancer la course'),
            ),
          ),
        ],
      ));
    }

    // Remboursement dû au client (course payée puis annulée).
    if (_course.remboursementDu != null) {
      children.add(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Text(
          'Remboursement de ${AppCurrency.format(_course.remboursementDu!)} dû à votre client : '
          'il est traité par Sönaiyaa.',
          style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.4),
        ),
      ));
    }

    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final w in children) ...[w, const SizedBox(height: 8)],
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
    return s == 'ACCEPTEE' || s == 'EN_RECUPERATION' || s == 'EN_LIVRAISON';
  }

  Color get _statusColor {
    switch (_course.status.toUpperCase()) {
      case 'CREEE': return AppTheme.textSecondary;
      case 'DIFFUSEE': return AppTheme.info;
      case 'ACCEPTEE': return AppTheme.accent;
      case 'EN_RECUPERATION': return AppTheme.warning;
      case 'EN_LIVRAISON': return AppTheme.accent;
      case 'TERMINEE': return AppTheme.success;
      case 'ANNULEE': return AppTheme.error;
      default: return AppTheme.textTertiary;
    }
  }

  IconData get _statusIcon {
    switch (_course.status.toUpperCase()) {
      case 'CREEE': return Icons.edit_note_rounded;
      case 'DIFFUSEE': return Icons.wifi_tethering_rounded;
      case 'ACCEPTEE': return Icons.directions_bike_rounded;
      case 'EN_RECUPERATION': return Icons.storefront_rounded;
      case 'EN_LIVRAISON': return Icons.delivery_dining_rounded;
      case 'TERMINEE': return Icons.task_alt_rounded;
      case 'ANNULEE': return Icons.cancel_outlined;
      default: return Icons.help_outline_rounded;
    }
  }

  String get _statusDescription {
    switch (_course.status.toUpperCase()) {
      case 'CREEE': return 'La course va être diffusée aux livreurs';
      case 'DIFFUSEE': return 'En attente d\'un livreur à proximité';
      case 'ACCEPTEE': return 'Le livreur est en route vers le point de retrait';
      case 'EN_RECUPERATION': return 'Le livreur est arrivé, préparez la course';
      case 'EN_LIVRAISON': return 'Le livreur a récupéré la course et livre le client';
      case 'TERMINEE': return 'La course a été livrée avec succès !';
      case 'ANNULEE': return 'Cette course a été annulée';
      default: return '';
    }
  }

  String get _livreurStatusText {
    switch (_course.status.toUpperCase()) {
      case 'ACCEPTEE': return 'En route vers le point de retrait';
      case 'EN_RECUPERATION': return 'Arrivé — attend la course';
      case 'EN_LIVRAISON': return 'En livraison vers le client';
      case 'TERMINEE': return 'Livraison terminée';
      default: return 'Assigné';
    }
  }

  int get _statusIndex {
    switch (_course.status.toUpperCase()) {
      case 'CREEE': return 0;
      case 'DIFFUSEE': return 1;
      case 'ACCEPTEE': return 2;
      case 'EN_RECUPERATION': return 3;
      case 'EN_LIVRAISON': return 4;
      case 'TERMINEE': return 5;
      default: return 0;
    }
  }

  String _fmt(DateTime dt) => '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} à ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Évaluer le livreur', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Comment s\'est passée la récupération ?', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          // Étoiles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return GestureDetector(
                onTap: () => setState(() => _note = i + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    i < _note ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 36,
                    color: i < _note ? AppTheme.warning : AppTheme.textTertiary,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _commentCtrl,
            decoration: const InputDecoration(
              hintText: 'Commentaire (optionnel)',
              fillColor: AppTheme.white,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _note == 0 ? null : () async {
                final provider = context.read<CourseProvider>();
                final ok = await provider.evaluerLivreur(
                  widget.courseId,
                  _note,
                  _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
                );
                if (ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Merci pour votre évaluation !'),
                    backgroundColor: AppTheme.success,
                    behavior: SnackBarBehavior.floating,
                  ));
                  widget.onEvaluated();
                }
              },
              child: const Text('Envoyer l\'évaluation'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── TIMELINE STEP ──
class _Step extends StatelessWidget {
  final String label;
  final String? time;
  final bool done;
  final int idx;
  final int current;
  final bool isLast;
  const _Step({required this.label, this.time, required this.done, required this.idx, required this.current, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final isCurrent = idx == current;
    final color = done ? AppTheme.black : (isCurrent ? AppTheme.accent : AppTheme.divider);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: done ? AppTheme.black : (isCurrent ? AppTheme.accent.withOpacity(0.1) : AppTheme.background),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: done 
                  ? const Icon(Icons.check_rounded, color: AppTheme.white, size: 14)
                  : (isCurrent ? Center(child: _PulseDot(size: 8, color: AppTheme.accent)) : null),
            ),
            if (!isLast) 
              Container(
                width: 2, height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, done ? AppTheme.black : AppTheme.divider],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label, 
                  style: TextStyle(
                    fontSize: 14, 
                    fontWeight: isCurrent || done ? FontWeight.w800 : FontWeight.w500, 
                    color: isCurrent || done ? AppTheme.textPrimary : AppTheme.textTertiary,
                    letterSpacing: 0.2,
                  )
                ),
                if (time != null) ...[
                  const SizedBox(height: 2),
                  Text(time!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PulseDot extends StatefulWidget {
  final double size;
  final Color color;
  const _PulseDot({this.size = 10, this.color = AppTheme.success});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(1 - _controller.value),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.6 * (1 - _controller.value)),
                blurRadius: 10 * _controller.value,
                spreadRadius: 5 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniInfo({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textTertiary),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
      ],
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
                Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
                const SizedBox(height: 1),
                SelectableText(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppTheme.error),
        );
      }
    } finally {
      setState(() => _generating = false);
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
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.successLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Position GPS du client reçue',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.success),
              ),
            ),
          ],
        ),
      );
    }

    if (_locationLink != null) {
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningLight,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_top_rounded, color: AppTheme.warning, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'En attente de la position du client',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.warning),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _shareViaWhatsApp,
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: const Text('WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.whatsapp,
                    side: const BorderSide(color: AppTheme.whatsapp),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copier le lien'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    minimumSize: Size.zero,
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: _generating ? null : _generateLink,
      icon: _generating
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.link_rounded, size: 18),
      label: Text(_generating ? 'Génération...' : 'Envoyer un lien de localisation au client'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.accent,
        side: const BorderSide(color: AppTheme.accent),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        minimumSize: Size.zero,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}


