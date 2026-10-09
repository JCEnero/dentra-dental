// lib/features/treatment/screens/treatment_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../data/models/treatment_model.dart';
import '../data/treatment_data.dart';
import 'treatment_detail_screen.dart';

class TreatmentScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateToTab;

  const TreatmentScreen({super.key, this.onNavigateToTab});

  @override
  State<TreatmentScreen> createState() => _TreatmentScreenState();
}

class _TreatmentScreenState extends State<TreatmentScreen> {
  TreatmentCategory? _selectedCategory; // null = "All"
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TreatmentModel> get _filtered {
    // When a search query is active, search across ALL treatments regardless of category.
    if (_searchQuery.isNotEmpty) {
      return TreatmentData.search(_searchQuery);
    }
    // No query — filter by selected category (null = all).
    return TreatmentData.byCategory(_selectedCategory);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── GRADIENT HEADER WITH SEARCH ──────────────────────
            _GradientHeader(
              searchController: _searchController,
              onSearchChanged: (v) => setState(() => _searchQuery = v),
              onClearSearch: _clearSearch,
              onBack: () => Navigator.of(context).pop(),
            ),

            // ── CATEGORY FILTER CHIPS ─────────────────────────────
            const SizedBox(height: 14),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH),
                children: [
                  _CategoryChip(
                    label: 'All',
                    selected: _selectedCategory == null,
                    onTap: () =>
                        setState(() => _selectedCategory = null),
                  ),
                  const SizedBox(width: 8),
                  ...TreatmentCategory.values.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _CategoryChip(
                        label: cat.label,
                        selected: _selectedCategory == cat,
                        onTap: () =>
                            setState(() => _selectedCategory = cat),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── TREATMENT LIST ────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(query: _searchQuery)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH, 0,
                          AppSpacing.screenH, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final treatment = filtered[index];
                        return _TreatmentCard(
                          treatment: treatment,
                          index: index,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TreatmentDetailScreen(
                                  treatment: treatment,
                                  onFindClinic: widget.onNavigateToTab != null
                                      ? () {
                                          // Pop detail screen, then list screen
                                          Navigator.of(context).pop();
                                          Navigator.of(context).pop();
                                          // Switch to Clinics tab (index 3)
                                          widget.onNavigateToTab!(3);
                                        }
                                      : null,
                                ),
                              ),
                            );
                          },
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

// ─────────────────────────────────────────────────────────────────────────────
// Gradient header with integrated search
// ─────────────────────────────────────────────────────────────────────────────

class _GradientHeader extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onBack;

  const _GradientHeader({
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.verticalGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenH, 16, AppSpacing.screenH, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              Text(
                'Treatments',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              // Subtitle
              Text(
                'Learn what to expect before your visit',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 20),
              // Search field
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.navy,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search treatments...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.secondaryText,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.secondaryText,
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: onClearSearch,
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppColors.secondaryText,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category chip
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : Colors.white,
          border: selected ? null : Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Treatment card
// ─────────────────────────────────────────────────────────────────────────────

class _TreatmentCard extends StatelessWidget {
  final TreatmentModel treatment;
  final VoidCallback onTap;
  final int index;

  const _TreatmentCard({
    required this.treatment,
    required this.onTap,
    required this.index,
  });

  Color _getCategoryColor() {
    switch (treatment.category) {
      case TreatmentCategory.general:
        return AppColors.primary; // teal
      case TreatmentCategory.cosmetic:
        return AppColors.coral;
      case TreatmentCategory.orthodontics:
        return AppColors.mintGreen;
      case TreatmentCategory.surgical:
        return AppColors.g2; // default teal
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(treatment.id),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.g2.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: treatment.iconBackground,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: treatment.imagePath != null
                        ? Image.asset(
                            treatment.imagePath!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            treatment.icon,
                            size: 28,
                            color: treatment.iconColor,
                          ),
                  ),

                  const SizedBox(width: 14),

                  // Name + description + meta chips
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          treatment.name,
                          style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          treatment.shortDescription,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        // Meta chips row
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            // Category
                            _MetaChip(
                              label: treatment.category.label,
                              color: _getCategoryColor(),
                            ),
                            // Duration
                            _MetaChip(
                              icon: Icons.schedule_rounded,
                              label: treatment.duration,
                              color: AppColors.secondaryText,
                            ),
                            // Follow-up
                            if (treatment.requiresFollowUp)
                              _MetaChip(
                                icon: Icons.event_repeat_rounded,
                                label: 'Follow-up',
                                color: AppColors.secondaryText,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Arrow
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppColors.g2,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small meta chip (category, duration, follow-up)
// ─────────────────────────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const _MetaChip({
    required this.label,
    this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final String query;

  const _EmptyState({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.lightLavender,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 34,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              query.isNotEmpty
                  ? 'No results for "$query"'
                  : 'No treatments in this category',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try a different search term or category.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
