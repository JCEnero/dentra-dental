import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../notifications/data/notification_events.dart';
import '../../notifications/providers/notifications_provider.dart';
import '../../screening/data/models/scan_check_in.dart';
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';
import '../data/models/captured_image.dart';
import '../data/scan_regions.dart';
import '../services/dentra_device_service.dart';
import '../services/phone_camera_service.dart';
import '../services/photo_quality.dart';
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
    this.started = false,
    this.checkIn,
    this.checkInSeen = false,
    this.captures = const {},
    this.capturePhase = CapturePhase.idle,
    this.transferProgress,
    this.pending,
    this.pendingQuality,
    this.pendingSource,
    this.captureFailure,
    this.lastSavedRegionId,
    this.savedCount = 0,
    this.finishPhase = FinishPhase.scanning,
    this.finishedAt,
    this.analysis,
    this.analysisFailure,
    this.historySaveFailed = false,
    this.uploadedCount = 0,
    this.uploadTotal = 0,
    this.uploadsDone = false,
    this.analysisProgress,
  });

  final String selectedRegionId;

  /// Past the intro, into the guided views.
  final bool started;

  /// What the user said before this scan. Null when they skipped it.
  final ScanCheckIn? checkIn;

  /// They've had their say, so coming back to the intro doesn't ask again.
  final bool checkInSeen;

  /// Accepted images by region id. A region is complete only once its
  /// image is here.
  final Map<String, CapturedImage> captures;

  final CapturePhase capturePhase;

  /// Device transfer progress (0–1), null while unknown.
  final double? transferProgress;
  final CapturedImage? pending;

  /// How the image under review measured on the device, once it has.
  final PhotoQuality? pendingQuality;

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

  /// Real progress of the run: photos sent, and how far the server has got.
  final int uploadedCount;
  final int uploadTotal;
  final bool uploadsDone;
  final ScreeningAnalysisProgress? analysisProgress;

  /// Photos in the run, in capture order: each view, then its second photo.
  List<String> get photoIds => [
        for (final r in scanRegions) ...[
          if (isCaptured(r.id)) r.id,
          if (isCaptured(secondPhotoId(r.id))) secondPhotoId(r.id),
        ],
      ];

  ScanRegion get selectedRegion => scanRegionById(selectedRegionId);
  bool isCaptured(String regionId) => captures.containsKey(regionId);

  /// Photos taken, second photos included.
  int get capturedCount => captures.length;

  /// Views with a photo. A view's second photo doesn't count again.
  int get capturedViewCount =>
      scanRegions.where((r) => isCaptured(r.id)).length;
  bool get allCaptured => capturedViewCount == scanRegions.length;

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
    bool? started,
    ScanCheckIn? checkIn,
    bool? checkInSeen,
    Map<String, CapturedImage>? captures,
    CapturePhase? capturePhase,
    Object? transferProgress = _unset,
    Object? pending = _unset,
    Object? pendingQuality = _unset,
    Object? pendingSource = _unset,
    Object? captureFailure = _unset,
    Object? lastSavedRegionId = _unset,
    int? savedCount,
    FinishPhase? finishPhase,
    Object? finishedAt = _unset,
    Object? analysis = _unset,
    Object? analysisFailure = _unset,
    bool? historySaveFailed,
    int? uploadedCount,
    int? uploadTotal,
    bool? uploadsDone,
    Object? analysisProgress = _unset,
  }) {
    return ScanSessionState(
      selectedRegionId: selectedRegionId ?? this.selectedRegionId,
      started: started ?? this.started,
      checkIn: checkIn ?? this.checkIn,
      checkInSeen: checkInSeen ?? this.checkInSeen,
      captures: captures ?? this.captures,
      capturePhase: capturePhase ?? this.capturePhase,
      transferProgress: transferProgress == _unset
          ? this.transferProgress
          : transferProgress as double?,
      pending: pending == _unset ? this.pending : pending as CapturedImage?,
      pendingQuality: pendingQuality == _unset
          ? this.pendingQuality
          : pendingQuality as PhotoQuality?,
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
      uploadedCount: uploadedCount ?? this.uploadedCount,
      uploadTotal: uploadTotal ?? this.uploadTotal,
      uploadsDone: uploadsDone ?? this.uploadsDone,
      analysisProgress: analysisProgress == _unset
          ? this.analysisProgress
          : analysisProgress as ScreeningAnalysisProgress?,
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
  /// Covers uploading and analyzing a full scan, up to 18 photos.
  /// The server gives up on a run at 5 minutes.
  static const Duration analysisTimeout = Duration(minutes: 4);

  /// Invalidates in-flight work when the session resets.
  int _token = 0;

  /// The history record of the finished session, updated with analysis.
  ScreeningSession? _recorded;

  /// Whether [_recorded] reached the history store.
  bool _saved = false;

  /// Photo uploads for [_recorded]. Server-side analysis waits for them.
  Future<void>? _upload;

  /// What's already stored for [_recorded], so a retake only sends new photos.
  final Map<String, Uint8List> _uploaded = {};

  /// Set while retaking: the run saves over this session instead of adding one.
  String? _resumeId;

  @override
  ScanSessionState build() =>
      ScanSessionState(selectedRegionId: scanRegions.first.id);

  /// Leaves the intro for the guided views, keeping what the user said first.
  void start({ScanCheckIn? checkIn}) => state = state.copyWith(
        started: true,
        checkIn: checkIn,
        checkInSeen: true,
      );

  /// Back to the intro. Photos taken so far stay.
  void showIntro() {
    if (!state.canChangeRegion) return;
    state = state.copyWith(started: false);
  }

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
      pendingQuality: null,
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
      unawaited(_measure(image));
    }
  }

  /// Measures the photo under review. Ignored if it has moved on meanwhile.
  Future<void> _measure(CapturedImage image) async {
    final quality = await PhotoQuality.measure(image.bytes);
    if (quality != null && identical(state.pending, image)) {
      state = state.copyWith(pendingQuality: quality);
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
      pendingQuality: null,
      pendingSource: null,
      lastSavedRegionId: region,
      savedCount: state.savedCount + 1,
    );
  }

  /// Discards the image under review and captures again from the same source.
  Future<void> retake() async {
    final source = state.pendingSource;
    if (state.capturePhase != CapturePhase.reviewing || source == null) return;
    state = state.copyWith(
      capturePhase: CapturePhase.idle,
      pending: null,
      pendingQuality: null,
    );
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
    state = state.copyWith(
      finishPhase: FinishPhase.saving,
      finishedAt: now,
      uploadedCount: 0,
      uploadTotal: 0,
      uploadsDone: false,
      analysisProgress: null,
    );

    final captured = state.photoIds;
    final session = ScreeningSession(
      id: _resumeId ?? now.microsecondsSinceEpoch.toString(),
      completedAt: now,
      capturedRegions: captured,
      totalRegions: scanRegions.length,
      checkIn: state.checkIn,
      captures: [
        for (final id in captured)
          ScreeningCapture(
            regionId: id,
            source: state.captures[id]!.source.name,
            capturedAt: state.captures[id]!.capturedAt,
            deviceMeta: state.captures[id]!.deviceMeta,
          ),
      ],
    );
    _recorded = session;
    _saved = false;
    _upload = null;
    final images = {for (final id in captured) id: state.captures[id]!.bytes};
    // Shown from memory right away; the upload below makes them last.
    ref.read(screeningImageCacheProvider.notifier).put(session.id, images);

    var saveFailed = false;
    try {
      await ref.read(screeningSessionsProvider.notifier).record(session);
      _saved = true;
    } catch (_) {
      saveFailed = true;
    }
    if (!saveFailed) {
      // In the background: the record is already saved, and the photos
      // stay visible for this app run if an upload fails. Server-side
      // analysis awaits this before it starts.
      final upload = _uploadImages();
      unawaited(upload.catchError((_) {}));
      unawaited(ref.read(notificationsProvider.notifier).record(
            NotificationEvents.screeningSaved(
              sessionId: session.id,
              captured: state.capturedViewCount,
              total: scanRegions.length,
            ),
          ));
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
    _recorded = null;
    _saved = false;
    _upload = null;
    _uploaded.clear();
    _resumeId = null;
    state = ScanSessionState(selectedRegionId: scanRegions.first.id);
  }

  /// Back to the guided views to take again only the photos the analysis
  /// couldn't use. The good ones stay, and finishing updates this screening
  /// rather than adding another to the history.
  void retakeFlagged() {
    final flagged = {
      for (final i in state.analysis?.analysis?.qualityIssues ??
          const <ScreeningQualityIssue>[])
        if (i.modality == 'rgb') i.regionId,
    };
    if (flagged.isEmpty) return;
    final first = scanRegions.firstWhere(
      (r) => flagged.contains(r.id) || flagged.contains(secondPhotoId(r.id)),
      orElse: () => scanRegions.first,
    );
    _token++;
    _resumeId = _recorded?.id;
    _upload = null;
    state = ScanSessionState(
      selectedRegionId: flagged.contains(first.id)
          ? first.id
          : secondPhotoId(first.id),
      started: true,
      checkIn: state.checkIn,
      checkInSeen: true,
      captures: Map.unmodifiable({...state.captures}
        ..removeWhere((id, _) => flagged.contains(id))),
    );
  }

  /// Uploads [_recorded]'s photos and NIR frames once; a failed upload is
  /// tried again on the next call. Photos already stored aren't sent again.
  Future<void> _uploadImages() {
    final recorded = _recorded!;
    final captures = state.captures;
    return _upload ??= () async {
      try {
        final images = {
          for (final id in recorded.capturedRegions)
            if (!identical(_uploaded[id], captures[id]!.bytes))
              id: captures[id]!.bytes,
        };
        final token = _token;
        state = state.copyWith(uploadTotal: images.length, uploadedCount: 0);
        var sent = 0;
        await ref.read(screeningSessionsProvider.notifier).uploadImages(
          recorded.id,
          images,
          nirByRegion: {
            for (final id in images.keys)
              if (captures[id]!.nirBytes case final nir?) id: nir,
          },
          onUploaded: (id, modality) {
            if (modality != 'rgb') return;
            _uploaded[id] = captures[id]!.bytes;
            sent++;
            if (token == _token) state = state.copyWith(uploadedCount: sent);
          },
        );
        if (token == _token) state = state.copyWith(uploadsDone: true);
      } catch (_) {
        _upload = null;
        rethrow;
      }
    }();
  }

  Future<void> _analyze() async {
    final service = ref.read(screeningAnalysisServiceProvider);
    final recorded = _recorded;
    if (service == null || recorded == null) return;
    final token = _token;
    state = state.copyWith(
      finishPhase: FinishPhase.analyzing,
      analysisFailure: null,
      analysisProgress: null,
    );
    try {
      // The server analyzes what it has stored, so the session and its
      // photos have to be there first.
      final result = await () async {
        if (!_saved) {
          await ref.read(screeningSessionsProvider.notifier).record(recorded);
          _saved = true;
          if (token == _token) state = state.copyWith(historySaveFailed: false);
        }
        await _uploadImages();
        return service.analyze(recorded.id, onProgress: (progress) {
          if (token == _token) {
            state = state.copyWith(analysisProgress: progress);
          }
        });
      }()
          .timeout(analysisTimeout);
      if (token != _token) return;
      state = state.copyWith(finishPhase: FinishPhase.done, analysis: result);
      final sessions = ref.read(screeningSessionsProvider.notifier);
      if (result.savedSession case final saved?) {
        // Already stored with the analysis by the server.
        sessions.showSaved(saved);
      } else {
        // Best-effort: the result is already on screen; history keeps the
        // scan either way.
        unawaited(sessions
            .save(recorded.copyWith(
              analysis: result.analysis ??
                  ScreeningAnalysis(
                    summary: result.summary,
                    analyzedAt: DateTime.now(),
                  ),
            ))
            .catchError((_) {}));
      }
      unawaited(ref
          .read(notificationsProvider.notifier)
          .record(NotificationEvents.analysisReady(sessionId: recorded.id)));
    } catch (e) {
      if (token != _token) return;
      final failure = switch (e) {
        TimeoutException() => AnalysisFailure.timeout,
        AnalysisException(:final failure) => failure,
        // Saving or uploading first: the server answered with an error.
        ApiException() => AnalysisFailure.service,
        // Otherwise the request never got an answer.
        _ => AnalysisFailure.offline,
      };
      state = state.copyWith(
        // Nothing to retry when the backend has no analysis: finish as if
        // none were configured.
        finishPhase: failure == AnalysisFailure.unavailable
            ? FinishPhase.done
            : FinishPhase.analysisFailed,
        analysisFailure: failure,
      );
    }
  }

  String _nextOpenRegion({
    required String after,
    required Map<String, CapturedImage> captures,
  }) {
    final start = scanRegionIndex(after);
    if (start < 0) return scanRegions.first.id;
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
