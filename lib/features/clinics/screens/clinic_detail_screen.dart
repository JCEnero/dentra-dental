import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../clinic_finder/data/models/clinic_model.dart';
import '../widgets/clinic_ui.dart';

/// Detail page for one clinic.
///
/// Name with a single rating and distance line, the service price list
/// and contact details. The top bar starts clear and frosts over, showing
/// the name, once the title scrolls away. Call and Directions stay docked
/// at the bottom.
class ClinicDetailScreen extends StatefulWidget {
  final ClinicModel clinic;

  /// Distance from the user, in kilometers. Null when unknown.
  final double? distanceKm;

  const ClinicDetailScreen({
    super.key,
    required this.clinic,
    this.distanceKm,
  });

  @override
  State<ClinicDetailScreen> createState() => _ClinicDetailScreenState();
}

class _ClinicDetailScreenState extends State<ClinicDetailScreen> {
  static const double _barHeight = 60;

  final ScrollController _scroll = ScrollController();

  // 0 at rest, 1 once the header title is under the bar.
  final ValueNotifier<double> _collapse = ValueNotifier(0);

  ClinicModel get _clinic => widget.clinic;

  bool get _hasPhone {
    final digits = _clinic.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    return digits.length >= 7;
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      // The title sits just under the bar; fade the bar in as it passes.
      final t = ((_scroll.offset - 20) / 48).clamp(0.0, 1.0);
      if (t != _collapse.value) _collapse.value = t;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _collapse.dispose();
    super.dispose();
  }

  Future<void> _call() async {
    final uri = Uri(
      scheme: 'tel',
      path: _clinic.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), ''),
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      showDentraSnack(context, 'Could not open the phone dialer.',
          tone: DentraFeedbackTone.error);
    }
  }

  Future<void> _directions() async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${_clinic.latitude},${_clinic.longitude}',
    });
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      showDentraSnack(context, 'Could not open maps.',
          tone: DentraFeedbackTone.error);
    }
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showDentraSnack(context, '$what copied');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final services = [..._clinic.services]
      ..sort((a, b) => a.price.compareTo(b.price));

    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scroll,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.screenH,
                      media.padding.top + _barHeight + 8,
                      AppSpacing.screenH,
                      0,
                    ),
                    child: _Header(
                      clinic: _clinic,
                      distanceKm: widget.distanceKm,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.screenH,
                    32,
                    AppSpacing.screenH,
                    112 + media.padding.bottom,
                  ),
                  sliver: SliverList.list(
                    children: [
                      // Prices come from public listings, so label them
                      // quietly as estimates rather than with a banner.
                      const _SectionTitle(
                        'Services',
                        trailing: 'Est. public rates',
                      ),
                      const SizedBox(height: 10),
                      _ServicesCard(services: services),
                      const SizedBox(height: 28),
                      const _SectionTitle('Contact'),
                      const SizedBox(height: 10),
                      GlassCard(
                        borderRadius: BorderRadius.circular(18),
                        child: Column(
                          children: [
                            _ContactRow(
                              label: 'Phone',
                              value: _hasPhone
                                  ? _clinic.phoneNumber
                                  : 'Not available',
                              onTap: _hasPhone ? _call : null,
                              onCopy: _hasPhone
                                  ? () => _copy(_clinic.phoneNumber, 'Number')
                                  : null,
                            ),
                            if (_clinic.address.isNotEmpty) ...[
                              const _Hairline(),
                              _ContactRow(
                                label: 'Address',
                                value: _clinic.address,
                                onTap: _directions,
                                onCopy: () => _copy(_clinic.address, 'Address'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Top bar, drawn over the content.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _TopBar(
                height: _barHeight,
                collapse: _collapse,
                title: _clinic.name,
                onBack: () => Navigator.of(context).maybePop(),
              ),
            ),

            // Docked actions.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GlassBar(
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenH, 14, AppSpacing.screenH, 14),
                    child: DentraButtonRow(
                      secondary: DentraPillButton(
                        label: 'Call',
                        icon: Icons.call_rounded,
                        variant: DentraButtonVariant.outline,
                        onPressed: _hasPhone ? _call : null,
                      ),
                      primary: DentraPillButton(
                        label: 'Directions',
                        icon: Icons.directions_rounded,
                        onPressed: _directions,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top bar: clear at rest, frosted with the title once scrolled
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.height,
    required this.collapse,
    required this.title,
    required this.onBack,
  });

  final double height;
  final ValueNotifier<double> collapse;
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ValueListenableBuilder<double>(
      valueListenable: collapse,
      builder: (context, t, _) {
        final bar = SizedBox(
          height: top + height,
          child: Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.screenH - 4, top, 16, 0),
            child: Row(
              children: [
                DentraBackButton(onPressed: onBack),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    opacity: t,
                    child: ExcludeSemantics(
                      // The header title already announces the page.
                      excluding: t < 1,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        if (t == 0) return bar;
        return ClipRect(
          child: GlassBlur(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color:
                    AppGlass.barFill.withValues(alpha: AppGlass.barFill.a * t),
                border: Border(
                  bottom: BorderSide(
                    color: AppGlass.divider.withValues(
                      alpha: AppGlass.divider.a * t,
                    ),
                  ),
                ),
              ),
              child: bar,
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header: name, then rating and distance on one quiet line
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.clinic, required this.distanceKm});

  final ClinicModel clinic;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final rated = clinic.reviewCount > 0;
    final rating = clinic.rating.toStringAsFixed(1);
    final reviews =
        '${clinic.reviewCount} ${clinic.reviewCount == 1 ? 'review' : 'reviews'}';
    final distance = distanceKm != null ? formatClinicDistance(distanceKm) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            clinic.name,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Semantics(
          label: [
            rated ? 'Rated $rating from $reviews' : 'No reviews yet',
            if (distance != null) '$distance away',
          ].join(', '),
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.secondaryText,
              ),
              children: [
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: AppColors.warmOrange,
                  ),
                ),
                if (rated) ...[
                  TextSpan(
                    text: ' $rating',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  TextSpan(text: ' ($reviews)'),
                ] else
                  const TextSpan(text: ' No reviews yet'),
                if (distance != null) TextSpan(text: '   ·   $distance away'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sections
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryText,
            ),
          ),
      ],
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppGlass.divider,
    );
  }
}

/// Services in one glass card, cheapest first. Shows the first few and
/// lets the user expand, since the listing may not be complete.
class _ServicesCard extends StatefulWidget {
  const _ServicesCard({required this.services});

  final List<ClinicService> services;

  @override
  State<_ServicesCard> createState() => _ServicesCardState();
}

class _ServicesCardState extends State<_ServicesCard> {
  static const _previewCount = 5;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final services = widget.services;
    if (services.isEmpty) {
      return GlassCard(
        width: double.infinity,
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(16),
        child: Text(
          'No listed rates yet. Call the clinic to ask what they offer.',
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.secondaryText,
            height: 1.45,
          ),
        ),
      );
    }

    final canExpand = services.length > _previewCount;
    final shown =
        _expanded || !canExpand ? services : services.take(_previewCount);

    return GlassCard(
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          for (final (i, service) in shown.indexed) ...[
            if (i > 0) const _Hairline(),
            MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 15),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.name,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // "~" keeps the estimate hint subtle.
                    Semantics(
                      label: 'about ${formatPeso(service.price)}',
                      excludeSemantics: true,
                      child: Text(
                        '~${formatPeso(service.price)}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (canExpand) ...[
            const _Hairline(),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(18)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _expanded ? 'Show less' : 'Show more',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.g2,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 18,
                      color: AppColors.g2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Contact line: label and value, tappable, with a copy button.
class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: onTap != null
                            ? AppColors.navy
                            : AppColors.secondaryText,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (onCopy != null)
                IconButton(
                  onPressed: onCopy,
                  tooltip: 'Copy ${label.toLowerCase()}',
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: AppColors.secondaryText,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
