import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_mascot.dart';
import '../../dental_profile/widgets/question_block.dart'
    show QuestionnaireProgress;
import '../../scan/data/scan_regions.dart';
import '../../scan/providers/scan_session_provider.dart';
import '../../scan/services/photo_check_service.dart';
import '../../scan/widgets/scan_motion.dart';
import '../../scan/widgets/scan_theme.dart';
import '../camera_flow.dart';
import '../camera_strings.dart';
import '../data/camera_config.dart';
import '../data/camera_store.dart';
import '../data/saved_camera.dart';
import '../providers/camera_providers.dart';
import '../state/guided_capture_controller.dart';
import '../state/live_camera_controller.dart';
import '../widgets/camera_bits.dart';
import '../widgets/camera_controls_sheet.dart';
import '../widgets/capture_tips_sheet.dart';
import '../widgets/live_view.dart';
import '../widgets/shot_status.dart';
import 'capture_review_screen.dart';
import 'shot_viewer_screen.dart';

/// The Dentra Cam's live picture, like a phone camera: a guided list of areas
/// to photograph, a big capture button and the photos taken so far.
///
/// Photos go into the current scan as soon as the photo check passes them.
/// The route resolves to true when the user chose Save & analyze.
class LiveCaptureScreen extends ConsumerStatefulWidget {
  const LiveCaptureScreen({
    super.key,
    required this.camera,
    required this.settings,
    this.showTips = false,
    this.startAt,
  });

  final SavedCamera camera;
  final CameraViewSettings settings;

  /// Shows "How to capture" before the first photo.
  final bool showTips;

  /// The area to start with; the first one still to do otherwise.
  final String? startAt;

  static Route<bool> route({
    required SavedCamera camera,
    required CameraViewSettings settings,
    bool showTips = false,
    String? startAt,
  }) =>
      MaterialPageRoute<bool>(
        builder: (_) => LiveCaptureScreen(
          camera: camera,
          settings: settings,
          showTips: showTips,
          startAt: startAt,
        ),
      );

  @override
  ConsumerState<LiveCaptureScreen> createState() => _LiveCaptureScreenState();
}

class _LiveCaptureScreenState extends ConsumerState<LiveCaptureScreen>
    with SingleTickerProviderStateMixin {
  late LiveCameraController _live;

  /// Which camera [_live] shows (its address, or its id on the API).
  late String _cameraKey;
  late final GuidedCaptureController _guide;
  late final CameraStore _store;
  late CameraViewSettings _settings;
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );
  late final AppLifecycleListener _lifecycle;

  /// Another page covers this one, so the stream stays off.
  bool _covered = false;

  /// The app is in the background.
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    _store = ref.read(cameraStoreProvider);
    _settings = widget.settings;
    _cameraKey = widget.camera.key;
    _live = _liveFor(widget.camera);
    // Captured once: a photo that passes after this page closes still
    // reaches the scan.
    final scan = ref.read(scanSessionProvider.notifier);
    _guide = GuidedCaptureController(
      areas: CameraConfig.captureAreas,
      checker: ref.read(photoCheckServiceProvider),
      kept: ref.read(scanSessionProvider).captures,
      startAt: widget.startAt,
      onKept: scan.keepCheckedPhoto,
      onRemoved: scan.removePhoto,
    );
    _live.start();
    unawaited(WakelockPlus.enable().catchError((_) {}));
    _lifecycle = AppLifecycleListener(onHide: _onHide, onShow: _onShow);
    if (widget.showTips) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showTips(first: true));
      });
    }
  }

  LiveCameraController _liveFor(SavedCamera camera) => LiveCameraController(
        client: ref.read(cameraClientProvider)(camera),
        settings: _settings,
        onSettingsChanged: (s) {
          _settings = s;
          unawaited(_store.saveSettings(s));
        },
      );

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(WakelockPlus.disable().catchError((_) {}));
    _flash.dispose();
    _live.dispose();
    _guide.dispose();
    super.dispose();
  }

  // ── Stream on and off ───────────────────────────────────────────

  void _onHide() {
    _hidden = true;
    _live.stop();
  }

  void _onShow() {
    _hidden = false;
    if (!_covered) _live.start();
  }

  /// Opens a page over this one with the stream off. Call [_resume] after,
  /// unless this page is closing.
  Future<T?> _over<T>(Future<T?> Function() open) async {
    _covered = true;
    _live.stop();
    try {
      return await open();
    } finally {
      _covered = false;
    }
  }

  void _resume() {
    if (mounted && !_covered && !_hidden) _live.start();
  }

  // ── Actions ─────────────────────────────────────────────────────

  Future<void> _capture() async {
    if (_live.capturing || !_live.isLive) return;
    unawaited(HapticFeedback.mediumImpact());
    if (!ScanMotion.reduced(context)) unawaited(_flash.forward(from: 0));
    try {
      final image = await _live.capture();
      if (!mounted) return;
      if (_guide.add(image)) unawaited(_openReview());
    } catch (_) {
      if (!mounted) return;
      showDentraSnack(
        context,
        CamText.captureFailed,
        tone: DentraFeedbackTone.error,
      );
    }
  }

  void _skip() {
    if (_live.capturing) return;
    if (_guide.skip()) unawaited(_openReview());
  }

  Future<void> _openReview() async {
    final result = await _over(
      () => Navigator.of(context).push(CaptureReviewScreen.route(_guide)),
    );
    if (!mounted) return;
    if (result is ReviewSave) {
      Navigator.of(context).pop(true);
      return;
    }
    if (result is ReviewGoTo) _guide.goTo(result.areaId);
    _resume();
  }

  Future<void> _openShot(ScanRegion area) async {
    if (_live.capturing) return;
    final action = await _over(
      () => Navigator.of(context).push(
        ShotViewerScreen.route(area: area, guide: _guide),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case ShotAction.retake:
        _guide.goTo(area.id);
      case ShotAction.delete:
        _guide.delete(area.id);
      case null:
        break;
    }
    _resume();
  }

  /// "Check device": the setup guide, then the camera it set up.
  Future<void> _checkDevice() async {
    await _over(() => openCameraSetup(context));
    if (!mounted) return;
    final camera = await ref.read(savedCameraProvider.future);
    if (!mounted) return;
    if (camera != null && camera.key != _cameraKey) {
      final old = _live;
      _cameraKey = camera.key;
      setState(() => _live = _liveFor(camera));
      old.dispose();
    }
    // Starting again gives a fresh 15 seconds, so it also retries.
    _resume();
  }

  Future<void> _showTips({bool first = false}) async {
    final hide = await showCaptureTips(context, offerHide: first);
    if (hide) unawaited(_store.setTipsHidden(true));
  }

  Future<void> _toggleLight() async {
    final ok = await _live.setLight(on: !_live.settings.lightOn);
    if (!ok && mounted) {
      showDentraSnack(
        context,
        CamText.settingFailed,
        tone: DentraFeedbackTone.error,
      );
    }
  }

  // ── Layout ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListenableBuilder(
                listenable: Listenable.merge([_live, _guide]),
                builder: (context, _) {
                  final area = _guide.current;
                  final busy = _live.capturing;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        guide: _guide,
                        onClose: () => Navigator.of(context).maybePop(),
                        onSkip: busy ? null : _skip,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Center(
                            child: _Viewport(
                              live: _live,
                              area: area,
                              flash: _flash,
                              onRetry: _live.retry,
                              cloud: widget.camera.cloudId != null,
                              onCheckDevice: _checkDevice,
                              onToggleLight: _toggleLight,
                              onControls: () =>
                                  showCameraControls(context, _live),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Thumbs(
                        guide: _guide,
                        onOpen: busy ? null : _openShot,
                      ),
                      const SizedBox(height: 8),
                      _BottomBar(
                        live: _live,
                        guide: _guide,
                        area: area,
                        onCapture: _capture,
                        onReview: busy ? null : _openReview,
                        onTips: () => _showTips(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Close, how far along, Skip, then the area to photograph and how.
class _Header extends StatelessWidget {
  const _Header({
    required this.guide,
    required this.onClose,
    required this.onSkip,
  });

  final GuidedCaptureController guide;
  final VoidCallback onClose;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final area = guide.current;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onClose,
                tooltip: CamText.closeCamera,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.white.withValues(alpha: 0.7),
                  foregroundColor: AppColors.navy,
                  fixedSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: QuestionnaireProgress(
                  step: guide.index,
                  total: guide.total,
                  label: area.label,
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  minimumSize: const Size(56, 44),
                  textStyle: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Semantics(
                  label: CamText.skipArea(area.label),
                  excludeSemantics: true,
                  child: const Text(CamText.skip),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AnimatedSwitcher(
              duration: ScanMotion.of(context, ScanMotion.medium),
              transitionBuilder: ScanMotion.fadeRise,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [...previous, if (current != null) current],
              ),
              child: Column(
                key: ValueKey(area.id),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    liveRegion: true,
                    child: Text(
                      area.label,
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    area.instruction,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13.5,
                      color: AppColors.secondaryText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The live picture at the camera's own 4:3 shape, so nothing that will be
/// in the photo is cropped away, with the status, quick controls and area
/// on top.
class _Viewport extends StatelessWidget {
  const _Viewport({
    required this.live,
    required this.area,
    required this.flash,
    required this.cloud,
    required this.onRetry,
    required this.onCheckDevice,
    required this.onToggleLight,
    required this.onControls,
  });

  final LiveCameraController live;
  final ScanRegion area;
  final Animation<double> flash;

  /// The camera comes through the internet (the website).
  final bool cloud;
  final VoidCallback onRetry;
  final VoidCallback onCheckDevice;
  final VoidCallback onToggleLight;
  final VoidCallback onControls;

  @override
  Widget build(BuildContext context) {
    final phase = live.phase;
    final duration = ScanMotion.of(context, ScanMotion.medium);
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.lightLavender,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.white, width: 1.5),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Semantics(
                image: true,
                label: CamText.captureScreen,
                // Each camera frame repaints only the picture, not the page around it.
                child: RepaintBoundary(
                  child: LiveView(frames: live.frame),
                ),
              ),
              AnimatedSwitcher(
                duration: duration,
                child: switch (phase) {
                  LivePhase.live => const SizedBox.expand(),
                  LivePhase.connecting => const _Veil(
                      key: ValueKey('connecting'),
                      opacity: 0,
                      child: CamBusyCenter(CamText.connecting),
                    ),
                  LivePhase.reconnecting => const _Veil(
                      key: ValueKey('reconnecting'),
                      opacity: 0.55,
                      child: CamBusyCenter(CamText.reconnecting),
                    ),
                  LivePhase.disconnected => _Veil(
                      key: const ValueKey('disconnected'),
                      opacity: 0.8,
                      child: _Disconnected(
                        cloud: cloud,
                        onRetry: onRetry,
                        onCheckDevice: onCheckDevice,
                      ),
                    ),
                },
              ),
              Positioned(
                top: 10,
                left: 10,
                child: _StatusChip(on: live.isLive, bars: live.signal),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Row(
                  children: [
                    // Only on cameras that have a light.
                    if (live.lightAvailable) ...[
                      CamRoundButton(
                        icon: live.settings.lightOn
                            ? Icons.light_mode_rounded
                            : Icons.light_mode_outlined,
                        tooltip: live.settings.lightOn
                            ? CamText.lightOff
                            : CamText.lightOn,
                        onPressed: onToggleLight,
                        size: 40,
                      ),
                      const SizedBox(width: 6),
                    ],
                    CamRoundButton(
                      icon: Icons.tune_rounded,
                      tooltip: CamText.controls,
                      onPressed: onControls,
                      size: 40,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 10,
                bottom: 10,
                child: _AreaChip(label: area.short),
              ),
              // The shutter: a white flash that fades as the photo is taken.
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: flash,
                  builder: (context, _) {
                    final showing = flash.status == AnimationStatus.forward;
                    return Opacity(
                      opacity: showing ? (1 - flash.value) * 0.85 : 0,
                      child: const ColoredBox(color: AppColors.white),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A frosted white layer over the picture, holding a message.
class _Veil extends StatelessWidget {
  const _Veil({super.key, required this.opacity, required this.child});

  final double opacity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.white.withValues(alpha: opacity),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FittedBox(fit: BoxFit.scaleDown, child: child),
        ),
      ),
    );
  }
}

class _Disconnected extends StatelessWidget {
  const _Disconnected({
    required this.cloud,
    required this.onRetry,
    required this.onCheckDevice,
  });

  /// Reached through the internet (the website), not the home network.
  final bool cloud;
  final VoidCallback onRetry;
  final VoidCallback onCheckDevice;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DentraMascot(mood: MascotMood.worried, size: 92),
            const SizedBox(height: 6),
            Text(
              CamText.disconnectedTitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              cloud ? CamText.disconnectedBodyCloud : CamText.disconnectedBody,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DentraPillButton(
                    label: CamText.checkDevice,
                    variant: DentraButtonVariant.outline,
                    onPressed: onCheckDevice,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DentraPillButton(
                    label: CamText.retry,
                    onPressed: onRetry,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Connected dot and Wi-Fi bars.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.on, required this.bars});

  final bool on;
  final int? bars;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: CamText.statusSemantics(on, bars),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.g2.withValues(alpha: 0.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusDot(on: on),
            if (bars != null) ...[
              const SizedBox(width: 8),
              SignalBars(bars: bars!, height: 11),
            ],
          ],
        ),
      ),
    );
  }
}

/// The area being photographed, on the picture.
class _AreaChip extends StatelessWidget {
  const _AreaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedSwitcher(
        duration: ScanMotion.of(context, ScanMotion.medium),
        transitionBuilder: ScanMotion.fadeRise,
        child: Container(
          key: ValueKey(label),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.g2.withValues(alpha: 0.14)),
          ),
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The photos taken this time, in area order, each with its check.
class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.guide, required this.onOpen});

  final GuidedCaptureController guide;
  final ValueChanged<ScanRegion>? onOpen;

  @override
  Widget build(BuildContext context) {
    final areas = guide.withPhotos;
    return SizedBox(
      height: 60,
      child: areas.isEmpty
          ? Center(
              child: Text(
                CamText.thumbsEmpty,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  color: AppColors.secondaryText,
                ),
              ),
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: areas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final area = areas[i];
                final shot = guide.shotFor(area.id)!;
                final current = area.id == guide.current.id;
                return _Thumb(
                  key: ValueKey(area.id),
                  area: area,
                  shot: shot,
                  current: current,
                  onTap: onOpen == null ? null : () => onOpen!(area),
                );
              },
            ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.area,
    required this.shot,
    required this.current,
    required this.onTap,
  });

  final ScanRegion area;
  final AreaShot shot;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final status = shotStatus(shot)!;
    return Semantics(
      button: true,
      label: CamText.thumbSemantics(area.label, status.label),
      onTap: onTap,
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        // Pops in when it's new.
        tween: Tween(begin: 0.6, end: 1),
        duration: ScanMotion.of(context, ScanMotion.medium),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 76,
            height: 60,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: 3,
                  right: 6,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: current
                            ? AppColors.primary
                            : AppColors.white.withValues(alpha: 0.9),
                        width: current ? 2 : 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        shot.image.bytes,
                        fit: BoxFit.cover,
                        cacheWidth: 210,
                        gaplessPlayback: true,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -2,
                  right: 0,
                  child: ShotBadge(shot: shot),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Review on the left, the capture button in the middle, tips on the right.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.live,
    required this.guide,
    required this.area,
    required this.onCapture,
    required this.onReview,
    required this.onTips,
  });

  final LiveCameraController live;
  final GuidedCaptureController guide;
  final ScanRegion area;
  final VoidCallback onCapture;
  final VoidCallback? onReview;
  final VoidCallback onTips;

  @override
  Widget build(BuildContext context) {
    final count = '${guide.keptCount}/${guide.total}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                button: true,
                label: '${CamText.review}, ${CamText.reviewSummary(
                  guide.keptCount,
                  guide.total,
                )}',
                onTap: onReview,
                excludeSemantics: true,
                child: Material(
                  color: AppColors.white.withValues(alpha: 0.85),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: AppColors.g2.withValues(alpha: 0.16),
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onReview,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.grid_view_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            count,
                            style:
                                figureText(size: 12, weight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ShutterButton(
                label: CamText.takePhoto(area.label),
                busy: live.capturing,
                onPressed: live.isLive ? onCapture : null,
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Align(
              alignment: Alignment.centerRight,
              child: CamRoundButton(
                icon: Icons.lightbulb_outline_rounded,
                tooltip: CamText.howToCapture,
                onPressed: onTips,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
