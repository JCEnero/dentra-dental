import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../scan/data/models/captured_image.dart';
import '../../scan/data/scan_regions.dart';
import '../../scan/providers/scan_session_provider.dart';
import '../../scan/services/photo_check_service.dart';

enum ShotCheck { checking, passed, rejected, error }

/// One area's photo and what the photo check said about it.
class AreaShot {
  const AreaShot(this.image, this.check, {this.verdict, this.error});

  final CapturedImage image;
  final ShotCheck check;

  /// Why it was rejected.
  final PhotoVerdict? verdict;

  /// Why the check couldn't reach a verdict.
  final PhotoCheckException? error;
}

/// Walks through the capture areas: which one is next, the photo taken for
/// each, and its check.
///
/// Every photo is checked as soon as it's taken, and only the ones the check
/// passes go on to the scan, through [onKept]. A kept photo that's replaced
/// or deleted is taken back through [onRemoved], so the scan always holds
/// exactly the passed photos shown here.
class GuidedCaptureController extends ChangeNotifier {
  GuidedCaptureController({
    required this.areas,
    required PhotoCheckService checker,
    required this.onKept,
    required this.onRemoved,
    Map<String, CapturedImage> kept = const {},
    String? startAt,
  })  : assert(areas.isNotEmpty),
        _checker = checker {
    for (final area in areas) {
      final image = kept[area.id];
      if (image != null) _shots[area.id] = AreaShot(image, ShotCheck.passed);
    }
    final start = areas.indexWhere((a) => a.id == startAt);
    final open = areas.indexWhere((a) => !_shots.containsKey(a.id));
    _index = start >= 0 ? start : (open >= 0 ? open : 0);
  }

  final List<ScanRegion> areas;
  final PhotoCheckService _checker;
  final void Function(String areaId, CapturedImage image, PhotoVerdict verdict)
      onKept;
  final void Function(String areaId) onRemoved;

  final Map<String, AreaShot> _shots = {};
  final Set<String> _skipped = {};
  late int _index;
  bool _disposed = false;

  ScanRegion get current => areas[_index];
  int get index => _index;
  int get total => areas.length;

  AreaShot? shotFor(String areaId) => _shots[areaId];
  bool isSkipped(String areaId) => _skipped.contains(areaId);

  /// Areas that have a photo, in order.
  List<ScanRegion> get withPhotos => [
        for (final a in areas)
          if (_shots.containsKey(a.id)) a
      ];

  int get keptCount =>
      _shots.values.where((s) => s.check == ShotCheck.passed).length;

  bool get anyChecking =>
      _shots.values.any((s) => s.check == ShotCheck.checking);

  /// Every area has a photo or was skipped.
  bool get allVisited => areas.every(
        (a) => _shots.containsKey(a.id) || _skipped.contains(a.id),
      );

  /// Adds a photo for the current area, starts its check and moves on to the
  /// next area still to do. True when there's none left.
  bool add(CapturedImage image) {
    final id = current.id;
    if (_shots[id]?.check == ShotCheck.passed) onRemoved(id);
    _shots[id] = AreaShot(image, ShotCheck.checking);
    _skipped.remove(id);
    unawaited(_check(id, image));
    final done = _moveOn();
    _notify();
    return done;
  }

  /// Leaves the current area without a photo. True when there's none left.
  bool skip() {
    _skipped.add(current.id);
    final done = _moveOn();
    _notify();
    return done;
  }

  /// Makes [areaId] the current area, e.g. to retake it.
  void goTo(String areaId) {
    final i = areas.indexWhere((a) => a.id == areaId);
    if (i < 0 || i == _index) return;
    _index = i;
    _notify();
  }

  void delete(String areaId) {
    final shot = _shots.remove(areaId);
    if (shot == null) return;
    if (shot.check == ShotCheck.passed) onRemoved(areaId);
    _notify();
  }

  /// Checks a photo again after a check that couldn't reach a verdict.
  void recheck(String areaId) {
    final shot = _shots[areaId];
    if (shot == null || shot.check != ShotCheck.error) return;
    _shots[areaId] = AreaShot(shot.image, ShotCheck.checking);
    unawaited(_check(areaId, shot.image));
    _notify();
  }

  /// To the next area, after the current one, with no photo and not
  /// skipped. Stays put and returns true when there's none.
  bool _moveOn() {
    for (var step = 1; step <= areas.length; step++) {
      final i = (_index + step) % areas.length;
      final id = areas[i].id;
      if (!_shots.containsKey(id) && !_skipped.contains(id)) {
        _index = i;
        return false;
      }
    }
    return true;
  }

  /// Anything short of a verdict leaves the photo unchecked, never passed.
  /// A photo that passes after the screen closed still reaches the scan.
  Future<void> _check(String id, CapturedImage image) async {
    PhotoVerdict? verdict;
    PhotoCheckException? error;
    try {
      verdict = await _checker
          .check(image.bytes)
          .timeout(ScanSessionNotifier.photoCheckTimeout);
    } on PhotoCheckException catch (e) {
      error = e;
    } catch (_) {
      error = const PhotoCheckException();
    }
    // Replaced or deleted meanwhile.
    if (!identical(_shots[id]?.image, image)) return;
    if (verdict != null && verdict.passed) {
      _shots[id] = AreaShot(image, ShotCheck.passed);
      onKept(id, image, verdict);
    } else if (verdict != null) {
      _shots[id] = AreaShot(image, ShotCheck.rejected, verdict: verdict);
    } else {
      _shots[id] = AreaShot(image, ShotCheck.error, error: error);
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
