import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dental_explorer/screens/dental_explorer_screen.dart';
import '../state/history_entry.dart';
import '../widgets/tooth_history.dart';

/// Dental Explorer with the user's history attached: the chart marks
/// teeth that have history items, and each tooth's panel gets a History
/// tab. Uses the explorer's own chart, so there is one dental chart.
class ToothHistoryExplorer extends ConsumerWidget {
  const ToothHistoryExplorer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DentalExplorerScreen(
      markedTeeth: ref.watch(teethWithHistoryProvider),
      historyBuilder: (tooth) => ToothHistoryList(
        fdi: tooth.fdi,
        onOpen: (entry) => openHistoryEntry(context, entry),
      ),
    );
  }
}
