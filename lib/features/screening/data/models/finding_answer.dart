import '../../../dental_profile/data/models/dental_answers.dart';

/// "Have you experienced pain or sensitivity in this tooth before?", asked about
/// one tooth the check marked. Ids match the backend's `TOOTH_PAIN` and the
/// `screening_finding_answers` CHECK constraint; change all three together.
enum ToothPain implements AnswerOption {
  yes('yes', 'Yes, I have experienced pain.'),
  sometimes('sometimes', 'Sometimes, especially when eating or drinking.'),
  no('no', 'No, I haven\'t experienced any pain.'),
  notSure('not_sure', 'I\'m not sure.');

  const ToothPain(this.id, this.label);

  @override
  final String id;

  /// The answer as the user picks it.
  @override
  final String label;

  @override
  bool get exclusive => false;

  /// The answer in a few words, for the PDF and a note to a dentist.
  String get short => switch (this) {
        yes => 'Has had pain',
        sometimes => 'Sometimes, when eating or drinking',
        no => 'No pain',
        notSure => 'Not sure',
      };

  /// Pain or sensitivity, all the time or now and then.
  bool get hurts => this == yes || this == sometimes;

  static ToothPain? fromId(Object? id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// What the user said about one finding. Their own account, never a finding: it
/// is shown apart from what the check saw, changes only the advice, and is never
/// sent to the image model. Goes away with its finding when a scan is read again.
class FindingAnswer {
  const FindingAnswer({
    required this.findingId,
    required this.pain,
    this.answeredAt,
  });

  /// The finding it's about (`ScreeningFinding.id`).
  final String findingId;
  final ToothPain pain;
  final DateTime? answeredAt;

  Map<String, dynamic> toJson() => {
        'source': 'user_reported',
        'finding_id': findingId,
        'pain': pain.id,
        'answered_at': answeredAt?.toUtc().toIso8601String(),
      };

  /// Null for an answer this version of the app doesn't know.
  static FindingAnswer? fromJson(Map<String, dynamic> json) {
    final pain = ToothPain.fromId(json['pain']);
    final id = json['finding_id'];
    if (pain == null || id is! String) return null;
    return FindingAnswer(
      findingId: id,
      pain: pain,
      answeredAt: switch (json['answered_at']) {
        final String at => DateTime.tryParse(at)?.toLocal(),
        _ => null,
      },
    );
  }
}
