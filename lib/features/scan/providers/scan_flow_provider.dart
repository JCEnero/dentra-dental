import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/capture_regions.dart';
import '../data/mock_scan_report.dart';
import '../rendering/scan_scene.dart';
import '../services/tooth_photo_check.dart';

/// The simulated scan: device → capture → (3D scan) → results. The 3D
/// scan runs as a full-screen route between capture and results.
enum ScanFlowStage { device, capture, results }

enum PhotoCheck {
  checking,
  passed,

  /// No teeth found. Shown so the user can retake it, but never scanned.
  rejected,
}

class RegionPhoto {
  const RegionPhoto({
    required this.bytes,
    required this.isSample,
    this.check = PhotoCheck.checking,
  });

  final Uint8List bytes;
  final bool isSample;
  final PhotoCheck check;

  RegionPhoto _checked(PhotoCheck check) =>
      RegionPhoto(bytes: bytes, isSample: isSample, check: check);
}

const Object _unset = Object();

class ScanFlowState {
  const ScanFlowState({
    this.stage = ScanFlowStage.device,
    this.photos = const {},
    this.report,
    this.completedScans = 0,
    this.preparingSamples = false,
  });

  final ScanFlowStage stage;

  /// By region id, including rejected photos so their card can say why.
  final Map<String, RegionPhoto> photos;
  final ScanReport? report;
  final int completedScans;

  /// Sample photos are being rendered.
  final bool preparingSamples;

  /// Photos that can go into the scan: everything not rejected.
  Map<String, RegionPhoto> get usablePhotos => {
        for (final e in photos.entries)
          if (e.value.check != PhotoCheck.rejected) e.key: e.value,
      };

  int get capturedCount => usablePhotos.length;
  int get skippedCount => captureRegions.length - capturedCount;
  bool get allCaptured => skippedCount == 0;

  /// At least one usable photo, and none still being checked.
  bool get canStartScan =>
      usablePhotos.isNotEmpty &&
      !photos.values.any((p) => p.check == PhotoCheck.checking);

  ScanFlowState copyWith({
    ScanFlowStage? stage,
    Map<String, RegionPhoto>? photos,
    Object? report = _unset,
    int? completedScans,
    bool? preparingSamples,
  }) {
    return ScanFlowState(
      stage: stage ?? this.stage,
      photos: photos ?? this.photos,
      report: report == _unset ? this.report : report as ScanReport?,
      completedScans: completedScans ?? this.completedScans,
      preparingSamples: preparingSamples ?? this.preparingSamples,
    );
  }
}

/// Runs the simulation. Nothing leaves the device: photos stay in
/// memory, [ToothPhotoCheck] turns away photos without teeth, and the
/// report is demo data shaped by which regions were captured.
class ScanFlowNotifier extends Notifier<ScanFlowState> {
  /// Shortest time the "checking" strip shows, so the check reads as a step.
  static const Duration qualityCheck = Duration(milliseconds: 1100);

  /// Gap between sample photos landing, so the grid fills in sequence.
  static const Duration sampleStagger = Duration(milliseconds: 90);

  @override
  ScanFlowState build() => const ScanFlowState();

  void openCapture() => state = state.copyWith(stage: ScanFlowStage.capture);

  void backToDevice() => state = state.copyWith(stage: ScanFlowStage.device);

  /// Adds a photo and checks it for teeth. Sample photos are rendered
  /// teeth, so they skip the check. Returns the outcome, or null when the
  /// photo was replaced or removed before the check finished.
  Future<PhotoCheck?> setPhoto(
    String regionId,
    Uint8List bytes, {
    bool sample = false,
  }) async {
    final photo = RegionPhoto(bytes: bytes, isSample: sample);
    state = state.copyWith(photos: {...state.photos, regionId: photo});

    final (hasTeeth, _) = await (
      sample ? Future.value(true) : ToothPhotoCheck.looksLikeTeeth(bytes),
      Future<void>.delayed(qualityCheck),
    ).wait;

    // Only if this photo wasn't replaced or removed meanwhile.
    if (!identical(state.photos[regionId], photo)) return null;
    final check = hasTeeth ? PhotoCheck.passed : PhotoCheck.rejected;
    state = state.copyWith(
      photos: {...state.photos, regionId: photo._checked(check)},
    );
    return check;
  }

  void removePhoto(String regionId) {
    state = state.copyWith(photos: {...state.photos}..remove(regionId));
  }

  void clearPhotos() {
    state = state.copyWith(photos: const {});
  }

  /// Fills every empty region with a sample photo.
  Future<void> useSamplePhotos() async {
    if (state.preparingSamples) return;
    // Rejected photos count as missing, so samples replace them.
    final missing = [
      for (final r in captureRegions)
        if (!state.usablePhotos.containsKey(r.id)) r,
    ];
    if (missing.isEmpty) return;
    state = state.copyWith(preparingSamples: true);
    try {
      final model = await ref.read(scanDentitionProvider.future);
      final samples = await renderSamplePhotos(model, missing);
      for (final r in missing) {
        if (state.stage != ScanFlowStage.capture) return;
        // A photo the user added meanwhile wins.
        if (!state.usablePhotos.containsKey(r.id)) {
          unawaited(setPhoto(r.id, samples[r.id]!, sample: true));
        }
        await Future<void>.delayed(sampleStagger);
      }
    } finally {
      state = state.copyWith(preparingSamples: false);
    }
  }

  /// Builds the report for the captured regions and shows results.
  void completeScan() {
    if (!state.canStartScan) return;
    final sequence = state.completedScans + 1;
    state = state.copyWith(
      stage: ScanFlowStage.results,
      completedScans: sequence,
      report: ScanReport.generate(
        captured: state.usablePhotos.keys.toSet(),
        completedAt: DateTime.now(),
        sequence: sequence,
      ),
    );
  }

  /// Back to the device screen with nothing captured.
  void restart() {
    state = ScanFlowState(completedScans: state.completedScans);
  }
}

final scanFlowProvider = NotifierProvider<ScanFlowNotifier, ScanFlowState>(
  ScanFlowNotifier.new,
);
