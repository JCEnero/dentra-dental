// lib/features/treatment/screens/treatment_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../data/models/treatment_model.dart';
import '../data/treatment_data.dart';
import 'treatment_detail_screen.dart';

class TreatmentScreen extends StatefulWidget {
  const TreatmentScreen({super.key});

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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ────────────────────────────────────────────
            _TreatmentHeader(onBack: () => Navigator.of(context).pop()),

            // ── SEARCH BAR ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenH, 16, AppSpacing.screenH, 0),
              child: _SearchBar(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                onClear: _clearSearch,
              ),
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
              child: _filtered.isEmpty
                  ? _EmptyState(query: _searchQuery)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.screenH, 0,
                          AppSpacing.screenH, 24),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final treatment = _filtered[index];
                        return _TreatmentCard(
                          treatment: treatment,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TreatmentDetailScreen(
                                  treatment: treatment,
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
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _TreatmentHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _TreatmentHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, 16, AppSpacing.screenH, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.lightLavender,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: AppColors.navy,
              ),
            ),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Treatments',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          // Placeholder to keep title centred
          const SizedBox(width: 38),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.lightLavender,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
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
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.secondaryText,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 13),
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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.g2 : AppColors.lightLavender,
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

  const _TreatmentCard({required this.treatment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            // Icon container — custom image or Flutter icon fallback
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: treatment.iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: treatment.iconPath != null
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: Image.asset(
                        treatment.iconPath!,
                        fit: BoxFit.contain,
                      ),
                    )
                  : treatment.imagePath != null
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

            // Name + description
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
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.lightLavender,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      treatment.category.label,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.g2,
                      ),
                    ),
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
