import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../../screening/data/api_screening_repository.dart';
import '../../screening/data/models/screening_session.dart';

enum AnalysisFailure {
  offline,
  timeout,
  service,

  /// The backend has no analysis service configured. Not an error the
  /// user can fix: the scan just finishes without analysis.
  unavailable,
}

class AnalysisException implements Exception {
  const AnalysisException(this.failure);
  final AnalysisFailure failure;

  @override
  String toString() => 'AnalysisException($failure)';
}

class ScreeningAnalysisResult {
  const ScreeningAnalysisResult({
    required this.summary,
    this.analysis,
    this.savedSession,
  });

  /// Plain-language summary returned by the analysis backend.
  final String summary;

  /// The full result: findings, recommendations and photos to retake.
  final ScreeningAnalysis? analysis;

  /// The session as the server saved it with this analysis. When set the
  /// app must not save the analysis again.
  final ScreeningSession? savedSession;
}

/// Contract for AI image analysis of a finished scan.
abstract class ScreeningAnalysisService {
  /// Analyzes the photos already uploaded for [sessionId]. Throws
  /// [AnalysisException]. [onProgress] hears how far the server has got.
  Future<ScreeningAnalysisResult> analyze(
    String sessionId, {
    ValueChanged<ScreeningAnalysisProgress>? onProgress,
  });
}

/// Server-side analysis: asks the API to analyze the uploaded photos,
/// then polls the session until the result is in.
class ApiScreeningAnalysisService implements ScreeningAnalysisService {
  ApiScreeningAnalysisService(
    this._api, {
    this.pollEvery = const Duration(seconds: 1),
  });

  final ApiClient _api;
  final Duration pollEvery;

  @override
  Future<ScreeningAnalysisResult> analyze(
    String sessionId, {
    ValueChanged<ScreeningAnalysisProgress>? onProgress,
  }) async {
    final path = '/api/screenings/${Uri.encodeComponent(sessionId)}';
    try {
      var session = await _request('POST', '$path/analyze');
      // The caller's timeout ends this loop if the server never finishes.
      while (session.analysis?.status == AnalysisStatus.pending) {
        if (session.analysis?.progress case final progress?) {
          onProgress?.call(progress);
        }
        await Future<void>.delayed(pollEvery);
        session = await _request('GET', path);
      }
      final analysis = session.analysis;
      if (analysis == null || analysis.status == AnalysisStatus.failed) {
        throw const AnalysisException(AnalysisFailure.service);
      }
      return ScreeningAnalysisResult(
        summary: analysis.summary,
        analysis: analysis,
        savedSession: session,
      );
    } on ApiException catch (e) {
      throw AnalysisException(e.code == 'analysis_unavailable'
          ? AnalysisFailure.unavailable
          : AnalysisFailure.service);
    } on SocketException {
      throw const AnalysisException(AnalysisFailure.offline);
    } on http.ClientException {
      throw const AnalysisException(AnalysisFailure.offline);
    } on TimeoutException {
      throw const AnalysisException(AnalysisFailure.timeout);
    }
  }

  Future<ScreeningSession> _request(String method, String path) async {
    final body = await _api.send(method, path);
    return screeningSessionFromApi(
        _api, body['session'] as Map<String, dynamic>);
  }
}

/// Server-side analysis whenever the app talks to the DENTRA API. Null in
/// demo mode (on-device history), where the scan finishes without an
/// "Analyzing" step.
final screeningAnalysisServiceProvider =
    Provider<ScreeningAnalysisService?>((ref) {
  final api = ref.watch(apiClientProvider);
  return api == null ? null : ApiScreeningAnalysisService(api);
});
