import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/course_provider.dart';
import '../../providers/location_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import 'course_livree_screen.dart';

/// Écran immersif pour une course en cours.
/// Flux : ACCEPTÉE → EN_RECUPERATION → EN_LIVRAISON → TERMINÉE
class CourseActiveScreen extends StatefulWidget {
  final Course course;
  const CourseActiveScreen({super.key, required this.course});

  @override
  State<CourseActiveScreen> createState() => _CourseActiveScreenState();
}

class _CourseActiveScreenState extends State<CourseActiveScreen> with TickerProviderStateMixin {
  late Course _course;
  bool _updating = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _course = widget.course;
  }

  // ── Quel step on est (0-based) ──
  int get _step {
    switch (_course.status.toUpperCase()) {
      case 'ACCEPTEE': return 0;
      case 'EN_RECUPERATION': return 1;
      case 'EN_LIVRAISON': return 2;
      case 'TERMINEE': return 3;
      default: return 0;
    }
  }

  bool get _isDone => _course.status.toUpperCase() == 'TERMINEE';

  // ── Données de chaque étape ──
  List<_StepData> get _steps => [
    _StepData(
      title: 'En route vers l\'expéditeur',
      subtitle: _course.expediteurNom ?? 'Commerce',
      icon: Icons.directions_rounded,
      actionLabel: 'Je suis chez l\'expéditeur',
      nextStatus: 'EN_RECUPERATION',
    ),
    _StepData(
      title: 'Récupération de la course',
      // Course cash réglée par l'expéditeur : il remet la part livreur ici.
      subtitle: _course.montantCashARecuperer > 0
          ? 'Récupérez ${AppCurrency.format(_course.montantCashARecuperer)} en espèces auprès de l\'expéditeur'
          : 'Présentez-vous au comptoir',
      icon: Icons.storefront_rounded,
      actionLabel: 'Colis récupéré',
      nextStatus: 'EN_LIVRAISON',
    ),
    _StepData(
      title: 'En livraison vers le client',
      subtitle: _course.adresseClient ?? 'Adresse non renseignée',
      icon: Icons.delivery_dining_rounded,
      // Le client ne paie plus le livreur : rien à encaisser à la porte.
      actionLabel: 'Livraison effectuée',
      nextStatus: 'TERMINEE',
    ),
    const _StepData(
      title: 'Livraison terminée',
      subtitle: 'Course complétée avec succès',
      icon: Icons.check_circle_rounded,
      actionLabel: '',
      nextStatus: '',
    ),
  ];

  Future<void> _advanceStep() async {
    if (_isDone || _updating) return;
    final step = _steps[_step];

    // Confirmation
    String? pinCode;

    if (step.nextStatus == 'TERMINEE' && _course.exigeCodeLivraison) {
      pinCode = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (ctx) => const _PinCodeSheet(),
      );
      if (pinCode == null || !mounted) return;
    } else {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _ConfirmSheet(
          label: step.actionLabel,
          icon: step.icon,
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _updating = true);
    final provider = context.read<CourseProvider>();
    final ok = await provider.updateCourseStatus(_course.id, step.nextStatus, codeLivraison: pinCode);

    if (!mounted) return;

    if (ok) {
      HapticFeedback.mediumImpact();
      // Recharger la course pour avoir les timestamps à jour
      await provider.loadMesCourses();
      final updated = provider.mesCourses.where((c) => c.id == _course.id).firstOrNull;
      if (updated != null && mounted) {
        setState(() {
          _course = updated;
          _updating = false;
        });
      } else {
        setState(() => _updating = false);
      }

      if (_course.status.toUpperCase() == 'TERMINEE' && mounted) {
        // Si c'est du CASH, on confirme aussi le paiement auto ou on demande?
        // Le backend ne confirme pas auto le paiement cash lors du changement de statut, 
        // donc on le fait ici si c'est du CASH.
        if (_course.modePaiement == 'CASH') {
          await provider.confirmerPaiement(_course.id);
        }
        
        // Petit délai pour laisser voir le check
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) _showCompletionDialog();
      }
    } else {
      setState(() => _updating = false);
      if (mounted) {
        UIUtils.showError(context, provider.error ?? 'Impossible de mettre à jour');
      }
    }
  }

  void _showCompletionDialog() {
    // Le moment « Course livrée » remplace l'écran de course : retour = accueil.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => CourseLivreeScreen(course: _course)),
    );
  }

  Future<void> _cancelCourse() async {
    final raisonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la course'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Voulez-vous vraiment annuler cette course ?'),
            const SizedBox(height: 16),
            TextField(
              controller: raisonCtrl,
              decoration: const InputDecoration(hintText: 'Raison de l\'annulation'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Retour')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Confirmer l\'annulation'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    final provider = context.read<CourseProvider>();
    final ok = await provider.cancelCourse(_course.id, raisonCtrl.text.trim().isEmpty ? 'Annulation livreur' : raisonCtrl.text.trim());

    if (mounted) {
      setState(() => _cancelling = false);
      if (ok) {
        Navigator.pop(context);
      } else {
        UIUtils.showError(context, provider.error ?? 'Erreur lors de l\'annulation');
      }
    }
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Widget _buildMap() {
    return Consumer<LocationProvider>(
      builder: (context, loc, _) {
        final livreurPos = loc.currentPosition;

        // Destination = commerce (étape 0) puis client (étapes 1, 2)
        double? destLat, destLon;
        String? destLabel;
        if (_step == 0) {
          destLat = _course.expediteurLatitude;
          destLon = _course.expediteurLongitude;
          destLabel = _course.expediteurNom ?? 'Commerce';
        } else {
          destLat = _course.latitudeClient;
          destLon = _course.longitudeClient;
          destLabel = _course.contactClientNom;
        }

        // Centrer la map sur le livreur, sinon la destination, sinon Conakry.
        LatLng center = const LatLng(9.6412, -13.5784);
        if (livreurPos != null) {
          center = LatLng(livreurPos.latitude, livreurPos.longitude);
        } else if (destLat != null && destLon != null) {
          center = LatLng(destLat, destLon);
        }

        final markers = <Marker>{};
        if (livreurPos != null) {
          markers.add(Marker(
            markerId: const MarkerId('livreur'),
            position: LatLng(livreurPos.latitude, livreurPos.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
            infoWindow: const InfoWindow(title: 'Vous'),
          ));
        }
        if (destLat != null && destLon != null) {
          markers.add(Marker(
            markerId: const MarkerId('destination'),
            position: LatLng(destLat, destLon),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(title: destLabel ?? 'Destination'),
          ));
        }

        return Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 14),
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              markers: markers,
            ),
            // CTA itinéraire (ouvre Google Maps / Apple Maps en navigation)
            Positioned(
              bottom: 12,
              right: 12,
              child: ElevatedButton.icon(
                onPressed: _navigate,
                icon: const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Itinéraire'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: AppTheme.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigate() async {
    double? lat, lon;
    if (_step == 0) {
      lat = _course.expediteurLatitude;
      lon = _course.expediteurLongitude;
    } else {
      lat = _course.latitudeClient;
      lon = _course.longitudeClient;
    }
    if (lat == null || lon == null) return;

    // Android : ouvre Google Maps directement en mode navigation turn-by-turn
    final googleNav = Uri.parse('google.navigation:q=$lat,$lon&mode=d');
    if (await canLaunchUrl(googleNav)) {
      await launchUrl(googleNav);
      return;
    }

    // iOS / universel : URL Google Maps qui ouvre l'app si installée
    // avec itinéraire complet depuis la position actuelle
    final googleUrl = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=driving',
    );
    final googleScheme = Uri.parse('comgooglemaps://');
    if (await canLaunchUrl(googleScheme)) {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
      return;
    }

    // Apple Maps
    final appleMaps = Uri.parse('maps://?daddr=$lat,$lon&dirflg=d');
    if (await canLaunchUrl(appleMaps)) {
      await launchUrl(appleMaps);
      return;
    }

    // Fallback navigateur
    await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
  }

  void _openMap() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.75,
        decoration: const BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _buildMap(),
      ),
    );
  }

  String? _heure(DateTime? d) =>
      d == null ? null : '${d.toLocal().hour.toString().padLeft(2, '0')}:${d.toLocal().minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final currentStep = _steps[_step.clamp(0, _steps.length - 1)];
    final chezExpediteur = !_isDone && _step <= 1;
    final chezClient = !_isDone && _step == 2;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── En-tête : retour · gains · carte ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  _RoundButton(
                    icon: Icons.arrow_back_rounded,
                    semanticLabel: 'Retour',
                    onTap: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Vos gains', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                        Text(
                          AppCurrency.format(_course.montantLivreur),
                          style: AppTheme.mono(size: 20, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: -0.3),
                        ),
                      ],
                    ),
                  ),
                  if (!_isDone)
                    _PillButton(icon: Icons.map_outlined, label: 'Carte', onTap: _openMap),
                ],
              ),
            ),

            // ── La frise de course : Acceptée → Expéditeur → Client ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FriseEtape(
                      etat: _EtatEtape.faite,
                      child: _EtapeResume(titre: 'Course acceptée', detail: _heure(_course.accepteeAt) ?? _course.numeroCourse),
                    ),
                    _FriseEtape(
                      etat: chezExpediteur ? _EtatEtape.active : _EtatEtape.faite,
                      child: chezExpediteur
                          ? _CarteEtape(
                              label: _step == 0 ? 'Expéditeur · allez-y maintenant' : 'Expéditeur · vous êtes sur place',
                              titre: _course.expediteurNom ?? 'Expéditeur',
                              adresse: _course.expediteurAdresse,
                              note: _course.descriptionColis,
                              encadre: _course.montantCashARecuperer > 0
                                  ? _Encadre(label: 'Espèces à récupérer', montant: AppCurrency.format(_course.montantCashARecuperer))
                                  : const _Encadre(label: 'Payée par Mobile Money : vos gains sont crédités à la livraison'),
                              actions: [
                                _ActionSecondaire(icon: Icons.navigation_rounded, label: 'Itinéraire', onTap: _navigate),
                              ],
                            )
                          : _EtapeResume(
                              titre: 'Colis récupéré · ${_course.expediteurNom ?? 'Expéditeur'}',
                              detail: _heure(_course.recupereeAt),
                            ),
                    ),
                    _FriseEtape(
                      etat: chezClient ? _EtatEtape.active : (_isDone ? _EtatEtape.faite : _EtatEtape.aVenir),
                      isLast: true,
                      child: chezClient
                          ? _CarteEtape(
                              label: 'Client · livrez maintenant',
                              titre: _course.contactClientNom,
                              adresse: _course.adresseClient,
                              note: _course.instructionsSpeciales,
                              encadre: _course.exigeCodeLivraison
                                  ? const _Encadre(label: 'Demandez au client le code à 4 chiffres reçu par SMS')
                                  : null,
                              actions: [
                                _ActionSecondaire(
                                  icon: Icons.phone_rounded,
                                  label: 'Appeler',
                                  onTap: () => _callPhone(_course.contactClientTelephone),
                                ),
                                _ActionSecondaire(icon: Icons.navigation_rounded, label: 'Itinéraire', onTap: _navigate),
                              ],
                            )
                          : _EtapeResume(
                              titre: _isDone ? 'Livrée · ${_course.contactClientNom}' : 'Client · ${_course.contactClientNom}',
                              detail: _isDone
                                  ? _heure(_course.livreeAt)
                                  : [
                                      if (_course.distanceKm != null) '${_course.distanceKm!.toStringAsFixed(1).replaceAll('.', ',')} km de livraison',
                                      if (_course.exigeCodeLivraison) 'code de livraison demandé',
                                    ].join(' · '),
                            ),
                    ),
                    const SizedBox(height: 24),
                    _FinancialSummary(course: _course),
                    if (_course.status.toUpperCase() == 'ACCEPTEE') ...[
                      const SizedBox(height: 16),
                      Center(
                        child: _cancelling
                            ? const SizedBox(height: 48, child: Center(child: BrandDotsPulse(color: AppTheme.textSecondary)))
                            : TextButton(
                                onPressed: _cancelCourse,
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.error,
                                  minimumSize: const Size(48, 48),
                                ),
                                child: const Text('Annuler la course', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                              ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Une seule action principale, en bas ──
            if (!_isDone)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: PrimaryCta(
                  label: currentStep.actionLabel,
                  loading: _updating,
                  onPressed: _advanceStep,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Data model pour les étapes ──
class _StepData {
  final String title;
  final String subtitle;
  final IconData icon;
  final String actionLabel;
  final String nextStatus;
  const _StepData({required this.title, required this.subtitle, required this.icon, required this.actionLabel, required this.nextStatus});
}

// ── Frise verticale (signature Sönaiyaa) ──
enum _EtatEtape { faite, active, aVenir }

class _FriseEtape extends StatelessWidget {
  final _EtatEtape etat;
  final Widget child;
  final bool isLast;
  const _FriseEtape({required this.etat, required this.child, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    Widget point;
    switch (etat) {
      case _EtatEtape.faite:
        point = Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, size: 18, color: AppTheme.white),
        );
      case _EtatEtape.active:
        point = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.accent,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.2), spreadRadius: 6)],
          ),
        );
      case _EtatEtape.aVenir:
        point = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.background,
            shape: BoxShape.circle,
            border: Border.all(color: AppTheme.textPrimary, width: 3),
          ),
        );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                point,
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: etat == _EtatEtape.faite ? AppTheme.success : AppTheme.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _EtapeResume extends StatelessWidget {
  final String titre;
  final String? detail;
  const _EtapeResume({required this.titre, this.detail});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(detail!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          ],
        ],
      ),
    );
  }
}

/// Étape en cours, dépliée : où aller, quoi récupérer, et les actions secondaires.
class _CarteEtape extends StatelessWidget {
  final String label;
  final String titre;
  final String? adresse;
  final String? note;
  final _Encadre? encadre;
  final List<_ActionSecondaire> actions;
  const _CarteEtape({
    required this.label,
    required this.titre,
    this.adresse,
    this.note,
    this.encadre,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.shadowMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.accentDark)),
          const SizedBox(height: 4),
          Text(titre, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          if (adresse != null && adresse!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(adresse!, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.35)),
          ],
          if (note != null && note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary, height: 1.35)),
          ],
          if (encadre != null) ...[
            const SizedBox(height: 12),
            encadre!,
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: actions[i]),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Encadre extends StatelessWidget {
  final String label;
  final String? montant;
  const _Encadre({required this.label, this.montant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.accentDark, height: 1.35)),
          ),
          if (montant != null)
            Text(montant!, style: AppTheme.mono(size: 15, weight: FontWeight.w800, color: AppTheme.textPrimary, spacing: 0)),
        ],
      ),
    );
  }
}

class _ActionSecondaire extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionSecondaire({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          side: const BorderSide(color: AppTheme.divider, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.semanticLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.cardBg,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onTap,
        tooltip: semanticLabel,
        icon: Icon(icon, color: AppTheme.textPrimary),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PillButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        style: TextButton.styleFrom(
          foregroundColor: AppTheme.textPrimary,
          backgroundColor: AppTheme.cardBg,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

// ── Bottom sheet de confirmation ──
class _ConfirmSheet extends StatelessWidget {
  final String label;
  final IconData icon;
  const _ConfirmSheet({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      decoration: const BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.accent, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('Confirmer l\'action', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Confirmer'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Récap financier de la course ──
class _FinancialSummary extends StatelessWidget {
  final Course course;
  const _FinancialSummary({required this.course});

  bool get _isCash => course.modePaiement.toUpperCase() == 'CASH';

  @override
  Widget build(BuildContext context) {
    final paymentColor = _isCash ? AppTheme.warning : AppTheme.success;
    final paymentBg = _isCash ? AppTheme.warningLight : AppTheme.successLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Titre + badge mode de paiement
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined,
                  size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              const Text(
                'Détails financiers',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: paymentBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: paymentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isCash ? Icons.payments_outlined : Icons.phone_android_rounded,
                      size: 12,
                      color: paymentColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isCash ? 'Espèces' : 'Mobile Money',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: paymentColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Lignes de décomposition
          _FinLine(label: 'Prix de la course', value: AppCurrency.format(course.prixPropose)),
          const SizedBox(height: 8),
          _FinLine(
            label: 'Commission Sönaiyaa',
            value: '−${AppCurrency.format(course.commissionPlateforme)}',
            valueColor: AppTheme.textSecondary,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _FinLine(
            label: 'Vos gains',
            value: AppCurrency.format(course.montantLivreur),
            valueColor: AppTheme.success,
            big: true,
          ),
          const SizedBox(height: 10),
          // Note sur le mode de paiement (impact wallet)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.textTertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isCash
                        ? 'L\'expéditeur vous remet ${AppCurrency.format(course.montantLivreur)} en espèces à la récupération du colis.'
                        : 'Course payée en ligne. Votre part est créditée sur vos Gains à la livraison.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool big;

  const _FinLine({
    required this.label,
    required this.value,
    this.valueColor,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: big ? 14 : 13,
            fontWeight: big ? FontWeight.w700 : FontWeight.w500,
            color: big ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: AppTheme.mono(
            size: big ? 18 : 13,
            weight: big ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? AppTheme.textPrimary,
            spacing: big ? -0.3 : 0,
          ),
        ),
      ],
    );
  }
}

// ── Bottom sheet pour Code PIN ──
class _PinCodeSheet extends StatefulWidget {
  const _PinCodeSheet();

  @override
  State<_PinCodeSheet> createState() => _PinCodeSheetState();
}

class _PinCodeSheetState extends State<_PinCodeSheet> {
  final TextEditingController _pinCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        decoration: const BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded, color: AppTheme.warning, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Code de sécurité', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Demandez le code PIN au client pour valider cette livraison sécurisée.',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _pinCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: '----',
                counterText: '',
                filled: true,
                fillColor: AppTheme.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
                      onPressed: () {
                        if (_pinCtrl.text.isNotEmpty) {
                          Navigator.pop(context, _pinCtrl.text);
                        }
                      },
                      child: const Text('Valider'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
