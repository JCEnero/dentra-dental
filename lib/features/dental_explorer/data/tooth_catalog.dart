/// The 32 permanent teeth, numbered with the FDI two-digit system.
///
/// First digit: quadrant (1 upper right, 2 upper left, 3 lower left,
/// 4 lower right, from the patient's point of view). Second digit:
/// position counted from the midline (1 central incisor … 8 third molar).
library;

enum ToothArch {
  upper('Upper'),
  lower('Lower');

  const ToothArch(this.label);
  final String label;
}

/// The patient's own side.
enum ToothSide {
  right('Right'),
  left('Left');

  const ToothSide(this.label);
  final String label;
}

enum ToothType {
  incisor('Incisor', 'Incisors'),
  canine('Canine', 'Canines'),
  premolar('Premolar', 'Premolars'),
  molar('Molar', 'Molars');

  const ToothType(this.label, this.plural);
  final String label;
  final String plural;
}

/// Average crown and root measurements in millimetres (Wheeler's
/// reference values), used to shape the 3D model.
class ToothDimensions {
  const ToothDimensions({
    required this.crownLength,
    required this.mesiodistal,
    required this.mesiodistalCervical,
    required this.buccolingual,
    required this.buccolingualCervical,
    required this.rootLength,
  });

  final double crownLength;
  final double mesiodistal;
  final double mesiodistalCervical;
  final double buccolingual;
  final double buccolingualCervical;
  final double rootLength;

  double get totalLength => crownLength + rootLength;
}

class ToothInfo {
  const ToothInfo._(this.fdi);

  /// FDI number, e.g. 11 or 36.
  final int fdi;

  int get quadrant => fdi ~/ 10;

  /// 1 (central incisor) to 8 (third molar), counted from the midline.
  int get position => fdi % 10;

  /// Stable 0–31 id, used to tag the tooth's geometry.
  int get index => (quadrant - 1) * 8 + (position - 1);

  ToothArch get arch => quadrant <= 2 ? ToothArch.upper : ToothArch.lower;

  ToothSide get side =>
      quadrant == 1 || quadrant == 4 ? ToothSide.right : ToothSide.left;

  ToothType get type => switch (position) {
        1 || 2 => ToothType.incisor,
        3 => ToothType.canine,
        4 || 5 => ToothType.premolar,
        _ => ToothType.molar,
      };

  /// Incisors and canines.
  bool get isFront => position <= 3;

  String get positionName => _positionNames[position - 1];

  /// e.g. "Upper right first molar".
  String get name =>
      '${arch.label} ${side.label.toLowerCase()} ${positionName.toLowerCase()}';

  String get quadrantName => '${arch.label} ${side.label.toLowerCase()}';

  ToothDimensions get dimensions => arch == ToothArch.upper
      ? _upperDimensions[position - 1]
      : _lowerDimensions[position - 1];

  @override
  String toString() => 'Tooth $fdi';

  static const _positionNames = [
    'Central incisor',
    'Lateral incisor',
    'Canine',
    'First premolar',
    'Second premolar',
    'First molar',
    'Second molar',
    'Third molar',
  ];
}

abstract class ToothCatalog {
  /// All 32 teeth, ordered by [ToothInfo.index].
  static final List<ToothInfo> all = [
    for (var q = 1; q <= 4; q++)
      for (var p = 1; p <= 8; p++) ToothInfo._(q * 10 + p),
  ];

  static ToothInfo byIndex(int index) => all[index];

  static ToothInfo? byFdi(int fdi) {
    final q = fdi ~/ 10, p = fdi % 10;
    if (q < 1 || q > 4 || p < 1 || p > 8) return null;
    return all[(q - 1) * 8 + (p - 1)];
  }

  /// Upper row as on a dental chart, facing the patient: 18 … 11, 21 … 28.
  static final List<ToothInfo> upperChartRow = [
    for (var p = 8; p >= 1; p--) byFdi(10 + p)!,
    for (var p = 1; p <= 8; p++) byFdi(20 + p)!,
  ];

  /// Lower row as on a dental chart, facing the patient: 48 … 41, 31 … 38.
  static final List<ToothInfo> lowerChartRow = [
    for (var p = 8; p >= 1; p--) byFdi(40 + p)!,
    for (var p = 1; p <= 8; p++) byFdi(30 + p)!,
  ];

  /// Chart order (upper row, then lower row), used for previous/next.
  static final List<ToothInfo> chartOrder = [
    ...upperChartRow,
    ...lowerChartRow,
  ];

  static int countOf(ToothType type) => all.where((t) => t.type == type).length;
}

const _upperDimensions = [
  ToothDimensions(
      crownLength: 10.5,
      mesiodistal: 8.5,
      mesiodistalCervical: 7.0,
      buccolingual: 7.0,
      buccolingualCervical: 6.0,
      rootLength: 13),
  ToothDimensions(
      crownLength: 9.0,
      mesiodistal: 6.5,
      mesiodistalCervical: 5.0,
      buccolingual: 6.0,
      buccolingualCervical: 5.0,
      rootLength: 13),
  ToothDimensions(
      crownLength: 10.0,
      mesiodistal: 7.5,
      mesiodistalCervical: 5.5,
      buccolingual: 8.0,
      buccolingualCervical: 7.0,
      rootLength: 17),
  ToothDimensions(
      crownLength: 8.5,
      mesiodistal: 7.0,
      mesiodistalCervical: 5.0,
      buccolingual: 9.0,
      buccolingualCervical: 8.0,
      rootLength: 14),
  ToothDimensions(
      crownLength: 8.5,
      mesiodistal: 7.0,
      mesiodistalCervical: 5.0,
      buccolingual: 9.0,
      buccolingualCervical: 8.0,
      rootLength: 14),
  ToothDimensions(
      crownLength: 7.5,
      mesiodistal: 10.0,
      mesiodistalCervical: 8.0,
      buccolingual: 11.0,
      buccolingualCervical: 10.0,
      rootLength: 12.5),
  ToothDimensions(
      crownLength: 7.0,
      mesiodistal: 9.0,
      mesiodistalCervical: 7.0,
      buccolingual: 11.0,
      buccolingualCervical: 10.0,
      rootLength: 12),
  ToothDimensions(
      crownLength: 6.5,
      mesiodistal: 8.5,
      mesiodistalCervical: 6.5,
      buccolingual: 10.0,
      buccolingualCervical: 9.0,
      rootLength: 11),
];

const _lowerDimensions = [
  ToothDimensions(
      crownLength: 9.0,
      mesiodistal: 5.0,
      mesiodistalCervical: 3.5,
      buccolingual: 6.0,
      buccolingualCervical: 5.3,
      rootLength: 12.5),
  ToothDimensions(
      crownLength: 9.5,
      mesiodistal: 5.5,
      mesiodistalCervical: 4.0,
      buccolingual: 6.5,
      buccolingualCervical: 5.8,
      rootLength: 14),
  ToothDimensions(
      crownLength: 11.0,
      mesiodistal: 7.0,
      mesiodistalCervical: 5.5,
      buccolingual: 7.5,
      buccolingualCervical: 7.0,
      rootLength: 16),
  ToothDimensions(
      crownLength: 8.5,
      mesiodistal: 7.0,
      mesiodistalCervical: 5.0,
      buccolingual: 7.5,
      buccolingualCervical: 6.5,
      rootLength: 14),
  ToothDimensions(
      crownLength: 8.0,
      mesiodistal: 7.0,
      mesiodistalCervical: 5.0,
      buccolingual: 8.0,
      buccolingualCervical: 7.0,
      rootLength: 14.5),
  ToothDimensions(
      crownLength: 7.5,
      mesiodistal: 11.0,
      mesiodistalCervical: 9.0,
      buccolingual: 10.5,
      buccolingualCervical: 9.0,
      rootLength: 14),
  ToothDimensions(
      crownLength: 7.0,
      mesiodistal: 10.5,
      mesiodistalCervical: 8.0,
      buccolingual: 10.0,
      buccolingualCervical: 9.0,
      rootLength: 13),
  ToothDimensions(
      crownLength: 7.0,
      mesiodistal: 10.0,
      mesiodistalCervical: 7.5,
      buccolingual: 9.5,
      buccolingualCervical: 9.0,
      rootLength: 11),
];
