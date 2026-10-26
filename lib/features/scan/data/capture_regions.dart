/// The eight photo views of the guided scan. Together they cover every
/// surface: the front, both biting surfaces, both sides, the tongue side
/// of each arch and the back molars.
///
/// Each view also says which teeth it shows (used for its guide and for
/// which teeth a scan can assess) and where a camera looks from to draw
/// its 3D guide.
library;

import 'dart:math' as math;

import '../../dental_explorer/data/tooth_catalog.dart';

/// Which arches a view shows.
enum ViewArches {
  upper,
  lower,
  both;

  bool shows(ToothArch arch) => switch (this) {
        ViewArches.upper => arch == ToothArch.upper,
        ViewArches.lower => arch == ToothArch.lower,
        ViewArches.both => true,
      };
}

class CaptureRegion {
  const CaptureRegion({
    required this.id,
    required this.number,
    required this.label,
    required this.shortLabel,
    required this.technical,
    required this.instruction,
    required this.tips,
    required this.arches,
    required this.covers,
    required this.yaw,
    required this.pitch,
    this.zoom = 1,
  });

  final String id;

  /// 1–8, the guided order.
  final int number;
  final String label;

  /// Compact name for checklists and charts.
  final String shortLabel;

  /// Clinical name of the view, e.g. "Upper Occlusal".
  final String technical;

  /// One-line positioning summary.
  final String instruction;

  /// Step-by-step positioning tips.
  final List<String> tips;

  final ViewArches arches;

  /// The teeth this view shows clearly: highlighted in its guide, and
  /// assessed when its photo is captured.
  final bool Function(ToothInfo tooth) covers;

  /// Guide camera, as for `CameraPose` (radians).
  final double yaw;
  final double pitch;

  /// Below 1 moves the guide camera closer than the fitted framing.
  final double zoom;

  /// "01" … "08".
  String get code => number.toString().padLeft(2, '0');
}

bool _frontTeeth(ToothInfo t) => t.position <= 3;
bool _upperArch(ToothInfo t) => t.arch == ToothArch.upper;
bool _lowerArch(ToothInfo t) => t.arch == ToothArch.lower;
bool _leftSide(ToothInfo t) => t.side == ToothSide.left && t.position >= 3;
bool _rightSide(ToothInfo t) => t.side == ToothSide.right && t.position >= 3;
bool _molars(ToothInfo t) => t.position >= 6;

const List<CaptureRegion> captureRegions = [
  CaptureRegion(
    id: 'front',
    number: 1,
    label: 'Front Teeth',
    shortLabel: 'Front',
    technical: 'Labial',
    instruction: 'Smile with your teeth together, camera straight on.',
    tips: [
      'Bite your back teeth together and smile wide so your lips pull back.',
      'Hold the camera level with your front teeth, about 10 cm away.',
      'Use bright, even light. Skip the flash if it causes glare.',
      'Keep the upper and lower front teeth centered in the frame.',
    ],
    arches: ViewArches.both,
    covers: _frontTeeth,
    yaw: 0,
    pitch: 0.06,
    zoom: 1.2,
  ),
  CaptureRegion(
    id: 'upper-occlusal',
    number: 2,
    label: 'Upper Biting Surface',
    shortLabel: 'Upper Biting',
    technical: 'Upper Occlusal',
    instruction: 'Tilt your head back and open wide.',
    tips: [
      'Tilt your head back and open as wide as is comfortable.',
      'Point the camera up at the chewing surfaces of your upper teeth.',
      'A small mirror helps: photograph the reflection.',
      'Fit every upper tooth, front to back, in the frame.',
    ],
    arches: ViewArches.upper,
    covers: _upperArch,
    yaw: 0,
    pitch: -math.pi / 2,
  ),
  CaptureRegion(
    id: 'lower-occlusal',
    number: 3,
    label: 'Lower Biting Surface',
    shortLabel: 'Lower Biting',
    technical: 'Lower Occlusal',
    instruction: 'Tilt your head down and open wide.',
    tips: [
      'Tilt your head down and open wide.',
      'Rest your tongue behind your lower front teeth, out of the way.',
      'Point the camera down at the chewing surfaces of your lower teeth.',
      'Fit every lower tooth, front to back, in the frame.',
    ],
    arches: ViewArches.lower,
    covers: _lowerArch,
    yaw: 0,
    pitch: math.pi / 2,
  ),
  CaptureRegion(
    id: 'left',
    number: 4,
    label: 'Left Side',
    shortLabel: 'Left',
    technical: 'Left Buccal',
    instruction: 'Pull your left cheek back and bite together.',
    tips: [
      'Bite your back teeth together.',
      'Pull your left cheek back with a finger or a cheek retractor.',
      'Hold the camera at your side, level with your teeth.',
      'Get the last molar you can see into the frame.',
    ],
    arches: ViewArches.both,
    covers: _leftSide,
    yaw: -math.pi / 2 + 0.22,
    pitch: 0.06,
  ),
  CaptureRegion(
    id: 'right',
    number: 5,
    label: 'Right Side',
    shortLabel: 'Right',
    technical: 'Right Buccal',
    instruction: 'Pull your right cheek back and bite together.',
    tips: [
      'Bite your back teeth together.',
      'Pull your right cheek back with a finger or a cheek retractor.',
      'Hold the camera at your side, level with your teeth.',
      'Get the last molar you can see into the frame.',
    ],
    arches: ViewArches.both,
    covers: _rightSide,
    yaw: math.pi / 2 - 0.22,
    pitch: 0.06,
  ),
  CaptureRegion(
    id: 'upper-lingual',
    number: 6,
    label: 'Back of Upper Teeth',
    shortLabel: 'Upper Back',
    technical: 'Upper Lingual · Palatal',
    instruction: 'Open wide and angle the camera up toward the roof of your mouth.',
    tips: [
      'Open wide and tilt your head back a little.',
      'Hold the camera just below your lower front teeth.',
      'Angle it up to see the roof-of-mouth side of your upper teeth.',
      "Use a mirror if the camera can't reach the angle.",
    ],
    arches: ViewArches.upper,
    covers: _upperArch,
    yaw: math.pi,
    pitch: -0.62,
  ),
  CaptureRegion(
    id: 'lower-lingual',
    number: 7,
    label: 'Back of Lower Teeth',
    shortLabel: 'Lower Back',
    technical: 'Lower Lingual',
    instruction: 'Open, lift your tongue and angle the camera down.',
    tips: [
      'Open your mouth and lift your tongue to the roof of your mouth.',
      'Hold the camera just above your upper front teeth.',
      'Angle it down to see the tongue side of your lower teeth.',
      'Take your time here: this area builds up tartar easily.',
    ],
    arches: ViewArches.lower,
    covers: _lowerArch,
    yaw: math.pi,
    pitch: 0.62,
  ),
  CaptureRegion(
    id: 'posterior',
    number: 8,
    label: 'Back Molars',
    shortLabel: 'Molars',
    technical: 'Posterior',
    instruction: 'Open wide and focus on your rearmost teeth.',
    tips: [
      'Open wide and relax your jaw.',
      'Move the camera to the corner of your mouth.',
      'Focus on the last two or three teeth on each side.',
      'Include the wisdom tooth area if you have one.',
    ],
    arches: ViewArches.both,
    covers: _molars,
    yaw: math.pi,
    pitch: 0.14,
  ),
];

CaptureRegion captureRegionById(String id) =>
    captureRegions.firstWhere((r) => r.id == id);
