// ──────────────────────────────────────────────────────────────────
// TEMPORARY DEMO-ONLY MODEL
// ──────────────────────────────────────────────────────────────────
// This is a simplified ClinicModel used exclusively for MockData and
// the demo UI in lib/features/clinics/screens/.
//
// The real production model lives at:
//   lib/features/clinic_finder/data/models/clinic_model.dart
//
// This file will be REMOVED once the demo UI is connected to the real
// Riverpod providers (clinicListProvider, filteredClinicsProvider).
// ──────────────────────────────────────────────────────────────────

class ClinicModel {
  final int id;
  final String name;
  final String distance;
  final String services;
  final double rating;
  final double latitude;
  final double longitude;

  const ClinicModel({
    required this.id,
    required this.name,
    required this.distance,
    required this.services,
    required this.rating,
    required this.latitude,
    required this.longitude,
  });
}
