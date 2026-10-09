import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/dentra_glance_tile.dart';
import '../../../shared/widgets/dentra_note_card.dart';
import '../../clinic_finder/data/models/clinic_model.dart';

class ClinicDetailScreen extends StatelessWidget {
  final ClinicModel clinic;
  final Position? userPosition;

  const ClinicDetailScreen({
    super.key,
    required this.clinic,
    this.userPosition,
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Main scrollable content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── HERO SLIVER APP BAR ──────────────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                automaticallyImplyLeading: false,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _HeroBanner(clinic: clinic),
                ),
                title: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate collapse progress based on flexible space shrink
                    final settings = context
                        .dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
                    final t = settings != null
                        ? (1 - (settings.currentExtent - settings.minExtent) /
                                (settings.maxExtent - settings.minExtent))
                            .clamp(0.0, 1.0)
                        : 1.0;
                    return Opacity(
                      opacity: t,
                      child: _CollapsedTitle(name: clinic.name),
                    );
                  },
                ),
                leading: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 15,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
              ),

              // ── BODY ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    24,
                    AppSpacing.screenH,
                    110, // Space for sticky bottom bar
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // At a glance tiles
                      Row(
                        children: [
                          Expanded(
                            child: DentraGlanceTile(
                              icon: Icons.location_on_rounded,
                              label: 'Distance',
                              value: _formatDistance(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DentraGlanceTile(
                              icon: Icons.star_rounded,
                              label: 'Rating',
                              value: '${clinic.rating}\n(${clinic.reviewCount})',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DentraGlanceTile(
                              icon: Icons.medical_services_rounded,
                              label: 'Services',
                              value: '${clinic.services.length}',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 28),

                      // Divider
                      Container(
                        height: 1,
                        color: AppColors.border,
                      ),

                      const SizedBox(height: 28),

                      // Services section
                      Text(
                        'Services',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Services cards
                      if (clinic.services.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'No services listed',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        )
                      else
                        ...clinic.services.map((service) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.g2.withValues(alpha: 0.06),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      service.name,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.navy,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '₱${service.price.toStringAsFixed(0)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.g2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 16),

                      // Info note card
                      const DentraNoteCard(
                        message: 'Estimated pricing - actual services and rates may vary by clinic. '
                            'Please contact the clinic to confirm.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Sticky bottom bar with Call and Directions buttons
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    16,
                    AppSpacing.screenH,
                    16,
                  ),
                  child: Row(
                    children: [
                      // Call button (outlined)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final uri = Uri(scheme: 'tel', path: clinic.phoneNumber);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not open the phone dialer.'),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.g2,
                                  width: 2,
                                ),
                              ),
                              child: Container(
                                height: 54,
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.phone_rounded,
                                      size: 20,
                                      color: AppColors.g2,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Call',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.g2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Directions button (gradient)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              final uri = Uri.parse(
                                'https://www.google.com/maps/dir/?api=1&destination=${clinic.latitude},${clinic.longitude}',
                              );
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Could not open maps.'),
                                  ),
                                );
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Container(
                                height: 54,
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.directions_rounded,
                                      size: 20,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Directions',
                                      style: GoogleFonts.outfit(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero banner – gradient with large icon and clinic name
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final ClinicModel clinic;

  const _HeroBanner({required this.clinic});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.cardGradient,
      ),
      child: SafeArea(
        bottom: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  clinic.name,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collapsed title shown when hero is scrolled away
// ─────────────────────────────────────────────────────────────────────────────

class _CollapsedTitle extends StatelessWidget {
  final String name;

  const _CollapsedTitle({required this.name});

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
