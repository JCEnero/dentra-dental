import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/tooth_catalog.dart';
import '../geometry/dentition_builder.dart';
import '../state/explorer_camera.dart';
import '../state/explorer_controller.dart';
import '../widgets/dental_viewport.dart';
import '../widgets/explorer_guide_sheet.dart';
import '../widgets/tooth_chart.dart';
import '../widgets/tooth_info_panel.dart';
import '../widgets/viewer_controls.dart';

typedef DentitionLoader = Future<DentitionAssets> Function();

/// Builds the meshes off the UI thread (on web, `compute` runs inline).
Future<DentitionAssets> _loadInBackground() =>
    compute(buildDentitionAssets, null);

/// Dental Explorer: an interactive 3D model of the full permanent
/// dentition with FDI numbering and per-tooth education.
class DentalExplorerScreen extends StatefulWidget {
  const DentalExplorerScreen({
    super.key,
    this.loadModel = _loadInBackground,
    this.markedTeeth = const {},
    this.historyBuilder,
  });

  /// Builds the 3D model. Tests can pass a synchronous builder.
  final DentitionLoader loadModel;

  /// FDI numbers marked on the chart as having history items.
  final Set<int> markedTeeth;

  /// Content of the info panel's History tab; no tab when null. Supplied
  /// by the history feature, so the explorer itself stays data-free.
  final Widget Function(ToothInfo tooth)? historyBuilder;

  @override
  State<DentalExplorerScreen> createState() => _DentalExplorerScreenState();
}

class _DentalExplorerScreenState extends State<DentalExplorerScreen> {
  final _controller = ExplorerController();
  final _camera = ExplorerCamera();
  late Future<DentitionAssets> _model;

  bool _renderFailed = false;
  bool _interacted = false;

  @override
  void initState() {
    super.initState();
    _model = widget.loadModel();
  }

  @override
  void dispose() {
    _controller.dispose();
    _camera.dispose();
    super.dispose();
  }

  void _retry() => setState(() {
        _renderFailed = false;
        _model = widget.loadModel();
      });

  void _select(ToothInfo tooth, {required bool focus}) {
    _controller.select(tooth);
    if (focus) _camera.focusTooth(tooth.index);
  }

  void _onViewerTap(ToothInfo? tooth) {
    // Tapping keeps the camera where it is.
    if (tooth == null) {
      _controller.clearSelection();
    } else {
      _select(tooth, focus: false);
    }
  }

  void _setRegion(ExplorerRegion region) {
    _controller.setRegion(region);
    _camera.showRegion(region);
  }

  void _markInteracted() {
    if (!_interacted) setState(() => _interacted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            return ListenableBuilder(
              listenable: _controller,
              builder: (context, _) => _layout(constraints.maxHeight),
            );
          }),
        ),
      ),
    );
  }

  Widget _layout(double height) {
    final selected = _controller.selected;
    // The region bar steps aside while reading, giving the taller info
    // panel room without squeezing the 3D view.
    final showRegions = selected == null;
    final panelHeight = (height * 0.5).clamp(330.0, 500.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DentraPageHeader(
          title: 'Dental Explorer',
          onBack: () => Navigator.of(context).maybePop(),
          trailing: IconButton(
            onPressed: () => showExplorerGuide(context),
            tooltip: 'Guide',
            style: IconButton.styleFrom(
              backgroundColor: AppColors.lightLavender,
              foregroundColor: AppColors.navy,
              fixedSize: const Size(44, 44),
            ),
            icon: const Icon(Icons.menu_book_rounded, size: 20),
          ),
        ),
        AnimatedSize(
          duration: dentraMotion(context, 220),
          curve: Curves.easeOutCubic,
          child: showRegions
              ? Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RegionBar(
                    region: _controller.region,
                    onChanged: _setRegion,
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: _viewerCard(),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, 0, AppSpacing.screenH, 12),
          child: AnimatedSize(
            duration: dentraMotion(context, 260),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: dentraMotion(context, 220),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: selected == null
                  ? ToothChart(
                      key: const ValueKey('chart'),
                      controller: _controller,
                      markedTeeth: widget.markedTeeth,
                      onSelect: (t) => _select(t, focus: true),
                      onOpenGuide: () => showExplorerGuide(context),
                    )
                  : SizedBox(
                      key: const ValueKey('info'),
                      height: panelHeight,
                      child: ToothInfoPanel(
                        tooth: selected,
                        previous: _controller.neighbour(selected, -1),
                        next: _controller.neighbour(selected, 1),
                        onClose: _controller.clearSelection,
                        onPrevious: () => _select(
                            _controller.neighbour(selected, -1),
                            focus: true),
                        onNext: () => _select(
                            _controller.neighbour(selected, 1),
                            focus: true),
                        onFocus: () => _camera.focusTooth(selected.index),
                        historyBuilder: widget.historyBuilder,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _viewerCard() {
    return GlassCard(
      borderRadius: BorderRadius.circular(28),
      borderWidth: 1.5,
      child: FutureBuilder<DentitionAssets>(
        future: _model,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ViewerMessage(
              icon: Icons.error_outline_rounded,
              title: "Couldn't build the 3D model",
              message: 'Something went wrong while preparing the teeth. '
                  'The tooth chart below still works.',
              onRetry: _retry,
            );
          }
          if (!snapshot.hasData) return const _ViewerLoading();
          if (_renderFailed) {
            return _ViewerMessage(
              icon: Icons.view_in_ar_outlined,
              title: '3D view unavailable',
              message: "This device couldn't draw the 3D model. You can "
                  'still explore every tooth with the chart below.',
              onRetry: _retry,
            );
          }
          return _viewer(snapshot.requireData);
        },
      ),
    );
  }

  Widget _viewer(DentitionAssets assets) {
    final c = _controller;
    // Desktop (including desktop browsers) has a mouse, not pinch.
    final touch = switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
    final String? hint = c.selected != null
        ? null
        : (!_interacted
            ? (touch
                ? 'Drag to rotate · pinch to zoom'
                : 'Drag to rotate · scroll to zoom')
            : 'Tap any tooth to learn about it');

    return LayoutBuilder(builder: (context, constraints) {
      // Short touch viewers (small phones with the panel open) keep only
      // the reset button; pinch still zooms. With a mouse the zoom buttons
      // stay. A very short viewer (panel expanded) shows just the model,
      // still fully interactive.
      final compact = touch && constraints.maxHeight < 340;
      final tiny = constraints.maxHeight < 220;
      return Stack(
        children: [
          Positioned.fill(
            child: DentalViewport(
              assets: assets,
              controller: c,
              camera: _camera,
              onToothTap: _onViewerTap,
              onInteract: _markInteracted,
              onRenderFailed: (_) => setState(() => _renderFailed = true),
            ),
          ),
          if (!tiny) ...[
            // Top right: display toggles.
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                children: [
                  ViewerIconButton(
                    icon: Icons.tag_rounded,
                    tooltip: 'Tooth numbers',
                    active: c.showNumbers,
                    onPressed: c.toggleNumbers,
                  ),
                  const SizedBox(width: 8),
                  ViewerIconButton(
                    icon: Icons.palette_outlined,
                    tooltip: 'Colour by type',
                    active: c.colorByType,
                    onPressed: c.toggleColorByType,
                  ),
                  const SizedBox(width: 8),
                  ViewerIconButton(
                    icon: Icons.layers_outlined,
                    tooltip: c.showGums ? 'Hide gums' : 'Show gums',
                    active: c.showGums,
                    onPressed: c.toggleGums,
                  ),
                ],
              ),
            ),
            // Bottom right: zoom and reset.
            Positioned(
              right: 12,
              bottom: 58,
              child: ViewerButtonColumn(children: [
                if (!compact) ...[
                  ViewerIconButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom in',
                    onPressed: () => _camera.zoomBy(1.35),
                  ),
                  ViewerIconButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Zoom out',
                    onPressed: () => _camera.zoomBy(1 / 1.35),
                  ),
                ],
                ViewerIconButton(
                  icon: Icons.restart_alt_rounded,
                  tooltip: 'Reset view',
                  onPressed: () {
                    _setRegion(ExplorerRegion.all);
                    _camera.reset();
                  },
                ),
              ]),
            ),
            // Bottom left: type legend and coaching hint.
            Positioned(
              left: 12,
              right: 68,
              bottom: 58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (c.colorByType) ...[
                    const TypeLegendStrip(),
                    const SizedBox(height: 8),
                  ],
                  AnimatedSwitcher(
                    duration: dentraMotion(context, 220),
                    child: hint == null
                        ? const SizedBox.shrink()
                        : ViewerHint(
                            key: ValueKey(hint),
                            text: hint,
                            icon: _interacted
                                ? Icons.touch_app_rounded
                                : Icons.threed_rotation_rounded,
                          ),
                  ),
                ],
              ),
            ),
            // Bottom: preset view directions.
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: CameraViewBar(onView: _camera.showView),
            ),
          ],
        ],
      );
    });
  }
}

class _RegionBar extends StatelessWidget {
  const _RegionBar({required this.region, required this.onChanged});

  final ExplorerRegion region;
  final ValueChanged<ExplorerRegion> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
        itemCount: ExplorerRegion.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final r = ExplorerRegion.values[i];
          return DentraChoiceChip(
            label: r.label,
            selected: r == region,
            onSelected: () => onChanged(r),
          );
        },
      ),
    );
  }
}

class _ViewerLoading extends StatelessWidget {
  const _ViewerLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Preparing the 3D model',
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation(AppColors.g2),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Preparing the 3D model…',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerMessage extends StatelessWidget {
  const _ViewerMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.g2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: AppColors.g2, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 160,
              child: DentraPillButton(
                label: 'Try again',
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
