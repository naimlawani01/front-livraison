import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/course_provider.dart';
import '../../providers/location_provider.dart';
import 'package:mobile_core/mobile_core.dart';

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
      title: 'En route vers le commerce',
      subtitle: _course.expediteurNom ?? 'Commerce',
      icon: Icons.directions_rounded,
      actionLabel: 'Je suis arrivé au commerce',
      nextStatus: 'EN_RECUPERATION',
    ),
    const _StepData(
      title: 'Récupération de la course',
      subtitle: 'Présentez-vous au comptoir',
      icon: Icons.storefront_rounded,
      actionLabel: 'Course récupérée, en route !',
      nextStatus: 'EN_LIVRAISON',
    ),
    _StepData(
      title: 'En livraison vers le client',
      subtitle: _course.adresseClient ?? 'Adresse non renseignée',
      icon: Icons.delivery_dining_rounded,
      actionLabel: _course.modePaiement == 'CASH'
          ? 'Confirmer le paiement et la livraison'
          : 'Livraison effectuée',
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: const BoxDecoration(
                  color: AppTheme.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: AppTheme.success, size: 36),
              ),
              const SizedBox(height: 20),
              const Text('Bravo !', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                _course.modePaiement == 'CASH'
                    ? 'Livraison effectuée et paiement encaissé.\nVous avez gagné ${AppCurrency.format(_course.montantLivreur)}'
                    : 'Livraison effectuée avec succès.\nVous avez gagné ${AppCurrency.format(_course.montantLivreur)}',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('Retour à l\'accueil'),
                ),
              ),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) {
    final currentStep = _steps[_step.clamp(0, _steps.length - 1)];

    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header (fixe) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(_course.numeroCourse, style: Theme.of(context).textTheme.titleLarge),
                  ),
                  if (_course.status.toUpperCase() == 'ACCEPTEE')
                    _cancelling 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : TextButton(
                          onPressed: _cancelCourse,
                          style: TextButton.styleFrom(foregroundColor: AppTheme.error),
                          child: const Text('Annuler', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                  const SizedBox(width: 12),
                  Text(
                    AppCurrency.format(_course.montantLivreur),
                    style: AppTheme.mono(size: 18, weight: FontWeight.w800, color: AppTheme.accent, spacing: -0.3),
                  ),
                ],
              ),
            ),

            // ── Stepper visuel (fixe) ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _ProgressBar(step: _step, total: 3),
            ),

            // ── Contenu scrollable ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 20, bottom: 12),
                child: Column(
                  children: [
                    // ── Mini-carte avec position livreur + destination ──
                    if (!_isDone)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                          child: SizedBox(
                            height: 220,
                            child: _buildMap(),
                          ),
                        ),
                      ),
                    if (!_isDone) const SizedBox(height: 20),

                    // ── Carte étape actuelle ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          key: ValueKey(_step),
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: _isDone ? null : AppTheme.accentGradient,
                            color: _isDone ? AppTheme.success : null,
                            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                            boxShadow: [
                              BoxShadow(
                                color: (_isDone ? AppTheme.success : AppTheme.accent).withValues(alpha: 0.28),
                                blurRadius: 20,
                                spreadRadius: -6,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Icon(currentStep.icon, color: AppTheme.white, size: 36),
                              const SizedBox(height: 12),
                              Text(
                                currentStep.title,
                                style: const TextStyle(color: AppTheme.white, fontSize: 18, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currentStep.subtitle,
                                style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Timeline compacte ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: List.generate(_steps.length, (i) {
                          final s = _steps[i];
                          final done = i < _step;
                          final active = i == _step;
                          return _TimelineRow(
                            title: s.title,
                            done: done || _isDone,
                            active: active && !_isDone,
                            isLast: i == _steps.length - 1,
                          );
                        }),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Infos contact ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.background,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Column(
                          children: [
                            _ContactRow(
                              icon: Icons.storefront_rounded,
                              label: _course.expediteurNom ?? 'Expediteur',
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_step == 0) _SmallAction(
                                    icon: Icons.navigation_rounded,
                                    color: AppTheme.info,
                                    onTap: _navigate,
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 16),
                            _ContactRow(
                              icon: Icons.person_rounded,
                              label: _course.contactClientNom,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _SmallAction(
                                    icon: Icons.phone_rounded,
                                    color: AppTheme.success,
                                    onTap: () => _callPhone(_course.contactClientTelephone),
                                  ),
                                  if (_step >= 2) ...[
                                    const SizedBox(width: 8),
                                    _SmallAction(
                                      icon: Icons.navigation_rounded,
                                      color: AppTheme.info,
                                      onTap: _navigate,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (_course.descriptionColis != null && _course.descriptionColis!.isNotEmpty) ...[
                              const Divider(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.inventory_2_outlined, size: 16, color: AppTheme.textTertiary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _course.descriptionColis!,
                                      style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (_course.instructionsSpeciales != null && _course.instructionsSpeciales!.isNotEmpty) ...[
                              const Divider(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.notes_rounded, size: 16, color: AppTheme.textTertiary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _course.instructionsSpeciales!,
                                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    if (_course.exigeCodeLivraison)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_rounded, color: AppTheme.warning, size: 20),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Livraison Sécurisée : Un code PIN sera demandé au client.',
                                  style: TextStyle(color: AppTheme.warning, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ── Récap financier ──
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _FinancialSummary(course: _course),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bouton action principal (fixe en bas) ──
            if (!_isDone)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _updating ? null : _advanceStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _step == 2 ? AppTheme.success : AppTheme.accent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    child: _updating
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: AppTheme.white, strokeWidth: 2))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_stepActionIcon, size: 20),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  currentStep.actionLabel,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),

            if (_isDone) const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  IconData get _stepActionIcon {
    switch (_step) {
      case 0: return Icons.location_on_rounded;
      case 1: return Icons.inventory_2_rounded;
      case 2: return Icons.check_circle_rounded;
      default: return Icons.check_rounded;
    }
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

// ── Barre de progression ──
class _ProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _ProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final done = i < step;
        final active = i == step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: done
                  ? AppTheme.success
                  : active
                      ? AppTheme.accent
                      : AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

// ── Timeline row ──
class _TimelineRow extends StatelessWidget {
  final String title;
  final bool done;
  final bool active;
  final bool isLast;
  const _TimelineRow({required this.title, required this.done, required this.active, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 18, height: 18,
              decoration: BoxDecoration(
                color: done ? AppTheme.success : active ? AppTheme.accent : AppTheme.divider,
                shape: BoxShape.circle,
              ),
              child: done
                  ? const Icon(Icons.check_rounded, color: AppTheme.white, size: 12)
                  : active
                      ? Container(
                          margin: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(color: AppTheme.white, shape: BoxShape.circle),
                        )
                      : null,
            ),
            if (!isLast) Container(width: 1.5, height: 20, color: done ? AppTheme.success.withValues(alpha: 0.3) : AppTheme.divider),
          ],
        ),
        const SizedBox(width: 12),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: done || active ? FontWeight.w600 : FontWeight.w400,
              color: done || active ? AppTheme.textPrimary : AppTheme.textTertiary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Contact row ──
class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget trailing;
  const _ContactRow({required this.icon, required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        trailing,
      ],
    );
  }
}

// ── Petit bouton action ──
class _SmallAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SmallAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: color),
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
            label: 'Commission plateforme',
            value: '−${AppCurrency.format(course.commissionPlateforme)}',
            valueColor: AppTheme.error,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          _FinLine(
            label: 'Ma part',
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
                        ? 'Vous recevez ${AppCurrency.format(course.montantLivreur)} en espèces pour cette course.'
                        : 'Course payée en ligne. Votre part est créditée sur vos Gains.',
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
