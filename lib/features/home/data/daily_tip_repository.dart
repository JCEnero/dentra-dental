import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/dentra_dates.dart';

/// The day's oral-care tip on Home. Written once a day on the server,
/// the same for every user.
class DailyTip {
  const DailyTip({
    required this.date,
    required this.headline,
    required this.body,
    required this.aiGenerated,
  });

  /// 'YYYY-MM-DD', the user's local date.
  final String date;
  final String headline;
  final String body;

  /// Written by the AI model for this day (false for a fallback tip).
  final bool aiGenerated;

  factory DailyTip.fromJson(Map<String, dynamic> json) => DailyTip(
        date: json['date'] as String,
        headline: json['headline'] as String,
        body: json['body'] as String,
        aiGenerated: json['source'] == 'ai_generated',
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'headline': headline,
        'body': body,
        'source': aiGenerated ? 'ai_generated' : 'fallback',
      };
}

/// Gets the tip for a day: from this device's copy when it already has
/// that day's tip, else from the API (`/api/tips/today`), else offline.
class DailyTipRepository {
  DailyTipRepository(this._api);

  /// Null without a backend (demo mode, tests): offline tips only.
  final ApiClient? _api;

  static const _cacheKey = 'daily_tip.v1';

  Future<DailyTip> tipFor(DateTime day) async {
    final date = DentraDates.isoDate(day);
    final prefs = await SharedPreferences.getInstance();
    final cached = _read(prefs);
    // A fallback tip is retried, so the day still gets its real one.
    if (cached != null && cached.date == date && cached.aiGenerated)
      return cached;

    final api = _api;
    if (api != null) {
      try {
        final body =
            await api.send('GET', '/api/tips/today', query: {'date': date});
        final tip = DailyTip.fromJson(body['tip'] as Map<String, dynamic>);
        await prefs.setString(_cacheKey, jsonEncode(tip.toJson()));
        return tip;
      } catch (_) {
        // Offline or server trouble: fall through.
      }
    }
    if (cached != null && cached.date == date) return cached;
    return offlineTip(day);
  }

  DailyTip? _read(SharedPreferences prefs) {
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return null;
    try {
      return DailyTip.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// A small rotation for when the server can't be reached, so the card
  /// still changes day to day.
  static DailyTip offlineTip(DateTime day) {
    final index = DateTime.utc(day.year, day.month, day.day)
            .difference(DateTime.utc(2026))
            .inDays %
        _offline.length;
    final (headline, body) = _offline[index];
    return DailyTip(
      date: DentraDates.isoDate(day),
      headline: headline,
      body: body,
      aiGenerated: false,
    );
  }

  static const _offline = [
    (
      "Don't forget the back teeth.",
      'Back teeth are easy to miss while brushing. Give them a little extra '
          'attention in your routine.',
    ),
    (
      'Brush for about two minutes.',
      'Gentle, steady strokes across every tooth surface clean better than '
          'brushing hard and fast.',
    ),
    (
      'Your tongue matters too.',
      'Gently cleaning your tongue helps keep your whole mouth fresher.',
    ),
  ];
}
