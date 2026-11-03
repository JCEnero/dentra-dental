import '../../dental_profile/data/models/dental_answers.dart';
import '../../dental_records/data/models/dental_record.dart';
import '../../screening/data/models/scan_check_in.dart';
import '../../screening/data/models/screening_session.dart';
import 'patient_context.dart';

/// Which questions are worth asking before this scan, from what's already
/// known. A first scan right after onboarding asks little, and someone scanning
/// again today isn't asked again what they said this morning.
class CheckInPlan {
  const CheckInPlan({
    this.asksSymptoms = false,
    this.asksTreatment = false,
    this.asksCheckup = false,
    this.asksCleaning = false,
    this.asksFocus = false,
    this.lastScanAt,
    this.prefill = const ScanCheckIn(),
  });

  /// Answers given recently enough to start from.
  final ScanCheckIn prefill;

  final bool asksSymptoms;
  final bool asksTreatment;
  final bool asksCheckup;
  final bool asksCleaning;
  final bool asksFocus;

  /// The scan before this one, so questions can say "since then".
  final DateTime? lastScanAt;

  bool get isEmpty =>
      !asksSymptoms &&
      !asksTreatment &&
      !asksCheckup &&
      !asksCleaning &&
      !asksFocus;

  /// How long an answer about today still holds.
  static const Duration _sameDay = Duration(hours: 24);

  /// How long an answer about visits still holds.
  static const Duration _visitAnswerLifetime = Duration(days: 180);

  /// A first scan asks about treatment over this long.
  static const Duration _recentTreatment = Duration(days: 90);

  /// A question skipped this recently isn't asked again.
  static const Duration _dontNag = Duration(days: 30);

  /// [sessions] and [records] newest first.
  factory CheckInPlan.of({
    required DateTime now,
    DentalProfile? profile,
    List<ScreeningSession> sessions = const [],
    List<DentalRecord> records = const [],
  }) {
    bool within(DateTime? at, Duration span) =>
        at != null && now.difference(at) < span;

    final answers = profile?.answers;
    final answeredAt = profile?.updatedAt ?? profile?.completedAt;
    final lastScan = sessions.firstOrNull;
    final lastCheckIn = sessions.where((s) => s.checkIn != null).firstOrNull;
    final checkInAt = lastCheckIn?.completedAt;
    final clinic =
        records.where((r) => r.source == RecordSource.clinicRecord).toList();

    // ── Symptoms ──
    var asksSymptoms = true;
    var prefill = const ScanCheckIn();
    final latest = lastCheckIn?.checkIn;
    if (latest != null &&
        latest.symptoms.isNotEmpty &&
        within(checkInAt, _sameDay)) {
      if (latest.hasSymptom) {
        prefill = latest.normalized();
      } else {
        asksSymptoms = false;
      }
    } else if (answers != null && within(answeredAt, _sameDay)) {
      if (answers.currentConcerns.any((c) => c.isActive)) {
        prefill = ScanCheckIn(
          symptoms: answers.currentConcerns.where(checkInSymptoms.contains).toSet(),
          started: symptomStarts.contains(answers.concernDuration)
              ? answers.concernDuration
              : null,
          pattern: answers.concernDuration == ConcernDuration.comesAndGoes
              ? SymptomPattern.occasional
              : null,
          severity: answers.discomfortLevel,
        );
      } else {
        asksSymptoms = false;
      }
    }

    // ── Treatment ──
    final bool asksTreatment;
    if (lastScan != null) {
      final since = lastScan.completedAt;
      final visitSince = clinic.any((r) => !r.recordDate.isBefore(since));
      asksTreatment = !within(since, _sameDay) && !visitSince;
    } else {
      final noRecentVisit = answers != null &&
          within(answeredAt, _recentTreatment) &&
          (answers.lastCheckup == LastCheckup.never ||
              answers.lastCheckup == LastCheckup.overAYear);
      final visitOnRecord =
          clinic.any((r) => within(r.recordDate, _recentTreatment));
      asksTreatment = !noRecentVisit && !visitOnRecord;
    }

    // ── Check-up and cleaning ──
    final recentlyAsked = within(checkInAt, _dontNag);
    final visitOnRecord =
        clinic.any((r) => within(r.recordDate, _visitAnswerLifetime));
    final checkupKnown = visitOnRecord ||
        (answers?.lastCheckup != null &&
            within(answeredAt, _visitAnswerLifetime)) ||
        sessions.any((s) =>
            s.checkIn?.lastCheckup != null &&
            within(s.completedAt, _visitAnswerLifetime));
    final cleaningKnown = clinic.any((r) =>
            within(r.recordDate, _visitAnswerLifetime) &&
            procedureKindOf(r.procedure) == ProcedureKind.cleaning) ||
        (answers?.lastCleaning != null &&
            within(answeredAt, _visitAnswerLifetime)) ||
        sessions.any((s) =>
            s.checkIn?.lastCleaning != null &&
            within(s.completedAt, _visitAnswerLifetime));

    // ── A tooth or area to note ──
    final asksFocus = lastScan != null ||
        (answers?.screeningGoals.contains(ScreeningGoal.specificConcern) ??
            false);

    return CheckInPlan(
      asksSymptoms: asksSymptoms,
      asksTreatment: asksTreatment,
      asksCheckup: !checkupKnown && !recentlyAsked,
      asksCleaning: !cleaningKnown && !recentlyAsked,
      asksFocus: asksFocus,
      lastScanAt: lastScan?.completedAt,
      prefill: prefill,
    );
  }
}
