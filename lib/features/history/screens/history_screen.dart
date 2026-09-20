import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/models/screening_model.dart';
import '../../../core/services/mock_data.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  int _activeDate = 7;

  final _weekDates = const [
    {'day': 'Wed', 'date': 5},
    {'day': 'Thu', 'date': 6},
    {'day': 'Fri', 'date': 7},
    {'day': 'Sat', 'date': 8},
    {'day': 'Sun', 'date': 9},
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, 20, AppSpacing.screenH, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Screening History',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Track your dental health over time',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),

            // ── CALENDAR WIDGET ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, 20, AppSpacing.screenH, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.g1.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  children: [
                    // Month nav
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.chevron_left_rounded,
                              size: 18),
                          color: AppColors.secondaryText,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        Row(
                          children: [
                            Text(
                              'Aug',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'September',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Oct',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.chevron_right_rounded,
                              size: 18),
                          color: AppColors.secondaryText,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Date row
                    Row(
                      children: _weekDates.map((wd) {
                        final date    = wd['date'] as int;
                        final day     = wd['day'] as String;
                        final isActive = _activeDate == date;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _activeDate = date),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    day,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isActive
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : AppColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$date',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: isActive
                                          ? AppColors.white
                                          : AppColors.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            // ── ONGOING LABEL ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, 20, AppSpacing.screenH, 12),
              child: Text(
                'Ongoing',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),

            // ── SCREENING CARDS ───────────────────────────────────
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenH, 0, AppSpacing.screenH, 24),
                itemCount: MockData.screenings.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final s = MockData.screenings[i];
                  final isEven = i % 2 == 0;
                  return _ScreeningCard(
                    screening: s,
                    isFirst: i == 0,
                    isEven: isEven,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScreeningCard extends StatelessWidget {
  final ScreeningModel screening;
  final bool isFirst;
  final bool isEven;

  const _ScreeningCard({
    required this.screening,
    required this.isFirst,
    required this.isEven,
  });

  @override
  Widget build(BuildContext context) {
    // White card with teal accent border — alternates teal shade per card
    final tealBorder = isEven
        ? const Color(0xFF2CA6A4)
        : const Color(0xFF3BBFB8);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tealBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: tealBorder.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  screening.fullDate,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Dental Screening',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 6),
                // Avatar circles + image count
                Row(
                  children: [
                    ...List.generate(
                      screening.images.clamp(0, 3),
                      (j) => Transform.translate(
                        offset: Offset(j > 0 ? -6.0 * j : 0, 0),
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2CA6A4)
                                .withValues(alpha: 0.18 - j * 0.04),
                            border: Border.all(
                              color: const Color(0xFF2CA6A4).withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${screening.images} images',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: AppColors.navy.withValues(alpha: 0.55),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${screening.teeth} teeth detected · ${screening.region}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.navy.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),

          // Right column
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2CA6A4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isFirst ? 'Latest' : 'View',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2CA6A4),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Icon(Icons.arrow_forward_rounded,
                  size: 14, color: const Color(0xFF2CA6A4).withValues(alpha: 0.7)),
            ],
          ),
        ],
      ),
    );
  }
}
