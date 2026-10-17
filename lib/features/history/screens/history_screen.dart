import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../screening/data/models/screening_session.dart';
import '../../screening/providers/screening_sessions_provider.dart';
import '../state/history_controller.dart';
import '../state/history_query.dart';
import '../widgets/history_calendar.dart';
import '../widgets/history_filter_sheet.dart';
import '../widgets/screening_history_card.dart';
import 'screening_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.onBack, this.onNavigate});

  /// Called by the header's back button; hidden when null.
  final VoidCallback? onBack;

  /// Switches the app shell's tab (used to start a scan).
  final ValueChanged<int>? onNavigate;

  /// Index of the Scan tab in `AppShell`.
  static const scanTab = 1;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchOpen = false;

  HistoryController get _controller =>
      ref.read(historyControllerProvider.notifier);

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      _searchFocus.requestFocus();
    } else {
      _searchCtrl.clear();
      _controller.setQuery('');
      _searchFocus.unfocus();
    }
  }

  void _reset() {
    _searchCtrl.clear();
    _controller.resetFilters();
    if (_searchOpen) setState(() => _searchOpen = false);
  }

  void _open(ScreeningSession s) {
    FocusScope.of(context).unfocus();
    Navigator.of(context, rootNavigator: true)
        .push(ScreeningDetailScreen.route(s.id));
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(screeningSessionsProvider);
    final view = ref.watch(historyControllerProvider);
    final results = ref.watch(historyResultsProvider);
    final all = sessionsAsync.valueOrNull ?? const <ScreeningSession>[];

    final thisMonth = DentraDates.monthOf(DateTime.now());
    final earliest =
        all.isEmpty ? thisMonth : DentraDates.monthOf(all.last.completedAt);

    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── HEADER ──────────────────────────────────────────
          DentraPageHeader(
            title: 'Screening History',
            onBack: widget.onBack,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderButton(
                  icon: _searchOpen ? Icons.search_off_rounded : Icons.search_rounded,
                  tooltip: _searchOpen ? 'Close search' : 'Search history',
                  active: _searchOpen,
                  onPressed: _toggleSearch,
                ),
                const SizedBox(width: 8),
                _HeaderButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Filter and sort',
                  active: !view.filters.isDefault,
                  badge: view.filters.activeCount,
                  onPressed: () => showHistoryFilterSheet(context),
                ),
              ],
            ),
            bottom: AnimatedSize(
              duration: dentraMotion(context),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _searchOpen
                  ? _SearchField(
                      controller: _searchCtrl,
                      focusNode: _searchFocus,
                      onChanged: _controller.setQuery,
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
          Divider(height: 1, thickness: 1, color: AppGlass.divider),

          // ── BODY ────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.refresh(screeningSessionsProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 16,
                    AppSpacing.screenH, 24 + MediaQuery.paddingOf(context).bottom),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          HistoryCalendar(
                            month: view.month,
                            weekStart: view.weekStart,
                            selectedDay: view.usesCalendar ? view.day : null,
                            markedDays: {
                              for (final s in all)
                                DentraDates.dateOnly(s.completedAt),
                            },
                            dimmed: !view.usesCalendar,
                            canGoBack: view.month.isAfter(earliest),
                            canGoForward: view.month.isBefore(thisMonth),
                            onShiftMonth: (d) =>
                                _controller.shiftMonth(d, sessions: all),
                            onShiftWeek: _controller.shiftWeek,
                            onDayTap: (day) {
                              // Picking a day returns to calendar mode.
                              if (!view.usesCalendar) _reset();
                              _controller.toggleDay(day);
                            },
                          ),
                          _ListHeader(
                            view: view,
                            count: results.valueOrNull?.length,
                            onWholeMonth: _controller.clearDay,
                            onReset: _reset,
                          ),
                          _buildResults(results, all, view),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(
    AsyncValue<List<ScreeningSession>> results,
    List<ScreeningSession> all,
    HistoryViewState view,
  ) {
    final Widget child;
    if (results.hasError && !results.hasValue) {
      child = HistoryMessage(
        key: const ValueKey('error'),
        icon: Icons.cloud_off_rounded,
        danger: true,
        title: "We couldn't load your history",
        message: 'Check your connection and try again.',
        actions: [
          DentraPillButton(
            label: 'Try again',
            onPressed: () => ref.invalidate(screeningSessionsProvider),
          ),
        ],
      );
    } else if (!results.hasValue) {
      child = const Column(
        key: ValueKey('loading'),
        children: [
          ScreeningCardSkeleton(),
          SizedBox(height: 10),
          ScreeningCardSkeleton(),
          SizedBox(height: 10),
          ScreeningCardSkeleton(),
        ],
      );
    } else if (results.requireValue.isEmpty) {
      child = _emptyState(all, view);
    } else {
      child = _ResultsList(
        key: ValueKey(
            '${view.month}${view.day}${view.query}${view.filters.activeCount}'
            '${view.filters.sort}'),
        sessions: results.requireValue,
        latestId: all.firstOrNull?.id,
        grouped: !view.usesCalendar,
        onOpen: _open,
      );
    }

    return AnimatedSwitcher(
      duration: dentraMotion(context, 220),
      switchInCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      child: child,
    );
  }

  Widget _emptyState(List<ScreeningSession> all, HistoryViewState view) {
    if (all.isEmpty) {
      return HistoryMessage(
        key: const ValueKey('empty-all'),
        icon: Icons.document_scanner_outlined,
        title: 'No screenings yet',
        message: 'Your completed screenings will appear here.',
        actions: [
          if (widget.onNavigate != null)
            DentraPillButton(
              label: 'Start a screening',
              icon: Icons.add_rounded,
              onPressed: () => widget.onNavigate!(HistoryScreen.scanTab),
            ),
        ],
      );
    }
    if (view.isSearching || !view.filters.isDefault) {
      return HistoryMessage(
        key: const ValueKey('empty-filtered'),
        icon: Icons.search_off_rounded,
        title: 'No matching screenings',
        message: view.isSearching
            ? 'Nothing matches "${view.query.trim()}". Try a date like '
                '"Sep 7" or a region like "upper left".'
            : 'No screenings match these filters.',
        actions: [
          DentraPillButton(
            label: 'Reset search and filters',
            variant: DentraButtonVariant.outline,
            onPressed: _reset,
          ),
        ],
      );
    }
    if (view.day != null) {
      return HistoryMessage(
        key: const ValueKey('empty-day'),
        icon: Icons.event_busy_outlined,
        title: 'No screening on ${DentraDates.medium(view.day!)}',
        message: 'Days with a dot have screenings.',
        actions: [
          DentraPillButton(
            label: 'Show all of ${DentraDates.monthNames[view.month.month - 1]}',
            variant: DentraButtonVariant.outline,
            onPressed: _controller.clearDay,
          ),
        ],
      );
    }
    final latest = all.first.completedAt;
    return HistoryMessage(
      key: const ValueKey('empty-month'),
      icon: Icons.event_note_outlined,
      title: 'No screenings in ${DentraDates.monthYear(view.month)}',
      message: 'Your latest screening was on ${DentraDates.medium(latest)}.',
      actions: [
        DentraPillButton(
          label: 'Go to latest screening',
          onPressed: () {
            _controller.goToMonth(latest, sessions: all);
            _controller.toggleDay(latest);
          },
        ),
        DentraPillButton(
          label: 'View all screenings',
          variant: DentraButtonVariant.outline,
          onPressed: () => _controller.setFilters(
            view.filters.copyWith(scope: HistoryScope.allTime),
          ),
        ),
      ],
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
    this.badge = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onPressed,
          tooltip: badge > 0 ? '$tooltip, $badge active' : tooltip,
          isSelected: active,
          style: IconButton.styleFrom(
            backgroundColor:
                active ? AppColors.g2.withValues(alpha: 0.14) : AppColors.lightLavender,
            foregroundColor: active ? AppColors.g2 : AppColors.navy,
            fixedSize: const Size(44, 44),
            minimumSize: const Size(44, 44),
          ),
          icon: Icon(icon, size: 20),
        ),
        if (badge > 0)
          Positioned(
            right: -2,
            top: -2,
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minWidth: 18),
                height: 18,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.g2,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: AppColors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$badge',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.navy),
        decoration: InputDecoration(
          hintText: 'Search by date, region or status',
          hintStyle: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.secondaryText.withValues(alpha: 0.7),
          ),
          prefixIcon: const Icon(Icons.search_rounded,
              size: 20, color: AppColors.secondaryText),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.secondaryText),
                ),
          filled: true,
          fillColor: AppColors.white.withValues(alpha: 0.7),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder: const OutlineInputBorder(
            borderRadius: AppRadius.lgAll,
            borderSide: BorderSide(color: AppGlass.border),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: AppRadius.lgAll,
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  const _ListHeader({
    required this.view,
    required this.count,
    required this.onWholeMonth,
    required this.onReset,
  });

  final HistoryViewState view;
  final int? count;
  final VoidCallback onWholeMonth;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final title = view.isSearching
        ? 'Search results'
        : !view.usesCalendar
            ? 'All screenings'
            : view.day != null
                ? DentraDates.long(view.day!)
                : DentraDates.monthYear(view.month);

    final Widget? action = view.isSearching || !view.filters.isDefault
        ? _HeaderLink(label: 'Reset', onTap: onReset)
        : view.day != null
            ? _HeaderLink(label: 'Whole month', onTap: onWholeMonth)
            : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 0, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: AnimatedSwitcher(
                    duration: dentraMotion(context, 180),
                    child: Text(
                      title,
                      key: ValueKey(title),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    '$count ${count == 1 ? 'screening' : 'screenings'}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.g2,
        minimumSize: const Size(44, 44),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    super.key,
    required this.sessions,
    required this.latestId,
    required this.grouped,
    required this.onOpen,
  });

  final List<ScreeningSession> sessions;
  final String? latestId;

  /// Adds month headings, for lists that span many months.
  final bool grouped;
  final ValueChanged<ScreeningSession> onOpen;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    DateTime? month;
    for (var i = 0; i < sessions.length; i++) {
      final s = sessions[i];
      final m = DentraDates.monthOf(s.completedAt);
      if (grouped && m != month) {
        children.add(Padding(
          padding: EdgeInsets.fromLTRB(4, children.isEmpty ? 0 : 10, 4, 8),
          child: Text(
            DentraDates.monthYear(m).toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: AppColors.secondaryText,
            ),
          ),
        ));
        month = m;
      } else if (children.isNotEmpty) {
        children.add(const SizedBox(height: 10));
      }
      children.add(ScreeningHistoryCard(
        key: ValueKey(s.id),
        session: s,
        isLatest: s.id == latestId,
        alternate: i.isOdd,
        onTap: () => onOpen(s),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
