import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/dentra_image_viewer.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../data/scan_regions.dart';
import '../../data/scan_report.dart';
import '../scan_motion.dart';
import '../scan_theme.dart';
import 'report_style.dart';
import 'spot_photo.dart';

/// How often signs at each strength matched decay dentists had marked, on
/// held-out photos with and without decay. Keep in step with
/// ml/inference/models/caries/report.json.
const Map<SignStrength, String> signMeaning = {
  SignStrength.strong: 'In our tests, about 9 in 10 of these were real decay.',
  SignStrength.possible:
      'In our tests, about 6 in 10 of these were real decay.',
  SignStrength.faint: 'In our tests, about 5 in 10 of these were real decay. '
      'Mention it to a dentist if it keeps showing up.',
};

/// The real photos, in close on each sign, above how sure the model was about
/// each one. The photo is the actual tooth map: it can't get someone's mouth
/// wrong, whatever teeth they have.
class SignsSection extends StatefulWidget {
  const SignsSection({
    super.key,
    required this.report,
    required this.imageOf,
    required this.focus,
  });

  final ScreeningReport report;
  final ImageProvider? Function(String photoId) imageOf;

  /// Set from elsewhere on the page to show a particular sign.
  final ValueNotifier<ReportSpot?> focus;

  @override
  State<SignsSection> createState() => _SignsSectionState();
}

class _SignsSectionState extends State<SignsSection> {
  /// A place in the list rather than the sign itself: the page can rebuild the
  /// report at any time, and the choice should survive that.
  int _index = 0;

  ReportSpot get _selected {
    final spots = widget.report.spots;
    return spots[_index.clamp(0, spots.length - 1)];
  }

  @override
  void initState() {
    super.initState();
    widget.focus.addListener(_onFocus);
  }

  @override
  void dispose() {
    widget.focus.removeListener(_onFocus);
    super.dispose();
  }

  void _onFocus() {
    final spot = widget.focus.value;
    if (spot == null) return;
    final i = widget.report.spots
        .indexWhere((s) => identical(s.finding, spot.finding));
    if (i >= 0) setState(() => _index = i);
  }

  void _open(ImageProvider image) {
    final s = _selected;
    openSpotPhoto(
      context,
      image: image,
      caption: '${s.photo.label} · ${s.strength.label}',
      markers: markersIn(widget.report.spots, s.photoId, selected: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spots = widget.report.spots;
    final s = _selected;
    final image = widget.imageOf(s.photoId);
    final photos = widget.report.photosWithSigns;
    final rows = spots.where((o) => o.photoId == s.photoId).toList();

    return GlassCard(
      width: double.infinity,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: image == null
                  ? const MissingPhoto()
                  : Semantics(
                      button: true,
                      label: '${s.photo.label} photo, with the sign marked. '
                          'Opens full size.',
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => _open(image),
                        child: SpotPhoto(
                          image: image,
                          markers: markersIn(spots, s.photoId, selected: s),
                          focus: s.box,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  rows.length > 1
                      ? '${s.photo.label} · ${rows.length} signs in this photo'
                      : s.photo.label,
                  style: reportNote,
                ),
                if (photos.length > 1) ...[
                  const SizedBox(height: 8),
                  _Filmstrip(
                    photos: photos,
                    current: s.photoId,
                    spots: spots,
                    imageOf: widget.imageOf,
                    onSelect: (id) => setState(() {
                      _index = spots.indexWhere((o) => o.photoId == id);
                    }),
                  ),
                ],
                const SizedBox(height: 8),
                for (final o in rows)
                  _SignRow(
                    spot: o,
                    // Same words twice can't be told apart without this.
                    detail: rows.where((r) => r.where == o.where).length > 1
                        ? o.sideOfPhoto
                        : null,
                    selected: identical(o, s),
                    onTap: () => setState(() => _index = spots.indexOf(o)),
                  ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: ScanMotion.of(context, ScanMotion.fast),
                  child: Text(
                    key: ValueKey(s.strength),
                    '${s.strength.label}. ${signMeaning[s.strength]}',
                    style: reportBody,
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

/// The other photos with a sign in them. Each sign's row stays with its photo,
/// so two signs in the same general area can still be told apart.
class _Filmstrip extends StatelessWidget {
  const _Filmstrip({
    required this.photos,
    required this.current,
    required this.spots,
    required this.imageOf,
    required this.onSelect,
  });

  final List<String> photos;
  final String current;
  final List<ReportSpot> spots;
  final ImageProvider? Function(String photoId) imageOf;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final id in photos)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilmstripPhoto(
                region: findScanRegion(id)!,
                image: imageOf(id),
                count: spots.where((s) => s.photoId == id).length,
                selected: id == current,
                onTap: () => onSelect(id),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilmstripPhoto extends StatelessWidget {
  const _FilmstripPhoto({
    required this.region,
    required this.image,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final ScanRegion region;
  final ImageProvider? image;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final photo = image;
    return Semantics(
      button: true,
      selected: selected,
      label: '${region.label}, $count ${count == 1 ? 'sign' : 'signs'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: ScanMotion.of(context, ScanMotion.fast),
          width: 58,
          height: 58,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              width: 2,
              color: selected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: photo == null
                ? const MissingPhoto()
                : DentraCoverImage(image: photo),
          ),
        ),
      ),
    );
  }
}

/// One sign: where it is and a bar for how sure the model was. A gap in the
/// track marks where a sign turns strong.
class _SignRow extends StatelessWidget {
  const _SignRow({
    required this.spot,
    required this.detail,
    required this.selected,
    required this.onTap,
  });

  final ReportSpot spot;

  /// Added to the area's name, e.g. "left of photo".
  final String? detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = spot.percent;
    final where = detail == null ? spot.where : '${spot.where}, $detail';
    return Semantics(
      button: true,
      selected: selected,
      label: '$where, ${spot.strength.label}'
          '${percent == null ? '' : ', $percent percent confidence'}',
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: ScanMotion.of(context, ScanMotion.fast),
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected
                  ? AppColors.lightLavender
                  : AppColors.lightLavender.withValues(alpha: 0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Side by side while they fit, one above the other at large text.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  children: [
                    Text(
                      where,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      [
                        spot.strength.label.split(' ').first,
                        if (percent != null) '$percent%',
                      ].join(' · '),
                      style: figureText(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _ConfidenceBar(
                  value: spot.finding.confidence ?? 0,
                  color: ReportColors.ofSign(spot.strength),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  const _ConfidenceBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: ScanMotion.of(context, const Duration(milliseconds: 700)),
      curve: ScanMotion.curve,
      builder: (context, v, _) => SizedBox(
        height: 6,
        child: CustomPaint(painter: _ConfidencePainter(v, color)),
      ),
    );
  }
}

class _ConfidencePainter extends CustomPainter {
  const _ConfidencePainter(this.value, this.color);

  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = AppColors.navy.withValues(alpha: 0.08),
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, r));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * value, size.height),
      Paint()..color = color,
    );
    canvas.restore();
    // Where a sign turns strong.
    final x = size.width * SignStrength.strongFrom;
    canvas.drawRect(
      Rect.fromLTWH(x - 1, 0, 2, size.height),
      Paint()..color = AppColors.white,
    );
  }

  @override
  bool shouldRepaint(_ConfidencePainter old) =>
      old.value != value || old.color != color;
}
