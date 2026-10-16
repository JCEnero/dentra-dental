import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';
import '../data/models/captured_image.dart';
import '../data/scan_regions.dart';
import '../services/dentra_device_service.dart';
import '../services/phone_camera_service.dart';
import '../services/screening_analysis_service.dart';

enum CapturePhase {
  idle,

  /// The system camera or photo picker is open.
  awaitingCamera,

  /// An image is transferring from the DENTRA device.
  receiving,

  /// A received image is waiting for the user to keep or retake it.
  reviewing,
  failed,
}

enum CaptureFailure {
  permissionDenied,
  cameraUnavailable,
  captureFailed,
  deviceTimeout,
  transferInterrupted,
}

enum FinishPhase { scanning, saving, analyzing, analysisFailed, done }

const Object _unset = Object();

class ScanSessionState {
  const ScanSessionState({
    required this.selectedRegionId,
    this.captures = const {},
    this.capturePhase = CapturePhase.idle,
    this.transferProgress,
    this.pending,
    this.pendingSource,
    this.captureFailure,
    this.lastSavedRegionId,
    this.savedCount = 0,
    this.finishPhase = FinishPhase.scanning,
    this.finishedAt,
    this.analysis,
    this.analysisFailure,
    this.historySaveFailed = false,
  });

  final String selectedRegionId;

  /// Accepted images by region id. A region is complete only once its
  /// image is here.
  final Map<String, CapturedImage> captures;

  final CapturePhase capturePhase;

  /// Device transfer progress (0–1), null while unknown.
  final double? transferProgress;
  final CapturedImage? pending;

  /// Source of the capture in progress or under review, for retakes.
  final CaptureSource? pendingSource;
  final CaptureFailure? captureFailure;

  /// Region accepted most recently, for the success feedback.
  final String? lastSavedRegionId;

  /// Increments on every accept so repeated saves still animate.
  final int savedCount;

  final FinishPhase finishPhase;
  final DateTime? finishedAt;
  final ScreeningAnalysisResult? analysis;
  final AnalysisFailure? analysisFailure;
  final bool historySaveFailed;

  ScanRegion get selectedRegion => scanRegionById(selectedRegionId);
  bool isCaptured(String regionId) => captures.containsKey(regionId);
  int get capturedCount => captures.length;
  bool get allCaptured => captures.length == scanRegions.length;

  bool get isCaptureBusy =>
      capturePhase == CapturePhase.awaitingCamera ||
      capturePhase == CapturePhase.receiving;

  /// Regions can be switched unless a capture or review is in progress.
  bool get canChangeRegion =>
      finishPhase == FinishPhase.scanning &&
      !isCaptureBusy &&
      capturePhase != CapturePhase.reviewing;

  bool get canFinish => captures.isNotEmpty && canChangeRegion;

  ScanSessionState copyWith({
    String? selectedRegionId,
    Map<String, CapturedImage>? captures,
    CapturePhase? capturePhase,
    Object? transferProgress = _unset,
    Object? pending = _unset,
    Object? pendingSource = _unset,
    Object? captureFailure = _unset,
    Object? lastSavedRegionId = _unset,
    int? savedCount,
    FinishPhase? finishPhase,
    Object? finishedAt = _unset,
    Object? analysis = _unset,
    Object? analysisFailure = _unset,
    bool? historySaveFailed,
  }) {
    return ScanSessionState(
      selectedRegionId: selectedRegionId ?? this.selectedRegionId,
      captures: captures ?? this.captures,
      capturePhase: capturePhase ?? this.capturePhase,
      transferProgress: transferProgress == _unset
          ? this.transferProgress
          : transferProgress as double?,
      pending: pending == _unset ? this.pending : pending as CapturedImage?,
      pendingSource: pendingSource == _unset
          ? this.pendingSource
          : pendingSource as CaptureSource?,
      captureFailure: captureFailure == _unset
          ? this.captureFailure
          : captureFailure as CaptureFailure?,
      lastSavedRegionId: lastSavedRegionId == _unset
          ? this.lastSavedRegionId
          : lastSavedRegionId as String?,
      savedCount: savedCount ?? this.savedCount,
      finishPhase: finishPhase ?? this.finishPhase,
      finishedAt:
          finishedAt == _unset ? this.finishedAt : finishedAt as DateTime?,
      analysis: analysis == _unset
          ? this.analysis
          : analysis as ScreeningAnalysisResult?,
      analysisFailure: analysisFailure == _unset
          ? this.analysisFailure
          : analysisFailure as AnalysisFailure?,
      historySaveFailed: historySaveFailed ?? this.historySaveFailed,
    );
  }
}

/// The scan session: region selection, captures, review, and finishing.
///
/// Progress only advances on real results: a region completes when the
/// user accepts an image that a capture source actually returned, and the
/// analysis phase runs only while a real analysis request is in flight.
class ScanSessionNotifier extends Notifier<ScanSessionState> {
  static const Duration deviceCaptureTimeout = Duration(seconds: 45);
  static const Duration analysisTimeout = Duration(seconds: 90);

  /// Invalidates in-flight work when the session resets.
  int _token = 0;

  @override
  ScanSessionState build() =>
      ScanSessionState(selectedRegionId: scanRegions.first.id);

  void selectRegion(String id) {
    if (!state.canChangeRegion || id == state.selectedRegionId) return;
    state = state.copyWith(
      selectedRegionId: id,
      capturePhase: CapturePhase.idle,
      captureFailure: null,
    );
  }

  Future<void> capture(CaptureSource source) async {
    if (state.isCaptureBusy || state.finishPhase != FinishPhase.scanning) {
      return;
    }
    final token = _token;
    state = state.copyWith(
      capturePhase: source == CaptureSource.device
          ? CapturePhase.receiving
          : CapturePhase.awaitingCamera,
      pending: null,
      pendingSource: source,
      captureFailure: null,
      transferProgress: null,
    );

    CapturedImage? image;
    CaptureFailure? failure;
    try {
      if (source == CaptureSource.device) {
        image = await ref.read(dentraDeviceServiceProvider).capture(
            onProgress: (p) {
          if (token == _token && state.capturePhase == CapturePhase.receiving) {
            state = state.copyWith(transferProgress: p.clamp(0.0, 1.0));
          }
        }).timeout(deviceCaptureTimeout);
      } else {
        image = await ref.read(phoneCameraServiceProvider).capture(source);
      }
    } on TimeoutException {
      failure = CaptureFailure.deviceTimeout;
    } on DeviceException catch (e) {
      failure = e.failure == DeviceFailure.timeout
          ? CaptureFailure.deviceTimeout
          : CaptureFailure.transferInterrupted;
    } on CameraException catch (e) {
      failure = switch (e.failure) {
        CameraFailure.permissionDenied => CaptureFailure.permissionDenied,
        CameraFailure.unavailable => CaptureFailure.cameraUnavailable,
        CameraFailure.failed => CaptureFailure.captureFailed,
      };
    } catch (_) {
      failure = CaptureFailure.captureFailed;
    }

    if (token != _token) return;
    if (failure != null) {
      state = state.copyWith(
        capturePhase: CapturePhase.failed,
        captureFailure: failure,
        transferProgress: null,
      );
    } else if (image == null) {
      // User closed the camera without taking a photo.
      state = state.copyWith(
        capturePhase: CapturePhase.idle,
        transferProgress: null,
      );
    } else {
      state = state.copyWith(
        capturePhase: CapturePhase.reviewing,
        pending: image,
        transferProgress: null,
      );
    }
  }

  /// Keeps the image under review and moves on to the next open region.
  void acceptPending() {
    final image = state.pending;
    if (state.capturePhase != CapturePhase.reviewing || image == null) return;
    final region = state.selectedRegionId;
    final captures = Map<String, CapturedImage>.unmodifiable({
      ...state.captures,
      region: image,
    });
    state = state.copyWith(
      captures: captures,
      selectedRegionId: _nextOpenRegion(after: region, captures: captures),
      capturePhase: CapturePhase.idle,
      pending: null,
      pendingSource: null,
      lastSavedRegionId: region,
      savedCount: state.savedCount + 1,
    );
  }

  /// Discards the image under review and captures again from the same source.
  Future<void> retake() async {
    final source = state.pendingSource;
    if (state.capturePhase != CapturePhase.reviewing || source == null) return;
    state = state.copyWith(capturePhase: CapturePhase.idle, pending: null);
    await capture(source);
  }

  void dismissFailure() {
    if (state.capturePhase != CapturePhase.failed) return;
    state = state.copyWith(
      capturePhase: CapturePhase.idle,
      captureFailure: null,
    );
  }

  /// Ends scanning with the regions captured so far.
  Future<void> finish() async {
    if (!state.canFinish) return;
    final token = _token;
    final now = DateTime.now();
    state = state.copyWith(finishPhase: FinishPhase.saving, finishedAt: now);

    var saveFailed = false;
    try {
      await ref.read(screeningSessionsProvider.notifier).record(
            ScreeningSession(
              id: now.microsecondsSinceEpoch.toString(),
              completedAt: now,
              capturedRegions: [
                for (final r in scanRegions)
                  if (state.isCaptured(r.id)) r.id,
              ],
              totalRegions: scanRegions.length,
            ),
          );
    } catch (_) {
      saveFailed = true;
    }
    if (token != _token) return;
    state = state.copyWith(historySaveFailed: saveFailed);

    if (ref.read(screeningAnalysisServiceProvider) == null) {
      state = state.copyWith(finishPhase: FinishPhase.done);
      return;
    }
    await _analyze();
  }

  Future<void> retryAnalysis() async {
    if (state.finishPhase != FinishPhase.analysisFailed) return;
    await _analyze();
  }

  void skipAnalysis() {
    if (state.finishPhase != FinishPhase.analysisFailed) return;
    state = state.copyWith(finishPhase: FinishPhase.done);
  }

  /// Clears the warning once the user has been told.
  void acknowledgeHistoryError() =>
      state = state.copyWith(historySaveFailed: false);

  /// Starts a fresh session. The device connection is left as it is.
  void reset() {
    _token++;
    state = ScanSessionState(selectedRegionId: scanRegions.first.id);
  }

  Future<void> _analyze() async {
    final service = ref.read(screeningAnalysisServiceProvider);
    if (service == null) return;
    final token = _token;
    state = state.copyWith(
      finishPhase: FinishPhase.analyzing,
      analysisFailure: null,
    );
    try {
      final result = await service.analyze({
        for (final e in state.captures.entries) e.key: e.value.bytes,
      }).timeout(analysisTimeout);
      if (token != _token) return;
      state = state.copyWith(finishPhase: FinishPhase.done, analysis: result);
    } catch (e) {
      if (token != _token) return;
      state = state.copyWith(
        finishPhase: FinishPhase.analysisFailed,
        analysisFailure: switch (e) {
          TimeoutException() => AnalysisFailure.timeout,
          AnalysisException(:final failure) => failure,
          _ => AnalysisFailure.service,
        },
      );
    }
  }

  String _nextOpenRegion({
    required String after,
    required Map<String, CapturedImage> captures,
  }) {
    final start = scanRegions.indexWhere((r) => r.id == after);
    for (var i = 1; i <= scanRegions.length; i++) {
      final r = scanRegions[(start + i) % scanRegions.length];
      if (!captures.containsKey(r.id)) return r.id;
    }
    return after; // everything is captured
  }
}

final scanSessionProvider =
    NotifierProvider<ScanSessionNotifier, ScanSessionState>(
  ScanSessionNotifier.new,
);
