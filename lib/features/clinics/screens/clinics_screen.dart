import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/constants/map_style.dart';
import '../../../shared/widgets/dentra_meta_chip.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../clinic_finder/data/models/clinic_model.dart';
import '../../clinic_finder/providers/clinic_provider.dart';
import 'clinic_detail_screen.dart';

class ClinicsScreen extends ConsumerStatefulWidget {
  const ClinicsScreen({super.key, this.onBack});

  /// Called by the header's back button; hidden when null.
  final VoidCallback? onBack;

  @override
  ConsumerState<ClinicsScreen> createState() => _ClinicsScreenState();
}

class _ClinicsScreenState extends ConsumerState<ClinicsScreen> {
  Position? _userPosition;
  final GlobalKey<_MapPlaceholderState> _mapKey =
      GlobalKey<_MapPlaceholderState>();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
    // Use filteredClinicsProvider when search is active, otherwise use clinicListProvider
    final filterState = ref.watch(clinicFilterProvider);
    final clinicsAsync = filterState.searchQuery.isEmpty
        ? ref.watch(clinicListProvider)
        : ref.watch(filteredClinicsProvider);

    return Column(
      children: [
        // ── HEADER ─────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: DentraPageHeader(
            title: 'Clinics Nearby',
            onBack: widget.onBack,
            bottom: SizedBox(
              height: 46,
              child: GlassCard(
                borderRadius: BorderRadius.circular(14),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {}); // Rebuild to show/hide clear button
                    ref
                        .read(clinicFilterProvider.notifier)
                        .setSearchQuery(value);
                  },
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.navy,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search clinics...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.secondaryText,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() {});
                              ref
                                  .read(clinicFilterProvider.notifier)
                                  .setSearchQuery('');
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.secondaryText,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
                  ),
                ),
              ),
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppGlass.divider),

        // ── BODY ───────────────────────────────────────────────
        Expanded(
          child: clinicsAsync.when(
            loading: () => LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                );
              },
            ),
            error: (error, stack) => LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.screenH),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
                  ),
                );
              },
            ),
            data: (clinics) {
              if (clinics.isEmpty) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Center(
                          child: _EmptyState(
                            query: filterState.searchQuery,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Map in rounded card (only show when not searching)
                    if (filterState.searchQuery.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenH, 20, AppSpacing.screenH, 0),
                        child: Container(
                          foregroundDecoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppGlass.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: _MapPlaceholder(
                              key: _mapKey,
                              userPosition: _userPosition,
                              clinics: clinics,
                            ),
                          ),
                        ),
                      ),

                    // Section label
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH, 20, AppSpacing.screenH, 12),
                      child: Text(
                        filterState.searchQuery.isEmpty
                            ? 'Nearby Clinics'
                            : 'Search Results',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),

                    // Clinic cards with animation
                    ...clinics.asMap().entries.map(
                      (entry) {
                        final index = entry.key;
                        final clinic = entry.value;
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.screenH, 0, AppSpacing.screenH, 12),
                          child: _ClinicCard(
                            clinic: clinic,
                            userPosition: _userPosition,
                            index: index,
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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

    final avgLat =
        widget.clinics.map((c) => c.latitude).reduce((a, b) => a + b) /
            widget.clinics.length;
    final avgLng =
        widget.clinics.map((c) => c.longitude).reduce((a, b) => a + b) /
            widget.clinics.length;
    return LatLng(avgLat, avgLng);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
  final Position? userPosition;
  final int index;

  const _ClinicCard({
    required this.clinic,
    this.userPosition,
    required this.index,
  });

  String _formatDistance() {
    if (userPosition == null) {
      return '-- km';
    }
    final distanceMeters = Geolocator.distanceBetween(
      userPosition!.latitude,
      userPosition!.longitude,
      clinic.latitude,
      clinic.longitude,
    );
    final distanceKm = distanceMeters / 1000;
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    // Cap stagger delay to first 6 items
    final animationIndex = index < 6 ? index : 5;

    return TweenAnimationBuilder<double>(
      key: ValueKey(clinic.id), // Key by clinic ID, not index
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 250 + (animationIndex * 40)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: GlassCard(
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
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.lightLavender,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 14),

              // Name + meta chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clinic.name,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Meta chips row
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        // Distance chip
                        DentraMetaChip(
                          icon: Icons.location_on_rounded,
                          label: _formatDistance(),
                          color: AppColors.secondaryText,
                        ),
                        // Rating chip
                        DentraMetaChip(
                          icon: Icons.star_rounded,
                          label: '${clinic.rating}',
                          color: AppColors.secondaryText,
                        ),
                        // Review count chip (if fits)
                        if (clinic.reviewCount > 0)
                          DentraMetaChip(
                            label: '${clinic.reviewCount} reviews',
                            color: AppColors.secondaryText,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Circular gradient arrow button
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.g2,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String query;

  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.lightLavender,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              size: 28,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            query.isNotEmpty ? 'No results for "$query"' : 'No clinics found',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            query.isNotEmpty
                ? 'Try a different search term or check your spelling.'
                : 'We couldn\'t find any clinics in your area.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}
