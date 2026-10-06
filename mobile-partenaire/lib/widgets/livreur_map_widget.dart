import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mobile_core/mobile_core.dart';

/// Widget affichant une carte Google Maps avec la position du livreur,
/// de l’établissement et du client.
class LivreurMapWidget extends StatefulWidget {
  final double? expediteurLat;
  final double? expediteurLng;
  final double? livreurLat;
  final double? livreurLng;
  final double? clientLat;
  final double? clientLng;

  const LivreurMapWidget({
    super.key,
    this.expediteurLat,
    this.expediteurLng,
    this.livreurLat,
    this.livreurLng,
    this.clientLat,
    this.clientLng,
  });

  @override
  State<LivreurMapWidget> createState() => _LivreurMapWidgetState();
}

class _LivreurMapWidgetState extends State<LivreurMapWidget> {
  GoogleMapController? _mapController;

  @override
  void didUpdateWidget(covariant LivreurMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recentrer la carte si la position du livreur a changé
    if (oldWidget.livreurLat != widget.livreurLat ||
        oldWidget.livreurLng != widget.livreurLng) {
      _fitBounds();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// Construit les marqueurs visibles sur la carte.
  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Marqueur expediteur (rouge)
    if (widget.expediteurLat != null && widget.expediteurLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('expediteur'),
        position: LatLng(widget.expediteurLat!, widget.expediteurLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Expéditeur'),
      ));
    }

    // Marqueur livreur (orange/accent)
    if (widget.livreurLat != null && widget.livreurLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('livreur'),
        position: LatLng(widget.livreurLat!, widget.livreurLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: const InfoWindow(title: 'Livreur'),
      ));
    }

    // Marqueur client (vert)
    if (widget.clientLat != null && widget.clientLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('client'),
        position: LatLng(widget.clientLat!, widget.clientLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Client'),
      ));
    }

    return markers;
  }

  /// Construit une polyline expediteur -> livreur -> client.
  Set<Polyline> _buildPolylines() {
    final points = <LatLng>[];

    if (widget.expediteurLat != null && widget.expediteurLng != null) {
      points.add(LatLng(widget.expediteurLat!, widget.expediteurLng!));
    }
    if (widget.livreurLat != null && widget.livreurLng != null) {
      points.add(LatLng(widget.livreurLat!, widget.livreurLng!));
    }
    if (widget.clientLat != null && widget.clientLng != null) {
      points.add(LatLng(widget.clientLat!, widget.clientLng!));
    }

    if (points.length < 2) return {};

    return {
      Polyline(
        polylineId: const PolylineId('trajet'),
        points: points,
        color: AppTheme.accent.withValues(alpha: 0.6),
        width: 3,
        patterns: [PatternItem.dash(12), PatternItem.gap(8)],
      ),
    };
  }

  /// Calcule la position initiale de la caméra pour englober tous les marqueurs.
  CameraPosition _initialCamera() {
    final points = <LatLng>[];

    if (widget.expediteurLat != null && widget.expediteurLng != null) {
      points.add(LatLng(widget.expediteurLat!, widget.expediteurLng!));
    }
    if (widget.livreurLat != null && widget.livreurLng != null) {
      points.add(LatLng(widget.livreurLat!, widget.livreurLng!));
    }
    if (widget.clientLat != null && widget.clientLng != null) {
      points.add(LatLng(widget.clientLat!, widget.clientLng!));
    }

    if (points.isEmpty) {
      // Défaut : Abidjan, Côte d'Ivoire
      return const CameraPosition(target: LatLng(5.3600, -4.0083), zoom: 13);
    }

    if (points.length == 1) {
      return CameraPosition(target: points.first, zoom: 15);
    }

    // Centre des points
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    return CameraPosition(target: LatLng(centerLat, centerLng), zoom: 13);
  }

  /// Ajuste les limites de la carte pour montrer tous les marqueurs.
  void _fitBounds() {
    if (_mapController == null) return;

    final points = <LatLng>[];
    if (widget.expediteurLat != null && widget.expediteurLng != null) {
      points.add(LatLng(widget.expediteurLat!, widget.expediteurLng!));
    }
    if (widget.livreurLat != null && widget.livreurLng != null) {
      points.add(LatLng(widget.livreurLat!, widget.livreurLng!));
    }
    if (widget.clientLat != null && widget.clientLng != null) {
      points.add(LatLng(widget.clientLat!, widget.clientLng!));
    }

    if (points.length < 2) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 50),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si la position du livreur est indisponible, afficher un placeholder
    if (widget.livreurLat == null || widget.livreurLng == null) {
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.divider),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_rounded, size: 32, color: AppTheme.textSecondary),
              SizedBox(height: 8),
              Text(
                'Position du livreur indisponible',
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: SizedBox(
        height: 280,
        child: GoogleMap(
          initialCameraPosition: _initialCamera(),
          markers: _buildMarkers(),
          polylines: _buildPolylines(),
          onMapCreated: (controller) {
            _mapController = controller;
            Future.delayed(const Duration(milliseconds: 300), _fitBounds);
          },
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          mapToolbarEnabled: false,
          liteModeEnabled: false,
          compassEnabled: false,
          scrollGesturesEnabled: true,
          zoomGesturesEnabled: true,
          rotateGesturesEnabled: true,
          tiltGesturesEnabled: true,
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
          padding: const EdgeInsets.all(8),
        ),
      ),
    );
  }
}
