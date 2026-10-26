import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/capture_regions.dart';
import '../data/mock_scan_report.dart';
import '../rendering/scan_scene.dart';

/// The simulated scan: device → capture → (3D scan) → results. The 3D
/// scan runs as a full-screen route between capture and results.
enum ScanFlowStage { device, capture, results }

enum PhotoCheck { checking, passed }

class RegionPhoto {
  const RegionPhoto({
    required this.bytes,
    required this.isSample,
    this.check = PhotoCheck.checking,
  });

  final Uint8List bytes;
  final bool isSample;
  final PhotoCheck check;

  RegionPhoto _passed() =>
      RegionPhoto(bytes: bytes, isSample: isSample, check: PhotoCheck.passed);
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

  /// By region id.
  final Map<String, RegionPhoto> photos;
  final ScanReport? report;
  final int completedScans;

  /// Sample photos are being rendered.
  final bool preparingSamples;

  int get capturedCount => photos.length;
  int get skippedCount => captureRegions.length - photos.length;
  bool get allCaptured => skippedCount == 0;
  bool get canStartScan => photos.isNotEmpty;

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
/// memory, the quality check is a short timer and the report is mock
/// data shaped by which regions were captured.
class ScanFlowNotifier extends Notifier<ScanFlowState> {
  static const Duration qualityCheck = Duration(milliseconds: 1100);

  /// Gap between sample photos landing, so the grid fills in sequence.
  static const Duration sampleStagger = Duration(milliseconds: 90);

  final _checks = <String, Timer>{};

  @override
  ScanFlowState build() {
    ref.onDispose(_cancelChecks);
    return const ScanFlowState();
  }

  void openCapture() => state = state.copyWith(stage: ScanFlowStage.capture);

  void backToDevice() => state = state.copyWith(stage: ScanFlowStage.device);

  void setPhoto(String regionId, Uint8List bytes, {bool sample = false}) {
    final photo = RegionPhoto(bytes: bytes, isSample: sample);
    state = state.copyWith(photos: {...state.photos, regionId: photo});
    _checks[regionId]?.cancel();
    _checks[regionId] = Timer(qualityCheck, () {
      _checks.remove(regionId);
      // Only if this photo wasn't replaced or removed meanwhile.
      if (!identical(state.photos[regionId], photo)) return;
      state = state.copyWith(
        photos: {...state.photos, regionId: photo._passed()},
      );
    });
  }

  void removePhoto(String regionId) {
    _checks.remove(regionId)?.cancel();
    state = state.copyWith(photos: {...state.photos}..remove(regionId));
  }

  void clearPhotos() {
    _cancelChecks();
    state = state.copyWith(photos: const {});
  }

  /// Fills every empty region with a sample photo.
  Future<void> useSamplePhotos() async {
    if (state.preparingSamples) return;
    final missing = [
      for (final r in captureRegions)
        if (!state.photos.containsKey(r.id)) r,
    ];
    if (missing.isEmpty) return;
    state = state.copyWith(preparingSamples: true);
    try {
      final model = await ref.read(scanDentitionProvider.future);
      final samples = await renderSamplePhotos(model, missing);
      for (final r in missing) {
        if (state.stage != ScanFlowStage.capture) return;
        // A photo the user added meanwhile wins.
        if (!state.photos.containsKey(r.id)) {
          setPhoto(r.id, samples[r.id]!, sample: true);
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
        captured: state.photos.keys.toSet(),
        completedAt: DateTime.now(),
        sequence: sequence,
      ),
    );
  }

  /// Back to the device screen with nothing captured.
  void restart() {
    _cancelChecks();
    state = ScanFlowState(completedScans: state.completedScans);
  }

  void _cancelChecks() {
    for (final t in _checks.values) {
      t.cancel();
    }
    _checks.clear();
  }
}

final scanFlowProvider = NotifierProvider<ScanFlowNotifier, ScanFlowState>(
  ScanFlowNotifier.new,
);
