import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_image_viewer.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../dental_records/widgets/record_source_label.dart';
import '../../scan/data/scan_regions.dart';
import '../../scan/data/scan_report.dart';
import '../../scan/widgets/report/scan_report_view.dart';
import '../../scan/widgets/scan_result_view.dart' show ScanDisclaimer;
import '../../scan/widgets/scan_theme.dart' show ScanIconDisc;
import '../../scan/widgets/visuals/region_visual.dart';
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';

/// Everything recorded for one screening. Shows only stored data: fields
/// the app does not record yet are named as unavailable, never filled in.
class ScreeningDetailScreen extends ConsumerStatefulWidget {
  const ScreeningDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  static Route<void> route(String sessionId) => MaterialPageRoute<void>(
        builder: (_) => ScreeningDetailScreen(sessionId: sessionId),
      );

  @override
  ConsumerState<ScreeningDetailScreen> createState() =>
      _ScreeningDetailScreenState();
}

class _ScreeningDetailScreenState extends ConsumerState<ScreeningDetailScreen> {
  // Last seen record. Deleting removes it from the list right away; keeping
  // it here avoids flashing a "missing" message before the page closes.
  ScreeningSession? _session;
  ScreeningSession? _previous;

  @override
  Widget build(BuildContext context) {
    final sessionId = widget.sessionId;
    final all = ref.watch(screeningSessionsProvider).valueOrNull;
    final index = all?.indexWhere((s) => s.id == sessionId) ?? -1;
    if (index >= 0) {
      _session = all![index];
      // List is newest first, so the previous screening is the next item.
      _previous = index + 1 < all.length ? all[index + 1] : null;
    }
    final session = _session;
    final previous = _previous;
    final images = ref.watch(screeningImageCacheProvider)[sessionId] ?? const {};

    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DentraPageHeader(
                title: 'Screening Details',
                onBack: () => Navigator.of(context).maybePop(),
              ),
              Divider(height: 1, thickness: 1, color: AppGlass.divider),
              Expanded(
                child: session == null
                    ? _Missing(loading: all == null)
                    : _Body(
                        session: session,
                        previous: previous,
                        images: images,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({
    required this.session,
    required this.previous,
    required this.images,
  });

  final ScreeningSession session;
  final ScreeningSession? previous;
  final Map<String, Uint8List> images;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _deleting = false;

  Future<void> _delete() async {
    final confirmed = await showGlassConfirmDialog(
      context: context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete this screening?',
      message: 'It will be removed from your history. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _deleting = true);
    // Captured up front: the optimistic delete removes this record from
    // the list, which unmounts this widget before the request returns.
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final id = widget.session.id;
    try {
      await ref.read(screeningSessionsProvider.notifier).delete(id);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(dentraSnackBar('Screening deleted.'));
      navigator.pop();
    } catch (_) {
      // The notifier restored the record, so this page is back.
      if (mounted) setState(() => _deleting = false);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(dentraSnackBar(
          "Couldn't delete this screening.",
          tone: DentraFeedbackTone.error,
        ));
    }
  }

  ImageProvider? _imageOf(String regionId) {
    if (widget.images[regionId] case final bytes?) return MemoryImage(bytes);
    if (widget.session.captureFor(regionId)?.imageUrl case final url?) {
      return NetworkImage(url);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final analysis = s.analysis;
    final report = analysis == null ||
            analysis.status == AnalysisStatus.pending ||
            analysis.status == AnalysisStatus.failed
        ? null
        : ScreeningReport(analysis, s.capturedRegions);
    // Without a model behind it, a clean result would say nothing.
    final hasReport = report != null && !report.detectorOff;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 20, AppSpacing.screenH,
          32 + MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasReport)
                ScanReportView(
                  report: report,
                  imageOf: _imageOf,
                  status: 'Smart screening',
                  date: DentraDates.long(s.completedAt),
                  at: s.completedAt,
                  saved: s,
                  leading: const ScanIconDisc(
                    Icons.auto_awesome_outlined,
                    size: 44,
                    iconSize: 21,
                  ),
                  sessionId: s.id,
                )
              else ...[
                _Summary(session: s),
                const _SectionTitle('Captured images'),
                _Images(session: s, images: widget.images),
                const _SectionTitle('Regions'),
                _Regions(session: s),
                const _SectionTitle('Screening findings'),
                _Findings(session: s),
              ],
              if (widget.previous != null) ...[
                const _SectionTitle('Compared with previous'),
                _Comparison(current: s, previous: widget.previous!),
              ],
              const SizedBox(height: 20),
              const ScanDisclaimer(),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _deleting ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(44, 44),
                  ),
                  icon: _deleting
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.danger,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(
                    _deleting ? 'Deleting…' : 'Delete this screening',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
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

// ── Sections ────────────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({required this.session});

  final ScreeningSession session;

  @override
  Widget build(BuildContext context) {
    final at = session.completedAt;
    final captured = session.capturedViewCount;
    final complete = session.isComplete;
    final sources = session.captures.map((c) => _sourceLabel(c.source)).toSet();

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      borderColor: AppColors.g2.withValues(alpha: 0.45),
      borderWidth: 1.5,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const RecordSourceHeader(source: RecordSource.aiScreening),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DentraDates.full(at),
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Completed at ${DentraDates.time(at)}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: session.status),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$captured of ${session.totalRegions} views captured',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: session.totalRegions == 0
                  ? 0
                  : captured / session.totalRegions,
              minHeight: 6,
              backgroundColor: AppColors.g2.withValues(alpha: 0.12),
              color: complete ? AppColors.successGreen : AppColors.g2,
            ),
          ),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Captured with: ${sources.join(', ')}',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Images extends StatelessWidget {
  const _Images({required this.session, required this.images});

  final ScreeningSession session;
  final Map<String, Uint8List> images;

  @override
  Widget build(BuildContext context) {
    final tiles = <(String, ImageProvider)>[
      for (final id in session.capturedRegions)
        if (images[id] != null)
          (id, MemoryImage(images[id]!))
        else if (session.captureFor(id)?.imageUrl != null)
          (id, NetworkImage(session.captureFor(id)!.imageUrl!)),
    ];

    if (tiles.isEmpty) {
      return const _Note(
        icon: Icons.image_not_supported_outlined,
        text: "Photos from this screening aren't stored yet. They are kept "
            'only until the app closes, and will appear here once cloud '
            'storage is connected.',
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth > 420 ? 3 : 2;
      const gap = 10.0;
      final size = (c.maxWidth - gap * (columns - 1)) / columns;
      final pixels = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (id, image) in tiles)
            _ImageTile(
              size: size,
              image: image,
              thumbnail: CoverResizeImage(image, pixels),
              label: scanRegionById(id).label,
            ),
        ],
      );
    });
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.size,
    required this.image,
    required this.thumbnail,
    required this.label,
  });

  final double size;

  /// Full resolution, for the zoomable view.
  final ImageProvider image;

  /// Downscaled to the tile, for the grid.
  final ImageProvider thumbnail;
  final String label;

  void _open(BuildContext context) => showDentraImageViewer(
        context,
        image: image,
        caption: 'Smart Screening · $label',
      );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label photo. Opens full size.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => _open(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: thumbnail,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.lightLavender,
                    child: const Icon(Icons.broken_image_outlined,
                        color: AppColors.secondaryText),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    color: AppColors.navy.withValues(alpha: 0.45),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Regions extends StatelessWidget {
  const _Regions({required this.session});

  final ScreeningSession session;

  @override
  Widget build(BuildContext context) {
    final regions = regionsForSession(session.capturedRegions);
    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        children: [
          for (var i = 0; i < regions.length; i++) ...[
            if (i > 0)
              Divider(height: 1, indent: 96, color: AppGlass.divider),
            _RegionRow(region: regions[i], session: session),
          ],
        ],
      ),
    );
  }
}

class _RegionRow extends StatelessWidget {
  const _RegionRow({required this.region, required this.session});

  final ScanRegion region;
  final ScreeningSession session;

  @override
  Widget build(BuildContext context) {
    final captured = session.capturedRegions.contains(region.id);
    final capture = session.captureFor(region.id);

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(
          children: [
            Opacity(
              opacity: captured ? 1 : 0.4,
              child: SizedBox(
                width: 68,
                child: RegionVisual(region: region, compact: true),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    region.label,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    captured
                        ? capture != null
                            ? 'Captured ${DentraDates.time(capture.capturedAt)} · '
                                '${_sourceLabel(capture.source)}'
                            : 'Captured'
                        : 'Not captured',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              captured
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: captured
                  ? AppColors.successGreen
                  : AppColors.secondaryText.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Findings extends StatelessWidget {
  const _Findings({required this.session});

  final ScreeningSession session;

  @override
  Widget build(BuildContext context) {
    final analysis = session.analysis;
    if (analysis == null) {
      return const _Note(
        icon: Icons.auto_awesome_outlined,
        text: 'No analysis was run for this screening, so there are no '
            'findings, tooth annotations or confidence scores to show. Smart '
            "analysis isn't connected yet.",
      );
    }

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.warmOrange.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Smart screening · Not a clinical diagnosis',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF9A5B1E),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            analysis.summary,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.navy,
              height: 1.55,
            ),
          ),
          for (final f in analysis.findings) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppGlass.divider),
            const SizedBox(height: 12),
            _FindingRow(finding: f),
          ],
          const SizedBox(height: 12),
          Text(
            'Analyzed ${DentraDates.medium(analysis.analyzedAt)} at '
            '${DentraDates.time(analysis.analyzedAt)}'
            '${analysis.model != null ? ' · ${analysis.model}' : ''}',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({required this.finding});

  final ScreeningFinding finding;

  @override
  Widget build(BuildContext context) {
    final where = [
      if (finding.regionId != null)
        findScanRegion(finding.regionId!)?.label,
      if (finding.tooth != null) 'Tooth ${finding.tooth}',
    ].whereType<String>().join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                finding.label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              if (where.isNotEmpty || finding.detail != null)
                Text(
                  [where, finding.detail].whereType<String>()
                      .where((t) => t.isNotEmpty)
                      .join(' — '),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    height: 1.4,
                  ),
                ),
            ],
          ),
        ),
        // Only a confidence the service actually reported.
        if (finding.confidence != null)
          Text(
            '${(finding.confidence! * 100).round()}% confidence',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.g2,
            ),
          ),
      ],
    );
  }
}

class _Comparison extends StatelessWidget {
  const _Comparison({required this.current, required this.previous});

  final ScreeningSession current;
  final ScreeningSession previous;

  @override
  Widget build(BuildContext context) {
    final now = current.capturedRegions.toSet();
    final before = previous.capturedRegions.toSet();
    String names(Iterable<String> ids) =>
        ids.map((id) => scanRegionById(id).label).join(', ');
    final added = now.difference(before);
    final missing = before.difference(now);
    final days = DentraDates.dateOnly(current.completedAt)
        .difference(DentraDates.dateOnly(previous.completedAt))
        .inDays;

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context)
          .pushReplacement(ScreeningDetailScreen.route(previous.id)),
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${DentraDates.medium(previous.completedAt)} · '
                  '${days == 0 ? 'same day' : '$days ${days == 1 ? 'day' : 'days'} earlier'}',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${previous.capturedViewCount} of ${previous.totalRegions} views then, '
                  '${current.capturedViewCount} of ${current.totalRegions} now.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
                if (added.isNotEmpty)
                  Text(
                    'New this time: ${names(added)}',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.secondaryText),
                  ),
                if (missing.isNotEmpty)
                  Text(
                    'Not captured this time: ${names(missing)}',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppColors.secondaryText),
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.secondaryText),
        ],
      ),
    );
  }
}

// ── Small pieces ────────────────────────────────────────────────────────────

String _sourceLabel(String source) => switch (source) {
      'device' => 'DENTRA device',
      'photoLibrary' => 'Photo library',
      _ => 'Camera',
    };

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final ScreeningStatus status;

  @override
  Widget build(BuildContext context) {
    final complete = status == ScreeningStatus.complete;
    final color = complete ? AppColors.successGreen : AppColors.warmOrange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      tint: AppColors.lightLavender,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.g2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.navy,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'This screening is no longer in your history.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}
