import 'dart:convert';

import 'package:dentra_mobile/core/network/api_client.dart';
import 'package:dentra_mobile/features/home/data/daily_tip_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// An API that answers /api/tips/today, counting calls.
(ApiClient, List<String>) _api({bool fail = false, String source = 'ai_generated'}) {
  final calls = <String>[];
  final client = MockClient((req) async {
    final date = req.url.queryParameters['date']!;
    calls.add(date);
    if (fail) return http.Response('oops', 503);
    return http.Response(
      jsonEncode({
        'tip': {
          'date': date,
          'headline': 'Tip for $date.',
          'body': 'Body for $date.',
          'source': source,
        },
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  return (
    ApiClient(baseUrl: 'http://api.test', accessToken: () async => 't', client: client),
    calls,
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test("fetches once per day, then uses the device's copy", () async {
    final (api, calls) = _api();
    final repo = DailyTipRepository(api);

    final first = await repo.tipFor(DateTime(2026, 10, 21));
    final again = await repo.tipFor(DateTime(2026, 10, 21));
    expect(first.headline, 'Tip for 2026-10-21.');
    expect(again.headline, first.headline);
    expect(calls, ['2026-10-21']);

    final next = await repo.tipFor(DateTime(2026, 10, 22));
    expect(next.headline, 'Tip for 2026-10-22.');
    expect(calls, ['2026-10-21', '2026-10-22']);
  });

  test('a fallback tip is retried later for the real one', () async {
    final (api, calls) = _api(source: 'fallback');
    final repo = DailyTipRepository(api);
    await repo.tipFor(DateTime(2026, 10, 21));
    await repo.tipFor(DateTime(2026, 10, 21));
    expect(calls, hasLength(2));
  });

  test('offline still changes from day to day', () async {
    final (api, _) = _api(fail: true);
    final repo = DailyTipRepository(api);
    final a = await repo.tipFor(DateTime(2026, 10, 21));
    final b = await repo.tipFor(DateTime(2026, 10, 22));
    expect(a.aiGenerated, isFalse);
    expect(a.headline, isNot(b.headline));
    expect(DailyTipRepository(null).tipFor(DateTime(2026, 10, 21)), completes);
  });
}
