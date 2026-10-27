import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../clinic_finder/data/models/clinic_model.dart';
import '../../clinic_finder/providers/clinic_provider.dart';
import '../widgets/clinic_map.dart';
import '../widgets/clinic_ui.dart';
import 'clinic_detail_screen.dart';

/// Default search radius, matching [ClinicFilterState.radiusKm].
const double _kDefaultRadiusKm = 5.0;

/// Below this body height (e.g. keyboard open) the map folds away so
/// the list keeps enough room.
const double _kMinHeightForMap = 420;

/// Number of filters (and a non-default sort) that differ from their defaults.
int _activeFilterCount(ClinicFilterState f) =>
    (f.radiusKm != _kDefaultRadiusKm ? 1 : 0) +
    (f.minRating > 0 ? 1 : 0) +
    (f.maxPrice != null ? 1 : 0) +
    (f.sort != ClinicSort.nearest ? 1 : 0);

/// Clears distance, rating, budget and sort but keeps the search text,
/// which [ClinicFilterNotifier.reset] would also wipe.
void _resetFilters(ClinicFilterNotifier notifier) {
  notifier
    ..setRadiusKm(_kDefaultRadiusKm)
    ..setMinRating(0)
    ..setMaxPrice(null)
    ..setSort(ClinicSort.nearest);
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
  final TextEditingController _searchController = TextEditingController();

  /// Lets a pin tap scroll its card into view.
  final Map<String, GlobalKey> _cardKeys = {};

  bool _locating = false;

  /// True once the device location is known.
  bool _precise = false;

  /// Clinic picked on the map; its pin and card are highlighted.
  String? _selectedId;

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
      setState(() => _precise = true);

      // Update the logic layer's location; the clinic list and map follow.
      ref.read(userLocationProvider.notifier).setLocation(
            latitude: position.latitude,
            longitude: position.longitude,
          );
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
      subtitle: 'Narrow and sort the list by distance, rating and budget.',
      builder: (_) => const _FilterSheetBody(),
    );
  }

  /// Highlights a clinic picked on the map and brings its card into view.
  void _selectFromMap(ClinicModel clinic) {
    setState(() => _selectedId = clinic.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cardContext = _cardKeys[clinic.id]?.currentContext;
      if (cardContext == null || !cardContext.mounted) return;
      Scrollable.ensureVisible(
        cardContext,
        alignment: 0.1,
        duration: dentraMotion(cardContext, 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _openClinic(ClinicModel clinic, double distanceKm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClinicDetailScreen(
          clinic: clinic,
          distanceKm: distanceKm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filters = ref.watch(clinicFilterProvider);
    final location = ref.watch(userLocationProvider);
    final clinicsAsync = ref.watch(filteredClinicsProvider);
    final filterCount = _activeFilterCount(filters);

    // One list, already filtered and sorted, drives both the pins and the cards.
    final sorted = clinicsAsync.valueOrNull ?? const <ClinicModel>[];

    // The app shell keeps hidden tabs built. Only mount the map while
    // this tab shows, so it never lingers behind other tabs on web.
    final tabVisible = Visibility.of(context);

    return Column(
      children: [
        // ── HEADER ─────────────────────────────────────────────
        SafeArea(
          bottom: false,
          child: DentraPageHeader(
            title: 'Clinics Nearby',
            onBack: widget.onBack,
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

        // ── BODY ───────────────────────────────────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final mapHeight = constraints.maxHeight < _kMinHeightForMap
                  ? 0.0
                  : (constraints.maxHeight * 0.4).clamp(200.0, 320.0);

              return Column(
                children: [
                  if (tabVisible)
                    // Sized rather than removed when folded, so the map
                    // isn't reloaded each time the keyboard opens.
                    AnimatedContainer(
                      duration: dentraMotion(context, 240),
                      curve: Curves.easeOutCubic,
                      height: mapHeight,
                      margin: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenH),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppGlass.divider),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ClinicMap(
                          clinics: sorted,
                          center: location,
                          radiusKm: filters.radiusKm,
                          showUser: _precise,
                          selectedId: _selectedId,
                          onClinicTap: _selectFromMap,
                          onMapTap: () => setState(() => _selectedId = null),
                          overlay: ClinicGlassIconButton(
                            icon: Icons.my_location_rounded,
                            tooltip: 'Use my current location',
                            busy: _locating,
                            onPressed: () => _getUserLocation(manual: true),
                          ),
                        ),
                      ),
                    ),
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
                                message:
                                    'Check your connection, then try again.',
                                actionLabel: 'Try again',
                                onAction: _refresh,
                              ),
                            ),
                          ],
                          data: (_) => sorted.isEmpty
                              ? [
                                  _toolbar(count: 0, filters: filters),
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: _emptyState(filters, filterCount),
                                  ),
                                ]
                              : [
                                  _toolbar(
                                      count: sorted.length, filters: filters),
                                  _clinicList(sorted, location),
                                  const SliverToBoxAdapter(
                                      child: SizedBox(height: 24)),
                                ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Cards in a plain column: Places returns at most 20 clinics, and
  /// building them all lets a pin tap scroll to any card.
  Widget _clinicList(List<ClinicModel> sorted, UserLocation location) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
      sliver: SliverToBoxAdapter(
        child: Column(
          children: [
            for (var i = 0; i < sorted.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _ClinicCard(
                key: _cardKeys.putIfAbsent(sorted[i].id, GlobalKey.new),
                clinic: sorted[i],
                index: i,
                distanceKm: _distanceKm(location, sorted[i]),
                selected: sorted[i].id == _selectedId,
                onTap: () => _openClinic(
                  sorted[i],
                  _distanceKm(location, sorted[i]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Result count above the list.
  Widget _toolbar({required int? count, required ClinicFilterState filters}) {
    final String summary;
    if (count == null) {
      summary = 'Finding clinics…';
    } else if (filters.searchQuery.isNotEmpty) {
      summary = '$count ${count == 1 ? 'result' : 'results'}';
    } else {
      summary = '$count ${count == 1 ? 'clinic' : 'clinics'} within '
          '${filters.radiusKm.toStringAsFixed(0)} km';
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH, 16, AppSpacing.screenH, 12),
        child: Semantics(
          liveRegion: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary,
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              if (!_precise && !_locating)
                Text(
                  'Approximate distances',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState(ClinicFilterState filters, int filterCount) {
    if (filters.searchQuery.isNotEmpty) {
      return _StatusView(
        icon: Icons.search_off_rounded,
        title: 'No results for "${filters.searchQuery}"',
        message: 'Try a different name or area.',
        actionLabel: 'Clear search',
        onAction: _clearSearch,
      );
    }
    if (filterCount > 0) {
      return _StatusView(
        icon: Icons.filter_alt_off_rounded,
        title: 'No clinics match your filters',
        message: 'Widen the distance or relax the rating and budget.',
        actionLabel: 'Reset filters',
        onAction: () => _resetFilters(ref.read(clinicFilterProvider.notifier)),
      );
    }
    return _StatusView(
      icon: Icons.location_off_rounded,
      title: 'No clinics found nearby',
      message: 'Use your current location or try again later.',
      actionLabel: 'Use my location',
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

// ── Clinic card ───────────────────────────────────────────────────

class _ClinicCard extends StatelessWidget {
  const _ClinicCard({
    super.key,
    required this.clinic,
    required this.index,
    required this.distanceKm,
    required this.selected,
    required this.onTap,
  });

  final ClinicModel clinic;

  /// Position in the list, used to stagger the entry animation.
  final int index;
  final double distanceKm;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = formatClinicDistance(distanceKm);
    final rated = clinic.reviewCount > 0;
    final rating = clinic.rating.toStringAsFixed(1);
    final meta = GoogleFonts.outfit(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppColors.secondaryText,
    );

    // Cap stagger delay to the first 6 items.
    final animationIndex = index < 6 ? index : 5;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: dentraMotion(context, 260 + animationIndex * 45),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 14 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: GlassCard(
        borderRadius: BorderRadius.circular(18),
        borderColor: selected ? AppColors.g2 : null,
        borderWidth: selected ? 1.5 : 1,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              _InitialsTile(name: clinic.name, selected: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    const SizedBox(height: 3),
                    Semantics(
                      label: rated
                          ? '$distance away, rated $rating from '
                              '${clinic.reviewCount} reviews'
                          : '$distance away, no reviews yet',
                      excludeSemantics: true,
                      child: Text.rich(
                        TextSpan(
                          style: meta,
                          children: [
                            TextSpan(text: '$distance   ·   '),
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: AppColors.warmOrange,
                              ),
                            ),
                            TextSpan(
                              text: rated
                                  ? ' $rating (${clinic.reviewCount})'
                                  : ' New',
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

/// Soft mint tile with the clinic's initials, the same as its map pin.
/// Turns teal when the clinic is picked on the map.
class _InitialsTile extends StatelessWidget {
  const _InitialsTile({required this.name, required this.selected});

  final String name;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedContainer(
        duration: dentraMotion(context, 200),
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected
              ? AppColors.cardGradient
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.white.withValues(alpha: 0.9),
                    AppColors.mintGreen.withValues(alpha: 0.6),
                  ],
                ),
          border: Border.all(
            color: selected ? AppColors.g2 : AppGlass.border,
          ),
        ),
        child: Text(
          clinicInitials(name),
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.white : AppColors.g2,
            letterSpacing: -0.4,
          ),
        ),
      ),
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
                  padding: EdgeInsets.only(bottom: 10),
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
    final fill = AppColors.g2.withValues(alpha: 0.1);
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(6),
          ),
        );

    return GlassCard(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(170, 13),
              const SizedBox(height: 8),
              bar(110, 10),
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
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH, 8, AppSpacing.screenH, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: AppColors.g2),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13.5,
                  color: AppColors.secondaryText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              DentraPillButton(
                label: actionLabel,
                variant: DentraButtonVariant.outline,
                onPressed: onAction,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter sheet ──────────────────────────────────────────────────

class _FilterSheetBody extends ConsumerWidget {
  const _FilterSheetBody();

  /// Tops out at [kClinicFetchRadiusKm], the area Places is searched over.
  static const _radiusOptions = [1.0, 3.0, 5.0, kClinicFetchRadiusKm];
  static const _ratingOptions = [0.0, 3.5, 4.0, 4.5];
  static const _priceOptions = <double?>[null, 500, 1000, 1500];
  static const _sortOptions = {
    ClinicSort.nearest: 'Nearest',
    ClinicSort.topRated: 'Top rated',
    ClinicSort.lowestPrice: 'Lowest est. price',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(clinicFilterProvider);
    final notifier = ref.read(clinicFilterProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SheetLabel(icon: Icons.sort_rounded, text: 'Sort by'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _sortOptions.entries)
              DentraChoiceChip(
                label: entry.value,
                selected: filters.sort == entry.key,
                onSelected: () => notifier.setSort(entry.key),
              ),
          ],
        ),
        const SizedBox(height: 22),
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
          text: 'Budget (estimated starting price)',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final price in _priceOptions)
              DentraChoiceChip(
                label:
                    price == null ? 'Any' : 'Est. up to ${formatPeso(price)}',
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
