/// A finished scan session, as recorded in the user's screening history.
///
/// Only metadata is stored. The captured images themselves live in memory
/// for the current session and are not persisted.
class ScreeningSession {
  final String id;
  final DateTime completedAt;

  /// Region ids (see `scanRegions`) that were captured, in capture order.
  final List<String> capturedRegions;
  final int totalRegions;

  const ScreeningSession({
    required this.id,
    required this.completedAt,
    required this.capturedRegions,
    required this.totalRegions,
  });

  bool get isComplete => capturedRegions.length >= totalRegions;

  Map<String, dynamic> toJson() => {
        'id': id,
        'completedAt': completedAt.toIso8601String(),
        'capturedRegions': capturedRegions,
        'totalRegions': totalRegions,
      };

  factory ScreeningSession.fromJson(Map<String, dynamic> json) {
    return ScreeningSession(
      id: json['id'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      capturedRegions:
          (json['capturedRegions'] as List<dynamic>).cast<String>(),
      totalRegions: json['totalRegions'] as int,
    );
  }
}
