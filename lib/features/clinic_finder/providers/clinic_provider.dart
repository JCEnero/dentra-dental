// mobile/lib/features/clinic_finder/providers/clinic_provider.dart

import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../../core/constants/api_keys.dart';
import '../data/models/clinic_model.dart';

/// Simple immutable coordinate pair for the user's current position.
/// Defaults to a placeholder location until the real GPS value is wired
/// in via Geolocator elsewhere in the feature.
typedef UserLocation = ({double latitude, double longitude});

const UserLocation _defaultUserLocation = (
  latitude: 14.5995, // Placeholder: Manila City Hall
  longitude: 120.9842,
);

/// Holds the user's current location. Read by [filteredClinicsProvider]
/// to compute distance-based filtering. Update this from the location
/// detection logic (Geolocator) once that piece is wired in.
class UserLocationNotifier extends Notifier<UserLocation> {
  @override
  UserLocation build() => _defaultUserLocation;

  void setLocation({required double latitude, required double longitude}) {
    state = (latitude: latitude, longitude: longitude);
  }
}

final userLocationProvider =
    NotifierProvider<UserLocationNotifier, UserLocation>(
  UserLocationNotifier.new,
);

/// Active filter selections for the Clinic Finder list/map views.
class ClinicFilterState {
  final double radiusKm;
  final double? maxPrice;
  final double minRating;
  final bool openNowOnly;
  final String searchQuery; // <-- ADDED BY CLAUDE

  const ClinicFilterState({
    this.radiusKm = 5.0,
    this.maxPrice,
    this.minRating = 0.0,
    this.openNowOnly = false,
    this.searchQuery = '', // <-- ADDED BY CLAUDE
  });

  ClinicFilterState copyWith({
    double? radiusKm,
    double? maxPrice,
    bool clearMaxPrice = false,
    double? minRating,
    bool? openNowOnly,
    String? searchQuery, // <-- ADDED BY CLAUDE
  }) {
    return ClinicFilterState(
      radiusKm: radiusKm ?? this.radiusKm,
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      minRating: minRating ?? this.minRating,
      openNowOnly: openNowOnly ?? this.openNowOnly,
      searchQuery: searchQuery ?? this.searchQuery, // <-- ADDED BY CLAUDE
    );
  }
}

/// Manages the active [ClinicFilterState] for the filter sheet UI.
class ClinicFilterNotifier extends Notifier<ClinicFilterState> {
  @override
  ClinicFilterState build() => const ClinicFilterState();

  void setRadiusKm(double radiusKm) {
    state = state.copyWith(radiusKm: radiusKm);
  }

  void setMaxPrice(double? maxPrice) {
    state = state.copyWith(
      maxPrice: maxPrice,
      clearMaxPrice: maxPrice == null,
    );
  }

  void setMinRating(double minRating) {
    state = state.copyWith(minRating: minRating);
  }

  void setOpenNowOnly(bool openNowOnly) {
    state = state.copyWith(openNowOnly: openNowOnly);
  }

  // <-- ADDED BY CLAUDE
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void reset() {
    state = const ClinicFilterState();
  }
}

final clinicFilterProvider =
    NotifierProvider<ClinicFilterNotifier, ClinicFilterState>(
  ClinicFilterNotifier.new,
);

/// Mock clinic dataset used until `clinic_repository.dart` is wired up
/// to a real data source (API/Firestore). Coordinates are placed around
/// Metro Manila so radius filtering has realistic variance.
final List<ClinicModel> _mockClinics = [
  ClinicModel(
    id: 'clinic_001',
    name: 'BrightSmile Dental Clinic',
    address: '123 Rizal Ave, Manila',
    latitude: 14.5995,
    longitude: 120.9842,
    rating: 4.7,
    reviewCount: 128,
    services: const [
      ClinicService(name: 'Cleaning', price: 800),
      ClinicService(name: 'Filling', price: 1500),
      ClinicService(name: 'Extraction', price: 2000),
    ],
    operatingHours: const [
      OperatingHours(weekday: 1, openTime: '09:00', closeTime: '18:00'),
      OperatingHours(weekday: 2, openTime: '09:00', closeTime: '18:00'),
      OperatingHours(weekday: 3, openTime: '09:00', closeTime: '18:00'),
      OperatingHours(weekday: 4, openTime: '09:00', closeTime: '18:00'),
      OperatingHours(weekday: 5, openTime: '09:00', closeTime: '18:00'),
      OperatingHours(weekday: 6, openTime: '09:00', closeTime: '14:00'),
      OperatingHours(
        weekday: 7,
        openTime: '00:00',
        closeTime: '00:00',
        isClosed: true,
      ),
    ],
    phoneNumber: '+639171234567',
  ),
  ClinicModel(
    id: 'clinic_002',
    name: 'Metro Dental Care',
    address: '45 Taft Ave, Manila',
    latitude: 14.5763,
    longitude: 120.9822,
    rating: 4.3,
    reviewCount: 76,
    services: const [
      ClinicService(name: 'Cleaning', price: 600),
      ClinicService(name: 'Filling', price: 1200),
      ClinicService(name: 'Extraction', price: 1800),
    ],
    operatingHours: const [
      OperatingHours(weekday: 1, openTime: '08:00', closeTime: '17:00'),
      OperatingHours(weekday: 2, openTime: '08:00', closeTime: '17:00'),
      OperatingHours(weekday: 3, openTime: '08:00', closeTime: '17:00'),
      OperatingHours(weekday: 4, openTime: '08:00', closeTime: '17:00'),
      OperatingHours(weekday: 5, openTime: '08:00', closeTime: '17:00'),
      OperatingHours(
        weekday: 6,
        openTime: '00:00',
        closeTime: '00:00',
        isClosed: true,
      ),
      OperatingHours(
        weekday: 7,
        openTime: '00:00',
        closeTime: '00:00',
        isClosed: true,
      ),
    ],
    phoneNumber: '+639181234567',
  ),
  ClinicModel(
    id: 'clinic_003',
    name: 'Quezon City Family Dental',
    address: '88 Commonwealth Ave, Quezon City',
    latitude: 14.6760,
    longitude: 121.0437,
    rating: 4.9,
    reviewCount: 214,
    services: const [
      ClinicService(name: 'Cleaning', price: 1000),
      ClinicService(name: 'Filling', price: 2000),
      ClinicService(name: 'Extraction', price: 2500),
    ],
    operatingHours: const [
      OperatingHours(weekday: 1, openTime: '09:00', closeTime: '20:00'),
      OperatingHours(weekday: 2, openTime: '09:00', closeTime: '20:00'),
      OperatingHours(weekday: 3, openTime: '09:00', closeTime: '20:00'),
      OperatingHours(weekday: 4, openTime: '09:00', closeTime: '20:00'),
      OperatingHours(weekday: 5, openTime: '09:00', closeTime: '20:00'),
      OperatingHours(weekday: 6, openTime: '09:00', closeTime: '20:00'),
      OperatingHours(weekday: 7, openTime: '10:00', closeTime: '16:00'),
    ],
    phoneNumber: '+639191234567',
  ),
  ClinicModel(
    id: 'clinic_004',
    name: 'Makati Dental Studio',
    address: '200 Ayala Ave, Makati',
    latitude: 14.5547,
    longitude: 121.0244,
    rating: 4.1,
    reviewCount: 52,
    services: const [
      ClinicService(name: 'Cleaning', price: 1500),
      ClinicService(name: 'Filling', price: 2800),
      ClinicService(name: 'Extraction', price: 3200),
    ],
    operatingHours: const [
      OperatingHours(weekday: 1, openTime: '10:00', closeTime: '19:00'),
      OperatingHours(weekday: 2, openTime: '10:00', closeTime: '19:00'),
      OperatingHours(weekday: 3, openTime: '10:00', closeTime: '19:00'),
      OperatingHours(weekday: 4, openTime: '10:00', closeTime: '19:00'),
      OperatingHours(weekday: 5, openTime: '10:00', closeTime: '19:00'),
      OperatingHours(weekday: 6, openTime: '10:00', closeTime: '15:00'),
      OperatingHours(
        weekday: 7,
        openTime: '00:00',
        closeTime: '00:00',
        isClosed: true,
      ),
    ],
    phoneNumber: '+639201234567',
  ),
  ClinicModel(
    id: 'clinic_005',
    name: 'Pasig Riverside Dental',
    address: '15 Ortigas Ave, Pasig',
    latitude: 14.5764,
    longitude: 121.0851,
    rating: 3.9,
    reviewCount: 34,
    services: const [
      ClinicService(name: 'Cleaning', price: 700),
      ClinicService(name: 'Filling', price: 1300),
      ClinicService(name: 'Extraction', price: 1700),
    ],
    operatingHours: const [
      OperatingHours(weekday: 1, openTime: '09:00', closeTime: '17:00'),
      OperatingHours(weekday: 2, openTime: '09:00', closeTime: '17:00'),
      OperatingHours(weekday: 3, openTime: '09:00', closeTime: '17:00'),
      OperatingHours(weekday: 4, openTime: '09:00', closeTime: '17:00'),
      OperatingHours(weekday: 5, openTime: '09:00', closeTime: '17:00'),
      OperatingHours(weekday: 6, openTime: '09:00', closeTime: '17:00'),
      OperatingHours(weekday: 7, openTime: '09:00', closeTime: '17:00'),
    ],
    phoneNumber: '+639211234567',
  ),
];

/// Fetches the clinic list from Google Places API (New) Nearby Search.
/// Searches for dentists near the user's current location.
class ClinicListNotifier extends AsyncNotifier<List<ClinicModel>> {
  @override
  Future<List<ClinicModel>> build() async {
    final userLocation = ref.watch(userLocationProvider);
    return _fetchNearbyClinics(userLocation.latitude, userLocation.longitude);
  }

  Future<List<ClinicModel>> _fetchNearbyClinics(double lat, double lng) async {
    final uri = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': placesApiKey,
        'X-Goog-FieldMask':
            'places.id,places.displayName,places.formattedAddress,'
            'places.location,places.rating,places.userRatingCount,'
            'places.nationalPhoneNumber',
      },
      body: jsonEncode({
        'includedTypes': ['dentist'],
        'maxResultCount': 10,
        'locationRestriction': {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': 5000.0,
          },
        },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Places API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final places = (data['places'] as List<dynamic>?) ?? [];

    final clinics = places.map((p) {
      final place = p as Map<String, dynamic>;
      return ClinicModel(
        id: place['id'] as String,
        name: (place['displayName']?['text'] as String?) ?? 'Unknown Clinic',
        address: (place['formattedAddress'] as String?) ?? '',
        latitude: (place['location']?['latitude'] as num?)?.toDouble() ?? lat,
        longitude: (place['location']?['longitude'] as num?)?.toDouble() ?? lng,
        rating: (place['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (place['userRatingCount'] as num?)?.toInt() ?? 0,
        services: const [ClinicService(name: 'General Dentistry', price: 0)],
        operatingHours: const [],
        phoneNumber: (place['nationalPhoneNumber'] as String?) ?? 'Not available',
      );
    }).toList();

    clinics.sort((a, b) {
      final distanceA = Geolocator.distanceBetween(lat, lng, a.latitude, a.longitude);
      final distanceB = Geolocator.distanceBetween(lat, lng, b.latitude, b.longitude);
      return distanceA.compareTo(distanceB);
    });

    return clinics;
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final userLocation = ref.read(userLocationProvider);
      return _fetchNearbyClinics(userLocation.latitude, userLocation.longitude);
    });
  }
}

final clinicListProvider =
    AsyncNotifierProvider<ClinicListNotifier, List<ClinicModel>>(
  ClinicListNotifier.new,
);

/// Combines [clinicListProvider], [clinicFilterProvider], and
/// [userLocationProvider] to produce the clinic list the UI should
/// actually render, filtered by radius, price, minimum rating, and
/// open-now status.
final filteredClinicsProvider = Provider<AsyncValue<List<ClinicModel>>>((ref) {
  final clinicsAsync = ref.watch(clinicListProvider);
  final filters = ref.watch(clinicFilterProvider);
  final userLocation = ref.watch(userLocationProvider);

  return clinicsAsync.whenData((clinics) {
    final now = DateTime.now();

    return clinics.where((clinic) {
      // <-- ADDED BY CLAUDE: Search query filter
      if (filters.searchQuery.isNotEmpty) {
        final query = filters.searchQuery.toLowerCase();
        final nameMatch = clinic.name.toLowerCase().contains(query);
        final addressMatch = clinic.address.toLowerCase().contains(query);
        if (!nameMatch && !addressMatch) return false;
      }

      // Radius filter: distance between user and clinic, in kilometers.
      final distanceMeters = Geolocator.distanceBetween(
        userLocation.latitude,
        userLocation.longitude,
        clinic.latitude,
        clinic.longitude,
      );
      final withinRadius = (distanceMeters / 1000) <= filters.radiusKm;
      if (!withinRadius) return false;

      // Rating filter.
      if (clinic.rating < filters.minRating) return false;

      // Price filter: clinic must have at least one service at or below
      // the selected max price.
      if (filters.maxPrice != null) {
        final lowestPrice = clinic.lowestServicePrice;
        if (lowestPrice == null || lowestPrice > filters.maxPrice!) {
          return false;
        }
      }

      // Open-now filter.
      if (filters.openNowOnly && !clinic.isOpenAt(now)) {
        return false;
      }

      return true;
    }).toList();
  });
});
