import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AnalysisFailure { offline, timeout, service }

class AnalysisException implements Exception {
  const AnalysisException(this.failure);
  final AnalysisFailure failure;

  @override
  String toString() => 'AnalysisException($failure)';
}

class ScreeningAnalysisResult {
  const ScreeningAnalysisResult({required this.summary});

  /// Plain-language summary returned by the analysis backend.
  final String summary;
}

/// Contract for AI image analysis of a finished scan.
abstract class ScreeningAnalysisService {
  /// [images] maps region id to image bytes. Throws [AnalysisException].
  Future<ScreeningAnalysisResult> analyze(Map<String, Uint8List> images);
}

/// No image-analysis backend exists in the project yet (`GeminiService`
/// is text chat only), so this is null and the scan finishes without an
/// "Analyzing" step. Override it with a real implementation to enable one.
final screeningAnalysisServiceProvider =
    Provider<ScreeningAnalysisService?>((ref) => null);
