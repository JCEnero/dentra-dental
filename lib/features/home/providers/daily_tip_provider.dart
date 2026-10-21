import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/dentra_dates.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/daily_tip_repository.dart';

/// Today's date (local, time stripped). Moves on at midnight, and is
/// re-checked when the app returns to the foreground, since timers don't
/// run while it's suspended.
class CurrentDayNotifier extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    final listener = AppLifecycleListener(onResume: _sync);
    ref.onDispose(() {
      _timer?.cancel();
      listener.dispose();
    });
    final today = DentraDates.dateOnly(DateTime.now());
    _scheduleAfter(today);
    return today;
  }

  void _sync() {
    final today = DentraDates.dateOnly(DateTime.now());
    if (today != state) state = today;
    _scheduleAfter(today);
  }

  void _scheduleAfter(DateTime day) {
    _timer?.cancel();
    final next = DateTime(day.year, day.month, day.day + 1);
    // A second past midnight, so the new day has surely begun.
    _timer = Timer(next.difference(DateTime.now()) + const Duration(seconds: 1), _sync);
  }
}

final currentDayProvider =
    NotifierProvider<CurrentDayNotifier, DateTime>(CurrentDayNotifier.new);

final dailyTipRepositoryProvider = Provider<DailyTipRepository>(
  (ref) => DailyTipRepository(ref.watch(apiClientProvider)),
);

/// The tip for a given day. Home watches it with [currentDayProvider], so
/// a new tip loads when the date changes.
final dailyTipProvider = FutureProvider.family<DailyTip, DateTime>(
  (ref, day) => ref.watch(dailyTipRepositoryProvider).tipFor(day),
);
