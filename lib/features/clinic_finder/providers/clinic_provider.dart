// mobile/lib/features/clinic_finder/providers/clinic_provider.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

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

/// How the Clinic Finder list is ordered.
enum ClinicSort { nearest, topRated, lowestPrice }

/// Places is queried once over this radius; the distance filter then
/// narrows it client-side, so every distance option can change the list.
const double kClinicFetchRadiusKm = 10.0;

/// Active filter selections for the Clinic Finder list/map views.
class ClinicFilterState {
  final double radiusKm;
  final double? maxPrice;
  final double minRating;
  final bool openNowOnly;
  final String searchQuery; // <-- ADDED BY CLAUDE
  final ClinicSort sort;

  const ClinicFilterState({
    this.radiusKm = 5.0,
    this.maxPrice,
    this.minRating = 0.0,
    this.openNowOnly = false,
    this.searchQuery = '', // <-- ADDED BY CLAUDE
    this.sort = ClinicSort.nearest,
  });

  ClinicFilterState copyWith({
    double? radiusKm,
    double? maxPrice,
    bool clearMaxPrice = false,
    double? minRating,
    bool? openNowOnly,
    String? searchQuery, // <-- ADDED BY CLAUDE
    ClinicSort? sort,
  }) {
    return ClinicFilterState(
      radiusKm: radiusKm ?? this.radiusKm,
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      minRating: minRating ?? this.minRating,
      openNowOnly: openNowOnly ?? this.openNowOnly,
      searchQuery: searchQuery ?? this.searchQuery, // <-- ADDED BY CLAUDE
      sort: sort ?? this.sort,
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

  void setSort(ClinicSort sort) {
    state = state.copyWith(sort: sort);
  }

  void reset() {
    state = const ClinicFilterState();
  }
}

final clinicFilterProvider =
    NotifierProvider<ClinicFilterNotifier, ClinicFilterState>(
  ClinicFilterNotifier.new,
);

/// Service pool for generating per-clinic service offerings.
const _servicePool = [
  ClinicService(name: 'Consultation', price: 500),
  ClinicService(name: 'Cleaning', price: 900),
  ClinicService(name: 'Filling', price: 1800),
  ClinicService(name: 'Extraction', price: 2200),
  ClinicService(name: 'Whitening', price: 3500),
  ClinicService(name: 'Root Canal', price: 6500),
  ClinicService(name: 'Dental X-Ray', price: 800),
  ClinicService(name: 'Deep Cleaning', price: 2500),
  ClinicService(name: 'Crown/Cap', price: 8000),
  ClinicService(name: 'Braces Consultation', price: 1500),
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
    final placesApiKey = dotenv.env['PLACES_API_KEY']!;
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
        // Nearest first, so the distance filter has a real spread to cut.
        'maxResultCount': 20,
        'rankPreference': 'DISTANCE',
        'locationRestriction': {
          'circle': {
            'center': {'latitude': lat, 'longitude': lng},
            'radius': kClinicFetchRadiusKm * 1000,
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
      final placeId = place['id'] as String;
      
      // Generate deterministic random subset of services based on place ID
      final random = Random(placeId.hashCode);
      final shuffled = [..._servicePool]..shuffle(random);
      final count = 3 + random.nextInt(3); // 3 to 5 services
      // Each clinic gets its own price level (0.7x to 1.8x), so the
      // budget filter and price sort separate clinics instead of every
      // clinic starting at the same ₱500 consultation.
      final priceLevel = 0.7 + random.nextDouble() * 1.1;
      final selectedServices = [
        for (final s in shuffled.take(count))
          ClinicService(
            name: s.name,
            price: ((s.price * priceLevel) / 50).round() * 50.0,
          ),
      ];
      
      return ClinicModel(
        id: placeId,
        name: (place['displayName']?['text'] as String?) ?? 'Unknown Clinic',
        address: (place['formattedAddress'] as String?) ?? '',
        latitude: (place['location']?['latitude'] as num?)?.toDouble() ?? lat,
        longitude: (place['location']?['longitude'] as num?)?.toDouble() ?? lng,
        rating: (place['rating'] as num?)?.toDouble() ?? 0.0,
        reviewCount: (place['userRatingCount'] as num?)?.toInt() ?? 0,
        services: selectedServices,
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

    double distanceTo(ClinicModel c) => Geolocator.distanceBetween(
          userLocation.latitude,
          userLocation.longitude,
          c.latitude,
          c.longitude,
        );

    final matches = clinics.where((clinic) {
      // <-- ADDED BY CLAUDE: Search query filter
      if (filters.searchQuery.isNotEmpty) {
        final query = filters.searchQuery.toLowerCase();
        final nameMatch = clinic.name.toLowerCase().contains(query);
        final addressMatch = clinic.address.toLowerCase().contains(query);
        if (!nameMatch && !addressMatch) return false;
      }

      // Radius filter: distance between user and clinic, in kilometers.
      final withinRadius = (distanceTo(clinic) / 1000) <= filters.radiusKm;
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

    // Ties fall back to distance, so the order is always stable.
    int byDistance(ClinicModel a, ClinicModel b) =>
        distanceTo(a).compareTo(distanceTo(b));
    switch (filters.sort) {
      case ClinicSort.nearest:
        matches.sort(byDistance);
      case ClinicSort.topRated:
        matches.sort((a, b) {
          final r = b.rating.compareTo(a.rating);
          return r != 0 ? r : byDistance(a, b);
        });
      case ClinicSort.lowestPrice:
        matches.sort((a, b) {
          final pa = a.lowestServicePrice ?? double.infinity;
          final pb = b.lowestServicePrice ?? double.infinity;
          final p = pa.compareTo(pb);
          return p != 0 ? p : byDistance(a, b);
        });
    }
    return matches;
  });
});
