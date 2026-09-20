import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/models/clinic_model.dart';
import '../../../core/services/mock_data.dart';

class ClinicsScreen extends ConsumerStatefulWidget {
  const ClinicsScreen({super.key});

  @override
  ConsumerState<ClinicsScreen> createState() => _ClinicsScreenState();
}

class _ClinicsScreenState extends ConsumerState<ClinicsScreen> {
  Position? _userPosition;
  final GlobalKey<_MapPlaceholderState> _mapKey = GlobalKey<_MapPlaceholderState>();

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Silently fall back to calculated center
        return;
      }

      // Check permission status
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Silently fall back to calculated center
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Silently fall back to calculated center
        return;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _userPosition = position;
      });

      // Update the migrated logic layer's location state
      ref.read(userLocationProvider.notifier).setLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      // Animate camera to user's location
      _mapKey.currentState?._animateToUserLocation(position);
    } catch (e) {
      // Silently fall back to calculated center on any error
      // This is a demo, so we don't show errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final clinicsAsync = ref.watch(clinicListProvider);

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
            child: clinicsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenH),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.secondaryText,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load clinics',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              data: (clinics) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Map placeholder
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH, 20, AppSpacing.screenH, 0),
                      child: _MapPlaceholder(
                        key: _mapKey,
                        userPosition: _userPosition,
                        clinics: clinics,
                      ),
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
                    ...clinics.map(
                      (clinic) => Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenH, 0, AppSpacing.screenH, 10),
                        child: _ClinicCard(
                          clinic: clinic,
                          userPosition: _userPosition,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
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
  final Position? userPosition;
  final List<ClinicModel> clinics;

  const _MapPlaceholder({
    super.key,
    this.userPosition,
    required this.clinics,
  });

  @override
  State<_MapPlaceholder> createState() => _MapPlaceholderState();
}

class _MapPlaceholderState extends State<_MapPlaceholder> {
  GoogleMapController? _mapController;
  late Set<Marker> _markers;
  bool _hasAnimatedToUserLocation = false;

  @override
  void initState() {
    super.initState();
    _markers = _createMarkers();
  }

  @override
  void didUpdateWidget(covariant _MapPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userPosition != widget.userPosition ||
        oldWidget.clinics != widget.clinics) {
      setState(() {
        _markers = _createMarkers();
      });
    }
  }

  /// Animate camera to user's location when position first resolves
  void _animateToUserLocation(Position position) {
    // Only animate once when position first arrives
    if (!_hasAnimatedToUserLocation && _mapController != null) {
      _hasAnimatedToUserLocation = true;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14.5,
        ),
      );
    }
  }

  Set<Marker> _createMarkers() {
    final markers = <Marker>{};

    // Add clinic markers
    markers.addAll(
      widget.clinics.map((clinic) {
        return Marker(
          markerId: MarkerId('clinic_${clinic.id}'),
          position: LatLng(clinic.latitude, clinic.longitude),
          infoWindow: InfoWindow(
            title: clinic.name,
            snippet: _formatDistance(clinic),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
        );
      }),
    );

    // Add user location marker if available
    if (widget.userPosition != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(
            widget.userPosition!.latitude,
            widget.userPosition!.longitude,
          ),
          infoWindow: const InfoWindow(
            title: 'Your Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    return markers;
  }

  String _formatDistance(ClinicModel clinic) {
    if (widget.userPosition == null) {
      return '-- km';
    }
    final distanceMeters = Geolocator.distanceBetween(
      widget.userPosition!.latitude,
      widget.userPosition!.longitude,
      clinic.latitude,
      clinic.longitude,
    );
    final distanceKm = distanceMeters / 1000;
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  LatLng _calculateCenter() {
    // If we have user position, use it
    if (widget.userPosition != null) {
      return LatLng(
        widget.userPosition!.latitude,
        widget.userPosition!.longitude,
      );
    }

    // Otherwise, calculate center of clinics
    if (widget.clinics.isEmpty) {
      // Default fallback if no clinics
      return const LatLng(14.5995, 120.9842); // Manila City Hall
    }

    final avgLat = widget.clinics
            .map((c) => c.latitude)
            .reduce((a, b) => a + b) /
        widget.clinics.length;
    final avgLng = widget.clinics
            .map((c) => c.longitude)
            .reduce((a, b) => a + b) /
        widget.clinics.length;
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
          style: mapStyle,
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
    _mapController?.dispose();
    super.dispose();
  }
}

// ── Clinic card ───────────────────────────────────────────────────

class _ClinicCard extends StatelessWidget {
  final ClinicModel clinic;
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
                        _formatDistance(),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatServices(),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                  builder: (context) => ClinicDetailScreen(
                    clinic: clinic,
                    userPosition: userPosition,
                  ),
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
