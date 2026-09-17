import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/services/mock_data.dart';
import 'clinic_detail_screen.dart';

class ClinicsScreen extends StatelessWidget {
  const ClinicsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        children: [
          // ── HEADER ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenH, 52, AppSpacing.screenH, 16),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find a Dentist',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Nearby dental clinics',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.border),

          // ── BODY ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map placeholder
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH, 20, AppSpacing.screenH, 0),
                    child: _MapPlaceholder(),
                  ),

                  // Nearby Clinics label
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH, 20, AppSpacing.screenH, 12),
                    child: Text(
                      'Nearby Clinics',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),

                  // Clinic cards
                  ...MockData.clinics.map(
                    (clinic) => Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH, 0, AppSpacing.screenH, 10),
                      child: _ClinicCard(clinic: clinic),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Map widget ────────────────────────────────────────────────────

class _MapPlaceholder extends StatefulWidget {
  @override
  State<_MapPlaceholder> createState() => _MapPlaceholderState();
}

class _MapPlaceholderState extends State<_MapPlaceholder> {
  late GoogleMapController _mapController;
  late Set<Marker> _markers;

  @override
  void initState() {
    super.initState();
    _markers = _createMarkers();
  }

  Set<Marker> _createMarkers() {
    return MockData.clinics.map((clinic) {
      return Marker(
        markerId: MarkerId('clinic_${clinic.id}'),
        position: LatLng(clinic.latitude, clinic.longitude),
        infoWindow: InfoWindow(
          title: clinic.name,
          snippet: clinic.distance,
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      );
    }).toSet();
  }

  LatLng _calculateCenter() {
    final avgLat = MockData.clinics
            .map((c) => c.latitude)
            .reduce((a, b) => a + b) /
        MockData.clinics.length;
    final avgLng = MockData.clinics
            .map((c) => c.longitude)
            .reduce((a, b) => a + b) /
        MockData.clinics.length;
    return LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 220,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _calculateCenter(),
            zoom: 14.5,
          ),
          markers: _markers,
          onMapCreated: (controller) {
            _mapController = controller;
          },
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          gestureRecognizers: {
            Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }
}

// ── Clinic card ───────────────────────────────────────────────────

class _ClinicCard extends StatelessWidget {
  final dynamic clinic;
  const _ClinicCard({required this.clinic});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Icon + name + distance
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.lightLavender,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clinic.name,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        clinic.distance,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clinic.services,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // View button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ClinicDetailScreen(clinic: clinic),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.lightLavender,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'View',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
