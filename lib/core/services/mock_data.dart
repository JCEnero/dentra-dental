/// Centralised mock data — mirrors the frontend App.tsx datasets.
abstract class MockData {
  static const List<Map<String, String>> dailyTips = [
    {
      'headline': "Don't forget the back teeth.",
      'body':
          'Posterior areas can be difficult to observe during everyday brushing. Give them extra attention during your routine.',
    },
    {
      'headline': 'Brush for about two minutes.',
      'body':
          'Use gentle, consistent movements across all tooth surfaces for thorough cleaning.',
    },
    {
      'headline': 'Your tongue matters too.',
      'body':
          'Gently cleaning your tongue can help maintain overall oral hygiene.',
    },
  ];

  // Scan regions now live in `features/scan/data/scan_regions.dart`.
}
