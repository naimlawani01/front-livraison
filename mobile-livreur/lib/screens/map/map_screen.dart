import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/course_provider.dart';
import 'package:mobile_core/mobile_core.dart';
import '../courses/course_active_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final locationProvider = context.watch<LocationProvider>();
    final courseProvider = context.watch<CourseProvider>();
    
    final livreur = authProvider.livreur;
    final position = locationProvider.currentPosition;
    final currentCourse = courseProvider.currentCourse;

    LatLng center = const LatLng(6.1319, 1.2228); // Lomé par défaut
    if (position != null) {
      center = LatLng(position.latitude, position.longitude);
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tableau de bord', style: TextStyle(fontSize: 18)),
            if (livreur != null)
              Text(
                livreur.isDisponible ? '🟢 En ligne' : '⚫ Hors ligne',
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          if (livreur != null)
            Chip(
              label: Text(
                '${livreur.totalGains.toInt()} ${AppCurrency.symbol}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: AppColors.primary,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: center,
              zoom: 14,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            compassEnabled: true,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            markers: _buildMarkers(position, currentCourse),
          ),

          // Stats overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.check_circle,
                      label: 'Complétées',
                      value: '${livreur?.nombreCoursesCompletees ?? 0}',
                    ),
                    _StatItem(
                      icon: Icons.star,
                      label: 'Note',
                      value: livreur != null && livreur.nombreEvaluations > 0
                          ? '${livreur.noteMoyenne.toStringAsFixed(1)} ⭐'
                          : '-',
                    ),
                    const _StatItem(
                      icon: Icons.money,
                      label: 'Aujourd\'hui',
                      value: '0 ${AppCurrency.symbol}',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Current course card
          if (currentCourse != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Card(
                color: AppColors.primary,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.delivery_dining, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Course en cours',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentCourse.numeroCourse,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        currentCourse.adresseClient ?? 'Localisation par lien',
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CourseActiveScreen(course: currentCourse),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                        ),
                        child: const Text('Voir les détails'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers(position, currentCourse) {
    Set<Marker> markers = {};

    // Current position
    if (position != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('my_position'),
          position: LatLng(position.latitude, position.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Ma position'),
        ),
      );
    }

    // Destination (if course active)
    if (currentCourse?.latitudeClient != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(
            currentCourse!.latitudeClient!,
            currentCourse.longitudeClient!,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: currentCourse.adresseClient ?? 'Client'),
        ),
      );
    }

    return markers;
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
