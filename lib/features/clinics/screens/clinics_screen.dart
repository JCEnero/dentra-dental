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
import '../../../core/services/maps_loader.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../clinic_finder/data/models/clinic_model.dart';
import '../../clinic_finder/providers/clinic_provider.dart';
import '../widgets/clinic_ui.dart';
import 'clinic_detail_screen.dart';

/// The map is switched off for now: on web it renders glitches over the
/// glass UI. Set to true to bring it back.
const bool _kShowMap = false;

/// Default search radius, matching [ClinicFilterState.radiusKm].
const double _kDefaultRadiusKm = 5.0;

enum _ClinicSort {
  nearest('Nearest', Icons.near_me_rounded),
  topRated('Top rated', Icons.star_rounded);

  const _ClinicSort(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Number of filters that differ from their defaults.
int _activeFilterCount(ClinicFilterState f) =>
    (f.radiusKm != _kDefaultRadiusKm ? 1 : 0) +
    (f.minRating > 0 ? 1 : 0) +
    (f.maxPrice != null ? 1 : 0);

/// Clears distance, rating and budget but keeps the search text, which
/// [ClinicFilterNotifier.reset] would also wipe.
void _resetFilters(ClinicFilterNotifier notifier) {
  notifier
    ..setRadiusKm(_kDefaultRadiusKm)
    ..setMinRating(0)
    ..setMaxPrice(null);
}

double _distanceKm(UserLocation from, ClinicModel clinic) =>
    Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      clinic.latitude,
      clinic.longitude,
    ) /
    1000;

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

  _ClinicSort _sort = _ClinicSort.nearest;
  bool _locating = false;

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

  /// Resolves the device location and reloads clinics around it.
  ///
  /// On first load this fails silently and the list falls back to the
  /// default area. When the user taps the locate button ([manual]), the
  /// reason is shown so they know what to fix.
  Future<void> _getUserLocation({bool manual = false}) async {
    setState(() => _locating = true);
    String? problem;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        problem = 'Turn on location services to find clinics near you.';
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        problem = 'Location access is off. Allow it in Settings to see '
            'clinics around you.';
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _userPosition = position);

      // Update the logic layer's location; the clinic list reloads.
      ref.read(userLocationProvider.notifier).setLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          );

      _mapKey.currentState?._animateToUserLocation(position);
    } catch (_) {
      problem = 'Could not get your location. Try again in a moment.';
    } finally {
      if (mounted) {
        setState(() => _locating = false);
        if (manual && problem != null) {
          showDentraSnack(context, problem, tone: DentraFeedbackTone.info);
        }
      }
    }
  }

  void _setSearch(String value) {
    setState(() {}); // Show or hide the clear button.
    ref.read(clinicFilterProvider.notifier).setSearchQuery(value);
  }

  void _clearSearch() {
    _searchController.clear();
    _setSearch('');
  }

  Future<void> _refresh() => ref.read(clinicListProvider.notifier).refresh();

  void _openFilters() {
    showGlassSheet<void>(
      context: context,
      title: 'Filter clinics',
      subtitle: 'Narrow the list by distance, rating and budget.',
      builder: (_) => const _FilterSheetBody(),
    );
  }

  List<ClinicModel> _sorted(List<ClinicModel> clinics, UserLocation from) {
    final list = [...clinics];
    switch (_sort) {
      case _ClinicSort.nearest:
        list.sort(
            (a, b) => _distanceKm(from, a).compareTo(_distanceKm(from, b)));
      case _ClinicSort.topRated:
        list.sort((a, b) {
          final byRating = b.rating.compareTo(a.rating);
          return byRating != 0
              ? byRating
              : b.reviewCount.compareTo(a.reviewCount);
        });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(clinicFilterProvider);
    final location = ref.watch(userLocationProvider);
    final clinicsAsync = ref.watch(filteredClinicsProvider);
    final filterCount = _activeFilterCount(filters);

    return Column(
      children: [
        // ── HEADER ─────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: DentraPageHeader(
            title: 'Clinics Nearby',
            onBack: widget.onBack,
            trailing: ClinicGlassIconButton(
              icon: Icons.my_location_rounded,
              tooltip: 'Use my current location',
              busy: _locating,
              onPressed: () => _getUserLocation(manual: true),
            ),
            bottom: Row(
              children: [
                Expanded(
                  child: _SearchField(
                    controller: _searchController,
                    onChanged: _setSearch,
                    onClear: _clearSearch,
                  ),
                ),
                const SizedBox(width: 10),
                ClinicGlassIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: filterCount > 0
                      ? 'Filters, $filterCount active'
                      : 'Filters',
                  active: filterCount > 0,
                  badgeCount: filterCount,
                  onPressed: _openFilters,
                ),
              ],
            ),
          ),
        ),
        Divider(height: 1, thickness: 1, color: AppGlass.divider),

        // ── BODY ───────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.g2,
            backgroundColor: AppColors.white,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: clinicsAsync.when(
                loading: () => [
                  _toolbar(count: null, filters: filters),
                  const _SkeletonList(),
                ],
                error: (_, __) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _StatusView(
                      icon: Icons.wifi_off_rounded,
                      title: 'Could not load clinics',
                      message: 'Check your connection, then try again.',
                      actionLabel: 'Try again',
                      actionIcon: Icons.refresh_rounded,
                      onAction: _refresh,
                    ),
                  ),
                ],
                data: (clinics) {
                  if (clinics.isEmpty) {
                    return [
                      _toolbar(count: 0, filters: filters),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _emptyState(filters, filterCount),
                      ),
                    ];
                  }

                  final sorted = _sorted(clinics, location);
                  final showBadges = filters.searchQuery.isEmpty;
                  return [
                    if (_kShowMap && filters.searchQuery.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
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
                      ),
                    _toolbar(count: sorted.length, filters: filters),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenH),
                      sliver: SliverList.separated(
                        itemCount: sorted.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final clinic = sorted[index];
                          return _ClinicCard(
                            clinic: clinic,
                            distanceKm: _distanceKm(location, clinic),
                            index: index,
                            badge: showBadges && index == 0
                                ? switch (_sort) {
                                    _ClinicSort.nearest => 'Closest to you',
                                    _ClinicSort.topRated => 'Highest rated',
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 28)),
                  ];
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Location status, result count and sort chips above the list.
  Widget _toolbar({required int? count, required ClinicFilterState filters}) {
    final searching = filters.searchQuery.isNotEmpty;
    final String summary;
    if (count == null) {
      summary = 'Finding clinics…';
    } else if (searching) {
      summary = '$count ${count == 1 ? 'result' : 'results'}';
    } else {
      summary = '$count ${count == 1 ? 'clinic' : 'clinics'} within '
          '${filters.radiusKm.toStringAsFixed(0)} km';
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        summary,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                  _LocationPill(precise: _userPosition != null),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
                itemCount: _ClinicSort.values.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final sort = _ClinicSort.values[i];
                  return DentraChoiceChip(
                    label: sort.label,
                    selected: _sort == sort,
                    onSelected: () => setState(() => _sort = sort),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ClinicFilterState filters, int filterCount) {
    if (filters.searchQuery.isNotEmpty) {
      return _StatusView(
        icon: Icons.search_off_rounded,
        title: 'No results for "${filters.searchQuery}"',
        message: 'Try a different name or area, or check the spelling.',
        actionLabel: 'Clear search',
        actionIcon: Icons.close_rounded,
        onAction: _clearSearch,
      );
    }
    if (filterCount > 0) {
      return _StatusView(
        icon: Icons.filter_alt_off_rounded,
        title: 'No clinics match your filters',
        message: 'Widen the distance or relax the rating and budget.',
        actionLabel: 'Reset filters',
        actionIcon: Icons.restart_alt_rounded,
        onAction: () => _resetFilters(ref.read(clinicFilterProvider.notifier)),
      );
    }
    return _StatusView(
      icon: Icons.location_off_rounded,
      title: 'No clinics found nearby',
      message: 'We could not find dental clinics in this area. '
          'Use your current location or try again later.',
      actionLabel: 'Use my location',
      actionIcon: Icons.my_location_rounded,
      onAction: () => _getUserLocation(manual: true),
    );
  }
}

// ── Search field ──────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: GlassCard(
        borderRadius: BorderRadius.circular(16),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.navy),
          cursorColor: AppColors.g2,
          decoration: InputDecoration(
            hintText: 'Search by clinic or area',
            hintStyle: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.secondaryText,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: AppColors.g2,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    onPressed: onClear,
                    tooltip: 'Clear search',
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.secondaryText,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          ),
        ),
      ),
    );
  }
}

// ── Location pill ─────────────────────────────────────────────────

class _LocationPill extends StatelessWidget {
  const _LocationPill({required this.precise});

  /// True once the device location is known.
  final bool precise;

  @override
  Widget build(BuildContext context) {
    final color = precise ? AppColors.successGreen : AppColors.secondaryText;
    return Tooltip(
      message: precise
          ? 'Distances are measured from your current location'
          : 'Location unavailable. Distances are approximate',
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppGlass.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              precise
                  ? Icons.my_location_rounded
                  : Icons.location_searching_rounded,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(
              precise ? 'Near you' : 'Approx. area',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Clinic card ───────────────────────────────────────────────────

class _ClinicCard extends StatelessWidget {
  const _ClinicCard({
    required this.clinic,
    required this.distanceKm,
    required this.index,
    this.badge,
  });

  final ClinicModel clinic;
  final double distanceKm;
  final int index;

  /// Optional highlight above the name, e.g. "Closest to you".
  final String? badge;

  @override
  Widget build(BuildContext context) {
    // Cap stagger delay to the first 6 items.
    final animationIndex = index < 6 ? index : 5;
    return TweenAnimationBuilder<double>(
      key: ValueKey(clinic.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: dentraMotion(context, 260 + animationIndex * 45),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 18 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GlassCard(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClinicDetailScreen(
                clinic: clinic,
                distanceKm: distanceKm,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              ClinicAvatar(name: clinic.name, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (badge != null) ...[
                      _Badge(label: badge!),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      clinic.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Distance and rating on one quiet line.
                    Row(
                      children: [
                        _InlineStat(
                          icon: Icons.near_me_rounded,
                          iconColor: AppColors.g2,
                          label: formatClinicDistance(distanceKm),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: _InlineStat(
                            icon: Icons.star_rounded,
                            iconColor: AppColors.warmOrange,
                            label: clinic.reviewCount > 0
                                ? '${clinic.rating.toStringAsFixed(1)} '
                                    '(${clinic.reviewCount})'
                                : 'New',
                          ),
                        ),
                      ],
                    ),
                    if (clinic.address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        clinic.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.secondaryText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.g2.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.g2,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: iconColor),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────

class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Hold still when the user prefers reduced motion.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse
        ..stop()
        ..value = 0.5;
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      sliver: SliverToBoxAdapter(
        child: Semantics(
          label: 'Loading clinics',
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.55, end: 1).animate(_pulse),
            child: Column(
              children: List.generate(
                4,
                (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _SkeletonCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.g2.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return GlassCard(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.g2.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(180, 14),
                    const SizedBox(height: 8),
                    bar(120, 10),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              bar(54, 12),
              const SizedBox(width: 14),
              bar(64, 12),
              const Spacer(),
              bar(70, 14),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Empty / error state ───────────────────────────────────────────

class _StatusView extends StatelessWidget {
  const _StatusView({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH, 12, AppSpacing.screenH, 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: GlassCard(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.white.withValues(alpha: 0.9),
                        AppColors.mintGreen.withValues(alpha: 0.7),
                      ],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppGlass.border),
                  ),
                  child: Icon(icon, size: 28, color: AppColors.g2),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                DentraPillButton(
                  label: actionLabel,
                  icon: actionIcon,
                  variant: DentraButtonVariant.outline,
                  onPressed: onAction,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter sheet ──────────────────────────────────────────────────

class _FilterSheetBody extends ConsumerWidget {
  const _FilterSheetBody();

  static const _radiusOptions = [1.0, 2.0, 3.0, 5.0];
  static const _ratingOptions = [0.0, 3.5, 4.0, 4.5];
  static const _priceOptions = <double?>[null, 1000, 2000, 5000];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(clinicFilterProvider);
    final notifier = ref.read(clinicFilterProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetLabel(icon: Icons.near_me_rounded, text: 'Distance'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final km in _radiusOptions)
              DentraChoiceChip(
                label: 'Within ${km.toStringAsFixed(0)} km',
                selected: filters.radiusKm == km,
                onSelected: () => notifier.setRadiusKm(km),
              ),
          ],
        ),
        const SizedBox(height: 22),
        const _SheetLabel(icon: Icons.star_rounded, text: 'Minimum rating'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final rating in _ratingOptions)
              DentraChoiceChip(
                label: rating == 0 ? 'Any' : '${rating.toStringAsFixed(1)}+',
                selected: filters.minRating == rating,
                onSelected: () => notifier.setMinRating(rating),
              ),
          ],
        ),
        const SizedBox(height: 22),
        const _SheetLabel(
          icon: Icons.payments_rounded,
          text: 'Budget (starting price)',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final price in _priceOptions)
              DentraChoiceChip(
                label: price == null ? 'Any' : 'Up to ${formatPeso(price)}',
                selected: filters.maxPrice == price,
                onSelected: () => notifier.setMaxPrice(price),
              ),
          ],
        ),
        const SizedBox(height: 28),
        DentraButtonRow(
          secondary: DentraPillButton(
            label: 'Reset',
            variant: DentraButtonVariant.outline,
            onPressed: _activeFilterCount(filters) > 0
                ? () => _resetFilters(notifier)
                : null,
          ),
          primary: DentraPillButton(
            label: 'Show clinics',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }
}

class _SheetLabel extends StatelessWidget {
  const _SheetLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.g2),
          const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
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

    final avgLat =
        widget.clinics.map((c) => c.latitude).reduce((a, b) => a + b) /
            widget.clinics.length;
    final avgLng =
        widget.clinics.map((c) => c.longitude).reduce((a, b) => a + b) /
            widget.clinics.length;
    return LatLng(avgLat, avgLng);
  }

  // On web the Maps JavaScript API has to be loaded before the map builds.
  late final Future<void> _mapsReady = ensureMapsLoaded();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: FutureBuilder<void>(
        future: _mapsReady,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done ||
              snapshot.hasError) {
            return const ColoredBox(color: AppColors.lightLavender);
          }
          return GoogleMap(
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
              Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer()),
            },
          );
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
