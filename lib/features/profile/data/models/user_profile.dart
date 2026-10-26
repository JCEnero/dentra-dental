import 'dart:typed_data';

/// Gender options offered on the profile form. `null` on [UserProfile]
/// means the user has not answered.
enum Gender {
  female('Female'),
  male('Male'),
  other('Other'),
  preferNotToSay('Prefer not to say');

  const Gender(this.label);
  final String label;

  static Gender? fromName(String? name) {
    for (final g in Gender.values) {
      if (g.name == name) return g;
    }
    return null;
  }
}

/// The signed-in user's profile and account preferences.
///
/// Immutable: edit with [copyWith] and save through `ProfileNotifier`.
class UserProfile {
  /// Server id (users.id). Null until the profile exists on the backend.
  final String? id;
  final String fullName;
  final String email;
  final String? phone;
  final DateTime? dateOfBirth;
  final Gender? gender;

  /// Profile photo as encoded image bytes (JPEG/PNG). Null shows initials.
  final Uint8List? avatarBytes;

  // ── Preferences ───────────────────────────────────────────────
  final bool analyticsConsent;
  final bool marketingConsent;
  final bool twoFactorEnabled;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.dateOfBirth,
    this.gender,
    this.avatarBytes,
    this.analyticsConsent = true,
    this.marketingConsent = false,
    this.twoFactorEnabled = false,
    this.createdAt,
    this.updatedAt,
  });

  /// Up to two initials for the avatar fallback, e.g. "Ana Cruz" -> "AC".
  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    // First code point, so accented or non-Latin names don't split a
    // surrogate pair.
    final letters =
        parts.take(2).map((w) => String.fromCharCode(w.runes.first).toUpperCase());
    final result = letters.join();
    return result.isEmpty ? '?' : result;
  }

  /// First word of the name, for greetings.
  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  /// Copies with new values. Nullable fields take a function so they can
  /// be cleared explicitly: `copyWith(phone: () => null)`.
  UserProfile copyWith({
    String? fullName,
    String? email,
    String? Function()? phone,
    DateTime? Function()? dateOfBirth,
    Gender? Function()? gender,
    Uint8List? Function()? avatarBytes,
    bool? analyticsConsent,
    bool? marketingConsent,
    bool? twoFactorEnabled,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone != null ? phone() : this.phone,
      dateOfBirth: dateOfBirth != null ? dateOfBirth() : this.dateOfBirth,
      gender: gender != null ? gender() : this.gender,
      avatarBytes: avatarBytes != null ? avatarBytes() : this.avatarBytes,
      analyticsConsent: analyticsConsent ?? this.analyticsConsent,
      marketingConsent: marketingConsent ?? this.marketingConsent,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
    );
  }

  /// JSON without the avatar. Keys match the `users` table columns so
  /// the same shape works for the local store and the future API. The
  /// photo is stored separately (avatar_url on the backend).
  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'date_of_birth': dateOfBirth?.toIso8601String().substring(0, 10),
        'gender': gender?.name,
        'analytics_consent': analyticsConsent,
        'marketing_consent': marketingConsent,
        'two_factor_enabled': twoFactorEnabled,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    Uint8List? avatarBytes,
  }) {
    DateTime? date(String key) {
      final v = json[key] as String?;
      return v == null ? null : DateTime.tryParse(v);
    }

    return UserProfile(
      id: json['id'] as String?,
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      dateOfBirth: date('date_of_birth'),
      gender: Gender.fromName(json['gender'] as String?),
      avatarBytes: avatarBytes,
      analyticsConsent: json['analytics_consent'] as bool? ?? true,
      marketingConsent: json['marketing_consent'] as bool? ?? false,
      twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
      createdAt: date('created_at')?.toLocal(),
      updatedAt: date('updated_at')?.toLocal(),
    );
  }
}
