import '../models/screening_model.dart';
import '../models/clinic_model.dart';

/// Centralised mock data — mirrors the frontend App.tsx datasets.
abstract class MockData {
  static const List<ScreeningModel> screenings = [
    ScreeningModel(
      id: 1,
      date: 'Sep 7',
      fullDate: 'September 7, 2026',
      images: 4,
      teeth: 18,
      region: 'Upper Right',
      weekday: 'Mon',
    ),
    ScreeningModel(
      id: 2,
      date: 'Aug 28',
      fullDate: 'August 28, 2026',
      images: 3,
      teeth: 16,
      region: 'Lower Left',
      weekday: 'Fri',
    ),
    ScreeningModel(
      id: 3,
      date: 'Aug 12',
      fullDate: 'August 12, 2026',
      images: 5,
      teeth: 20,
      region: 'Posterior',
      weekday: 'Wed',
    ),
    ScreeningModel(
      id: 4,
      date: 'Jul 30',
      fullDate: 'July 30, 2026',
      images: 2,
      teeth: 14,
      region: 'Upper Left',
      weekday: 'Thu',
    ),
  ];

  static const List<ClinicModel> clinics = [
    ClinicModel(
      id: 1,
      name: 'Sunrise Dental Clinic',
      distance: '0.8 km',
      services: 'General Dentistry · Restorative',
      rating: 4.8,
      latitude: 14.5547,   // Makati CBD (base point)
      longitude: 121.0244,
      phoneNumber: '+63 2 8123 4567',
    ),
    ClinicModel(
      id: 2,
      name: 'Pacific Oral Care',
      distance: '1.4 km',
      services: 'Orthodontics · Cosmetic',
      rating: 4.6,
      latitude: 14.5673,   // ~1.4 km northwest
      longitude: 121.0155,
      phoneNumber: '+63 917 234 5678',
    ),
    ClinicModel(
      id: 3,
      name: 'Metro Dental Center',
      distance: '2.1 km',
      services: 'Implants · Periodontics',
      rating: 4.7,
      latitude: 14.5735,   // ~2.1 km north-northeast
      longitude: 121.0380,
      phoneNumber: '+63 2 8765 4321',
    ),
  ];

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

  static const List<Map<String, String>> scanRegions = [
    {'id': 'ul', 'label': 'Upper Left',  'desc': 'Left side of the upper dental arch'},
    {'id': 'ur', 'label': 'Upper Right', 'desc': 'Right side of the upper dental arch'},
    {'id': 'll', 'label': 'Lower Left',  'desc': 'Left side of the lower dental arch'},
    {'id': 'lr', 'label': 'Lower Right', 'desc': 'Right side of the lower dental arch'},
    {'id': 'po', 'label': 'Posterior',   'desc': 'Back teeth — keep the device steady'},
  ];
}
