import 'dart:typed_data';

import 'package:dentra_mobile/features/camera/state/guided_capture_controller.dart';
import 'package:dentra_mobile/features/scan/data/models/captured_image.dart';
import 'package:dentra_mobile/features/scan/data/scan_regions.dart';
import 'package:dentra_mobile/features/scan/services/photo_check_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'camera_fakes.dart';

CapturedImage _photo(int n) => CapturedImage(
      bytes: Uint8List.fromList(List.filled(64, n)),
      source: CaptureSource.device,
      capturedAt: DateTime(2026, 11, 11),
    );

void main() {
  final areas = [
    scanRegionById('front'),
    scanRegionById('upper-occlusal'),
    scanRegionById('lower-occlusal'),
  ];
  late FakePhotoCheck check;
  late Map<String, CapturedImage> kept;
  late GuidedCaptureController guide;

  GuidedCaptureController make({
    Map<String, CapturedImage> already = const {},
    String? startAt,
  }) {
    check = FakePhotoCheck();
    kept = {...already};
    return guide = GuidedCaptureController(
      areas: areas,
      checker: check,
      kept: already,
      startAt: startAt,
      onKept: (id, image, verdict) {
        expect(verdict.passed, isTrue);
        kept[id] = image;
      },
      onRemoved: kept.remove,
    );
  }

  tearDown(() => guide.dispose());

  test('a photo joins the scan only once the check passes it', () async {
    make();
    final photo = _photo(1);
    expect(guide.add(photo), isFalse);
    expect(guide.shotFor('front')!.check, ShotCheck.checking);
    expect(kept, isEmpty);
    expect(guide.current.id, 'upper-occlusal', reason: 'moves on at once');

    check.pass();
    await pumpEventQueue();
    expect(guide.shotFor('front')!.check, ShotCheck.passed);
    expect(kept['front'], same(photo));
  });

  test('a rejected photo stays out, with its reason', () async {
    make();
    guide.add(_photo(1));
    check.reject(PhotoProblem.blurry);
    await pumpEventQueue();
    final shot = guide.shotFor('front')!;
    expect(shot.check, ShotCheck.rejected);
    expect(shot.verdict!.problem, PhotoProblem.blurry);
    expect(kept, isEmpty);
  });

  test('a check that cannot finish is never a pass, and can run again',
      () async {
    make();
    guide.add(_photo(1));
    check.fail();
    await pumpEventQueue();
    expect(guide.shotFor('front')!.check, ShotCheck.error);
    expect(kept, isEmpty);

    guide.recheck('front');
    expect(guide.shotFor('front')!.check, ShotCheck.checking);
    check.pass(1);
    await pumpEventQueue();
    expect(kept.keys, ['front']);
  });

  test('skips and photos until every area is visited', () {
    make();
    expect(guide.add(_photo(1)), isFalse);
    expect(guide.skip(), isFalse);
    expect(guide.current.id, 'lower-occlusal');
    expect(guide.add(_photo(2)), isTrue, reason: 'none left');
    expect(guide.allVisited, isTrue);
    expect(guide.isSkipped('upper-occlusal'), isTrue);
    expect(guide.withPhotos.map((a) => a.id), ['front', 'lower-occlusal']);
    // Leave no check (and its timeout timer) behind.
    check
      ..pass(0)
      ..pass(1);
  });

  test('retaking a kept photo takes the old one back out of the scan',
      () async {
    make();
    final first = _photo(1);
    guide.add(first);
    check.pass();
    await pumpEventQueue();
    expect(kept['front'], same(first));

    guide.goTo('front');
    final second = _photo(2);
    guide.add(second);
    expect(kept, isEmpty, reason: 'the old one is replaced');
    check.reject(PhotoProblem.tooDark, 1);
    await pumpEventQueue();
    expect(kept, isEmpty, reason: 'the new one did not pass');
  });

  test('a late verdict for a replaced photo is ignored', () async {
    make();
    guide.add(_photo(1));
    guide.goTo('front');
    final second = _photo(2);
    guide.add(second);
    check.pass(0); // the first photo's check, now stale
    await pumpEventQueue();
    expect(kept, isEmpty);
    expect(guide.shotFor('front')!.image, same(second));
    check.pass(1);
    await pumpEventQueue();
    expect(kept['front'], same(second));
  });

  test('deleting a kept photo takes it out of the scan', () async {
    make();
    guide.add(_photo(1));
    check.pass();
    await pumpEventQueue();
    guide.delete('front');
    expect(kept, isEmpty);
    expect(guide.shotFor('front'), isNull);
  });

  test('photos already in the scan show as done, and it starts at the first '
      'area still to do', () {
    make(already: {'front': _photo(1)});
    expect(guide.shotFor('front')!.check, ShotCheck.passed);
    expect(guide.current.id, 'upper-occlusal');
    expect(guide.keptCount, 1);

    guide.dispose();
    make(already: {'front': _photo(1)}, startAt: 'front');
    expect(guide.current.id, 'front');
  });

  test('a photo that passes after the screen closed still reaches the scan',
      () async {
    make();
    guide.add(_photo(1));
    guide.dispose();
    check.pass();
    await pumpEventQueue();
    expect(kept.keys, ['front']);
    // tearDown disposes again; make a fresh one so that's harmless.
    make();
  });
}
