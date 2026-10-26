import 'dart:convert';

import 'package:dentra_mobile/core/network/api_client.dart';
import 'package:dentra_mobile/features/scan/services/screening_analysis_service.dart';
import 'package:dentra_mobile/features/screening/data/models/screening_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> session(Map<String, dynamic>? analysis) => {
      'id': 's1',
      'completed_at': '2026-10-22T08:00:00.000Z',
      'captured_regions': ['ul'],
      'total_regions': 5,
      'captures': [
        {
          'region_id': 'ul',
          'source': 'device',
          'captured_at': '2026-10-22T08:00:00.000Z',
          'image_url': '/files/a.png',
          'nir_image_url': '/files/a-nir.png',
        },
      ],
      'analysis': analysis,
    };

Map<String, dynamic> analysis(String status) => {
      'status': status,
      'summary': status == 'complete' ? 'Possible cavity: see a dentist.' : '',
      'analyzed_at': '2026-10-22T08:00:05.000Z',
      'model': 'det-test+rules-0.1',
      'dentition_type': 'mixed',
      'findings': [
        if (status == 'complete')
          {
            'label': 'Possible cavity',
            'region_id': 'ul',
            'tooth': '54',
            'confidence': 0.8,
            'category': 'dentin_caries_cavity',
            'modality': 'nir',
          },
      ],
      'recommendations': [
        if (status == 'complete')
          {
            'code': 'possible_filling',
            'title': 'Possible cavity: see a dentist',
            'detail': 'Book a visit soon.',
            'urgency': 'soon',
            'region_ids': ['ul'],
          },
      ],
      'quality_issues': [],
    };

/// An API that answers POST /analyze with [first], then each GET with the
/// next of [then].
ApiScreeningAnalysisService serviceWith(
  http.Response first, [
  List<http.Response> then = const [],
]) {
  final requests = <String>[];
  var polls = 0;
  final client = MockClient((req) async {
    requests.add('${req.method} ${req.url.path}');
    if (req.method == 'POST') return first;
    return then[polls++];
  });
  return ApiScreeningAnalysisService(
    ApiClient(
      baseUrl: 'https://api.test',
      accessToken: () async => 'token',
      client: client,
    ),
    pollEvery: Duration.zero,
  );
}

http.Response json(int status, Object body) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  test('starts analysis, polls until done, and returns the saved session',
      () async {
    final service = serviceWith(json(202, {'session': session(analysis('pending'))}), [
      json(200, {'session': session(analysis('pending'))}),
      json(200, {'session': session(analysis('complete'))}),
    ]);
    final result = await service.analyze('s1');

    expect(result.summary, 'Possible cavity: see a dentist.');
    final a = result.analysis!;
    expect(a.status, AnalysisStatus.complete);
    expect(a.dentitionType, 'mixed');
    expect(a.findings.single.modality, 'nir');
    expect(a.recommendations.single.code, 'possible_filling');
    // Relative image URLs are resolved against the API.
    expect(result.savedSession!.captures.single.nirImageUrl,
        'https://api.test/files/a-nir.png');
  });

  test('a failed server analysis is a service failure', () async {
    final service = serviceWith(json(202, {'session': session(analysis('pending'))}), [
      json(200, {'session': session(analysis('failed'))}),
    ]);
    await expectLater(
      service.analyze('s1'),
      throwsA(isA<AnalysisException>()
          .having((e) => e.failure, 'failure', AnalysisFailure.service)),
    );
  });

  test('a backend without analysis reports unavailable', () async {
    final service = serviceWith(json(503, {
      'error': {
        'code': 'analysis_unavailable',
        'message': "Photo analysis isn't available right now.",
      },
    }));
    await expectLater(
      service.analyze('s1'),
      throwsA(isA<AnalysisException>()
          .having((e) => e.failure, 'failure', AnalysisFailure.unavailable)),
    );
  });

  test('a network error is offline', () async {
    final service = ApiScreeningAnalysisService(ApiClient(
      baseUrl: 'https://api.test',
      accessToken: () async => 'token',
      client: MockClient((_) => throw http.ClientException('no route')),
    ));
    await expectLater(
      service.analyze('s1'),
      throwsA(isA<AnalysisException>()
          .having((e) => e.failure, 'failure', AnalysisFailure.offline)),
    );
  });

  test('older records without the new fields still load', () {
    final a = ScreeningAnalysis.fromJson({
      'summary': 'Old summary',
      'analyzed_at': '2026-01-01T00:00:00.000Z',
      'findings': [
        {'label': 'Plaque'},
      ],
    });
    expect(a.status, AnalysisStatus.complete);
    expect(a.recommendations, isEmpty);
    expect(a.findings.single.category, isNull);
  });
}
