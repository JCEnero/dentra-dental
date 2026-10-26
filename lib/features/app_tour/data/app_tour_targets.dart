import 'package:flutter/widgets.dart';

import 'app_tour_steps.dart';

/// Keys on everything the app tour points at. Each app shell owns its
/// own set, so two shells on screen during a route change never share a
/// key.
class AppTourTargets {
  AppTourTargets(int tabCount)
      : tabs = List.generate(tabCount, (_) => GlobalKey());

  /// Dock buttons, in dock order.
  final List<GlobalKey> tabs;

  // Home's service buttons and bell.
  final GlobalKey teeth = GlobalKey();
  final GlobalKey treatment = GlobalKey();
  final GlobalKey comparison = GlobalKey();
  final GlobalKey rabi = GlobalKey();
  final GlobalKey notifications = GlobalKey();

  GlobalKey keyFor(TourSpot spot) => switch (spot) {
        TourSpot.teeth => teeth,
        TourSpot.treatment => treatment,
        TourSpot.comparison => comparison,
        TourSpot.rabi => rabi,
        TourSpot.notifications => notifications,
        _ => tabs[spot.dockIndex!],
      };
}
