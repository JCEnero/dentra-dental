import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../screening/data/models/finding_answer.dart';
import '../../data/scan_report.dart';
import '../../data/tooth_guidance.dart';
import '../scan_motion.dart';
import 'mouth_3d.dart';
import 'report_charts.dart';
import 'report_style.dart';
import 'spot_photo.dart';
import 'tooth_card.dart';

/// One marked tooth at a time: the real photo in close on it, a small 3D mouth
/// saying where that is, and everything about that tooth under it. Swipe or use
/// the arrows for the next one, and the big mouth at the top of the page turns
/// with it.
class SignsSection extends StatefulWidget {
  const SignsSection({
    super.key,
    required this.report,
    required this.guidance,
    required this.imageOf,
    required this.focus,
    this.onAnswer,
    this.onLearnMore,
  });

  final ScreeningReport report;

  /// One per sign, in the report's order.
  final List<ToothGuidance> guidance;
  final ImageProvider? Function(String photoId) imageOf;

  /// The sign being shown, shared with the 3D mouth.
  final ValueNotifier<ReportSpot?> focus;

  /// Saves an answer about the finding with this id. Null when answers can't be
  /// saved, which leaves the question out.
  final void Function(String findingId, ToothPain? pain)? onAnswer;

  /// Opens a procedure's page in the Treatment tab.
  final ValueChanged<String>? onLearnMore;

  @override
  State<SignsSection> createState() => _SignsSectionState();
}

class _SignsSectionState extends State<SignsSection> {
  /// A place in the list rather than the sign itself: the page can rebuild the
  /// report at any time, and the choice should survive that.
  int _index = 0;

  List<ReportSpot> get _spots => [for (final g in widget.guidance) g.spot];

  int get _at => _index.clamp(0, widget.guidance.length - 1);

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
    final i = widget.guidance
        .indexWhere((g) => identical(g.spot.finding, spot.finding));
    if (i >= 0 && i != _index) setState(() => _index = i);
  }

  void _step(int by) {
    final next = (_index + by).clamp(0, widget.guidance.length - 1);
    if (next == _index) return;
    setState(() => _index = next);
    widget.focus.value = widget.guidance[next].spot;
  }

  void _open(ImageProvider image, ReportSpot s) {
    openSpotPhoto(
      context,
      image: image,
      caption: '${s.photo.label} · ${s.strength.label}',
      markers: markersIn(_spots, s.photoId, selected: s),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guidance[_at];
    final s = g.spot;
    final image = widget.imageOf(s.photoId);
    final many = widget.guidance.length > 1;
    final work = widget.report.dentalWorkLine;
    final save = widget.onAnswer;
    final findingId = s.finding.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (many) ...[
          StrengthBar(report: widget.report),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -120) _step(1);
            if (v > 120) _step(-1);
          },
          child: GlassCard(
            width: double.infinity,
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (image == null)
                          const MissingPhoto()
                        else
                          Semantics(
                            button: true,
                            label: '${s.photo.label} photo, with the tooth '
                                'marked. Opens full size.',
                            excludeSemantics: true,
                            child: GestureDetector(
                              onTap: () => _open(image, s),
                              child: SpotPhoto(
                                image: image,
                                markers:
                                    markersIn(_spots, s.photoId, selected: s),
                                focus: s.box,
                              ),
                            ),
                          ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          width: 74,
                          height: 74,
                          child: IgnorePointer(
                            child: ClipOval(
                              child: GlassBlur(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color:
                                        AppColors.white.withValues(alpha: 0.8),
                                    border: Border.all(
                                      color: AppColors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: SpotLocator(spot: s),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
                  child: AnimatedSwitcher(
                    duration: ScanMotion.of(context, ScanMotion.fast),
                    child: Semantics(
                      key: ValueKey(_at),
                      container: true,
                      child: ToothDetails(
                        guidance: g,
                        onAnswer: save == null || findingId == null
                            ? null
                            : (pain) => save(findingId, pain),
                        onLearnMore: widget.onLearnMore,
                      ),
                    ),
                  ),
                ),
                if (many)
                  _Pager(
                    index: _at,
                    count: widget.guidance.length,
                    onStep: _step,
                  ),
              ],
            ),
          ),
        ),
        if (work != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'We also saw $work. Those aren\'t counted as signs.',
              style: reportNote,
            ),
          ),
        ],
      ],
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.index,
    required this.count,
    required this.onStep,
  });

  final int index;
  final int count;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    Widget arrow(IconData icon, String tip, int by, bool on) => IconButton(
          onPressed: on ? () => onStep(by) : null,
          tooltip: tip,
          icon: Icon(icon),
          color: AppColors.primary,
          disabledColor: AppColors.g2.withValues(alpha: 0.25),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 40),
          padding: EdgeInsets.zero,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        arrow(Icons.chevron_left_rounded, 'Previous marked tooth', -1,
            index > 0),
        Flexible(
          child: Text(
            '${index + 1} of $count marked teeth',
            textAlign: TextAlign.center,
            style: reportNote,
          ),
        ),
        arrow(Icons.chevron_right_rounded, 'Next marked tooth', 1,
            index < count - 1),
      ],
    );
  }
}
