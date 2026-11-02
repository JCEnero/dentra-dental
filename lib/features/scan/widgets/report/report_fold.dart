import 'package:flutter/material.dart';

import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/constants/app_colors.dart';
import '../scan_motion.dart';
import '../scan_theme.dart';
import 'report_style.dart';

/// A closed glass row with its answer in one line; tap for the detail. It keeps
/// the page short, and what's inside is only built once it's opened.
class ReportFold extends StatefulWidget {
  const ReportFold({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String summary;
  final Widget child;

  @override
  State<ReportFold> createState() => _ReportFoldState();
}

class _ReportFoldState extends State<ReportFold> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final duration = ScanMotion.of(context, ScanMotion.medium);
    return GlassCard(
      width: double.infinity,
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    ScanIconDisc(widget.icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title, style: reportCardTitle),
                          Text(widget.summary, style: reportNote),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: duration,
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            curve: ScanMotion.curve,
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}
