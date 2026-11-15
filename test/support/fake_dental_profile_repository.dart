import 'dart:async';

import 'package:dentra_mobile/features/dental_profile/data/dental_profile_repository.dart';
import 'package:dentra_mobile/features/dental_profile/data/models/dental_answers.dart';

/// In-memory stand-in for the dental profile API. A profile exists only
/// after a submit succeeds, like on the server.
class FakeDentalProfileRepository implements DentalProfileRepository {
  FakeDentalProfileRepository({this.profile});

  /// Starts with a saved profile: onboarding already completed.
  factory FakeDentalProfileRepository.completed() =>
      FakeDentalProfileRepository(profile: savedProfile(sampleAnswers));

  DentalProfile? profile;

  /// Thrown by the next status check, then cleared.
  DentalProfileException? statusError;

  /// Thrown by every submit/update while set.
  DentalProfileException? saveError;

  /// When set, submits wait for it, to inspect the pending state.
  Completer<void>? holdSave;

  /// When set, status checks wait for it, like a slow server.
  Completer<void>? holdStatus;

  final List<DentalAnswers> submitted = [];
  final List<DentalAnswers> updated = [];
  int statusChecks = 0;

  @override
  Future<bool> fetchOnboardingCompleted(String userId) async {
    statusChecks++;
    await holdStatus?.future;
    final error = statusError;
    statusError = null;
    if (error != null) throw error;
    return profile != null;
  }

  @override
  Future<DentalProfile?> fetchProfile(String userId) async => profile;

  @override
  Future<DentalProfile> submitProfile(
      String userId, DentalAnswers answers) async {
    submitted.add(answers);
    return _save(answers);
  }

  @override
  Future<DentalProfile> updateProfile(
      String userId, DentalAnswers answers) async {
    updated.add(answers);
    return _save(answers);
  }

  Future<DentalProfile> _save(DentalAnswers answers) async {
    await holdSave?.future;
    final error = saveError;
    if (error != null) throw error;
    return profile = DentalProfile(
      answers: answers,
      version: (profile?.version ?? 0) + 1,
      completedAt: profile?.completedAt ?? DateTime(2026, 10, 21),
    );
  }
}

const offline = DentalProfileException(
  "We couldn't reach DENTRA. Check your connection and try again.",
  offline: true,
);

/// A complete, valid set of answers.
const sampleAnswers = DentalAnswers(
  lastCheckup: LastCheckup.overAYear,
  previousProblems: {PreviousProblem.toothDecay},
  currentConcerns: {CurrentConcern.toothPain},
  concernDuration: ConcernDuration.fewWeeks,
  discomfortLevel: DiscomfortLevel.moderate,
  screeningGoals: {ScreeningGoal.decay},
  difficultAreas: {DifficultArea.backTeeth},
);

DentalProfile savedProfile(DentalAnswers answers) => DentalProfile(
      answers: answers,
      version: 1,
      completedAt: DateTime(2026, 10, 1),
    );
