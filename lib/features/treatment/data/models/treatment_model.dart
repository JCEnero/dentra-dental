// lib/features/treatment/data/models/treatment_model.dart

import 'package:flutter/material.dart';

/// Categories for dental treatments, matching the filter chips in the UI.
enum TreatmentCategory {
  general,
  cosmetic,
  orthodontics,
  surgical,
}

extension TreatmentCategoryLabel on TreatmentCategory {
  String get label {
    switch (this) {
      case TreatmentCategory.general:
        return 'General';
      case TreatmentCategory.cosmetic:
        return 'Cosmetic';
      case TreatmentCategory.orthodontics:
        return 'Orthodontics';
      case TreatmentCategory.surgical:
        return 'Surgical';
    }
  }
}

/// Represents a single step in the treatment procedure.
class TreatmentStep {
  final String title;
  final String description;

  const TreatmentStep({
    required this.title,
    required this.description,
  });
}

/// Full data model for a dental treatment.
class TreatmentModel {
  final String id;
  final String name;
  final String shortDescription;
  final String longDescription;
  final TreatmentCategory category;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  /// Optional custom image asset path (e.g. 'assets/images/treatments/braces.jpg').
  /// When provided, the card renders this image instead of [icon].
  final String? imagePath;

  final List<TreatmentStep> steps;
  final String duration;
  final bool requiresFollowUp;

  const TreatmentModel({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.longDescription,
    required this.category,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    this.imagePath,
    required this.steps,
    required this.duration,
    this.requiresFollowUp = false,
  });
}
