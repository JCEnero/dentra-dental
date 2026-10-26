import 'package:flutter/foundation.dart';

import '../data/tooth_catalog.dart';

/// Quick-view regions: which teeth stay in focus.
enum ExplorerRegion {
  all('All teeth'),
  upper('Upper'),
  lower('Lower'),
  front('Front'),
  back('Back');

  const ExplorerRegion(this.label);
  final String label;

  /// Whether [tooth] is emphasised in this region.
  bool includes(ToothInfo tooth) => switch (this) {
        ExplorerRegion.all => true,
        ExplorerRegion.upper => tooth.arch == ToothArch.upper,
        ExplorerRegion.lower => tooth.arch == ToothArch.lower,
        ExplorerRegion.front => tooth.isFront,
        ExplorerRegion.back => !tooth.isFront,
      };

  /// Upper and Lower hide the opposite arch entirely; the others keep
  /// both arches and fade the teeth outside the region.
  bool showsArch(ToothArch arch) => switch (this) {
        ExplorerRegion.upper => arch == ToothArch.upper,
        ExplorerRegion.lower => arch == ToothArch.lower,
        _ => true,
      };
}

/// What the explorer shows: selection, region and display toggles.
/// Camera movement lives in `ExplorerCamera`.
class ExplorerController extends ChangeNotifier {
  ToothInfo? _selected;
  ExplorerRegion _region = ExplorerRegion.all;
  bool _showNumbers = false;
  bool _colorByType = false;
  bool _showGums = true;

  ToothInfo? get selected => _selected;
  ExplorerRegion get region => _region;
  bool get showNumbers => _showNumbers;
  bool get colorByType => _colorByType;
  bool get showGums => _showGums;

  /// Whether [tooth] can be seen at all in the current region.
  bool isVisible(ToothInfo tooth) => _region.showsArch(tooth.arch);

  void select(ToothInfo? tooth) {
    if (tooth == _selected) return;
    // Selecting a tooth on a hidden arch brings every tooth back.
    if (tooth != null && !isVisible(tooth)) _region = ExplorerRegion.all;
    _selected = tooth;
    notifyListeners();
  }

  void clearSelection() => select(null);

  /// Steps through the chart order (upper row, then lower row).
  ToothInfo neighbour(ToothInfo tooth, int step) {
    final order = ToothCatalog.chartOrder;
    final i = order.indexOf(tooth);
    return order[(i + step) % order.length];
  }

  void setRegion(ExplorerRegion region) {
    if (region == _region) return;
    _region = region;
    final s = _selected;
    if (s != null && !isVisible(s)) _selected = null;
    notifyListeners();
  }

  void toggleNumbers() {
    _showNumbers = !_showNumbers;
    notifyListeners();
  }

  void toggleColorByType() {
    _colorByType = !_colorByType;
    notifyListeners();
  }

  void toggleGums() {
    _showGums = !_showGums;
    notifyListeners();
  }
}
