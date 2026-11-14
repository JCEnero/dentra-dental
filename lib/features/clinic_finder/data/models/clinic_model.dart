// mobile/lib/features/clinic_finder/data/models/clinic_model.dart

/// Represents a single dental service offered by a clinic, along with
/// its price. Used inside [ClinicModel.services].
class ClinicService {
  final String name;
  final double price;

  const ClinicService({
    required this.name,
    required this.price,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
    };
  }
}

/// Represents the opening and closing time for a single day of the week.
/// [isClosed] should be used when the clinic does not operate that day,
/// in which case [openTime] and [closeTime] are ignored.
class OperatingHours {
  final int weekday; // 1 = Monday ... 7 = Sunday (DateTime.weekday convention)
  final String openTime; // 24hr format, e.g. "09:00"
  final String closeTime; // 24hr format, e.g. "18:00"
  final bool isClosed;

  const OperatingHours({
    required this.weekday,
    required this.openTime,
    required this.closeTime,
    this.isClosed = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'weekday': weekday,
      'openTime': openTime,
      'closeTime': closeTime,
      'isClosed': isClosed,
    };
  }
}

/// Core data model for a dental clinic returned by the Clinic Finder feature.
///
/// Includes location, rating/review summary, offered services with pricing,
/// weekly operating hours, and contact details needed for the
/// "Directions" / "Call" actions on the clinic details screen.
class ClinicModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final List<ClinicService> services;
  final List<OperatingHours> operatingHours;
  final String phoneNumber;
  final String? imageUrl;

  const ClinicModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    required this.services,
    required this.operatingHours,
    required this.phoneNumber,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'rating': rating,
      'reviewCount': reviewCount,
      'services': services.map((e) => e.toJson()).toList(),
      'operatingHours': operatingHours.map((e) => e.toJson()).toList(),
      'phoneNumber': phoneNumber,
      'imageUrl': imageUrl,
    };
  }

  /// Returns the [OperatingHours] entry matching the given [weekday]
  /// (1 = Monday ... 7 = Sunday), or null if none is defined.
  OperatingHours? hoursFor(int weekday) {
    for (final hours in operatingHours) {
      if (hours.weekday == weekday) {
        return hours;
      }
    }
    return null;
  }

  /// Determines whether the clinic is open at the given [dateTime]
  /// (defaults to now). Used by filters and the details screen to show
  /// an open/closed badge.
  bool isOpenAt(DateTime dateTime) {
    final todayHours = hoursFor(dateTime.weekday);
    if (todayHours == null || todayHours.isClosed) {
      return false;
    }

    final openParts = todayHours.openTime.split(':');
    final closeParts = todayHours.closeTime.split(':');
    final openMinutes =
        int.parse(openParts[0]) * 60 + int.parse(openParts[1]);
    final closeMinutes =
        int.parse(closeParts[0]) * 60 + int.parse(closeParts[1]);
    final nowMinutes = dateTime.hour * 60 + dateTime.minute;

    return nowMinutes >= openMinutes && nowMinutes < closeMinutes;
  }

  /// Returns the lowest price among all offered [services], or null if
  /// the clinic has no listed services. Useful for price-based filtering.
  double? get lowestServicePrice {
    if (services.isEmpty) return null;
    return services.map((s) => s.price).reduce((a, b) => a < b ? a : b);
  }

}
