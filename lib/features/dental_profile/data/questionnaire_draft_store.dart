import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/dental_answers.dart';

/// Unsubmitted onboarding answers and the step the user was on, so an
/// unfinished questionnaire resumes where it was left (after closing the
/// app or signing out and back in). Only a convenience: the server's
/// profile is the record, and a draft is deleted once it is saved.
class QuestionnaireDraft {
  const QuestionnaireDraft({required this.answers, required this.step});

  final DentalAnswers answers;
  final int step;

  Map<String, dynamic> toJson() =>
      {'answers': answers.toDraftJson(), 'step': step};

  factory QuestionnaireDraft.fromJson(Map<String, dynamic> json) =>
      QuestionnaireDraft(
        answers:
            DentalAnswers.fromJson(json['answers'] as Map<String, dynamic>),
        step: json['step'] as int? ?? 0,
      );
}

/// Where drafts are kept, per user.
abstract class QuestionnaireDraftStore {
  Future<QuestionnaireDraft?> read(String userId);
  Future<void> write(String userId, QuestionnaireDraft draft);
  Future<void> clear(String userId);
}

/// Keychain / Keystore backed [QuestionnaireDraftStore]: drafts hold
/// health answers, so they never go to plain-text SharedPreferences.
///
/// Storage failures never block the questionnaire: an unreadable draft
/// starts fresh, and a failed write only loses the resume point. Calls
/// are capped by [_timeout], since a keychain that never answers (e.g.
/// no keyring on a desktop) must not leave the user waiting.
class SecureQuestionnaireDraftStore implements QuestionnaireDraftStore {
  SecureQuestionnaireDraftStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _timeout = Duration(seconds: 3);

  static String _key(String userId) => 'dental_profile.draft.v1.$userId';

  @override
  Future<QuestionnaireDraft?> read(String userId) async {
    try {
      final raw = await _storage.read(key: _key(userId)).timeout(_timeout);
      if (raw == null) return null;
      return QuestionnaireDraft.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String userId, QuestionnaireDraft draft) async {
    try {
      await _storage
          .write(key: _key(userId), value: jsonEncode(draft))
          .timeout(_timeout);
    } catch (_) {}
  }

  @override
  Future<void> clear(String userId) async {
    try {
      await _storage.delete(key: _key(userId)).timeout(_timeout);
    } catch (_) {}
  }
}

/// In-memory [QuestionnaireDraftStore] for tests.
class MemoryQuestionnaireDraftStore implements QuestionnaireDraftStore {
  final Map<String, QuestionnaireDraft> drafts = {};

  @override
  Future<QuestionnaireDraft?> read(String userId) async => drafts[userId];

  @override
  Future<void> write(String userId, QuestionnaireDraft draft) async =>
      drafts[userId] = draft;

  @override
  Future<void> clear(String userId) async => drafts.remove(userId);
}

/// Remembers, per user, that the server confirmed onboarding was
/// completed. Only consulted when the server can't be reached, so a
/// returning user isn't sent back through the questionnaire while
/// offline. Never written before the server confirms, and never sent
/// anywhere: the API checks its own records.
abstract final class OnboardingCompletionCache {
  static String _key(String userId) =>
      'dental_profile.onboarding_completed.v1.$userId';

  static Future<bool> read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key(userId)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> write(String userId, bool completed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(userId), completed);
    } catch (_) {
      // Best-effort: only affects the offline fallback.
    }
  }
}
