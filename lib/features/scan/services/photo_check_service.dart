import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import 'photo_quality.dart';

/// Why a photo can't be used. Codes match ml/inference's quality reasons.
enum PhotoProblem {
  noTeeth('no_teeth'),
  blurry('blurry'),
  tooDark('too_dark'),
  tooBright('too_bright'),
  tooSmall('too_small'),
  unreadable('unreadable'),

  /// A reason this version of the app has no words for: shows the server's.
  other('other');

  const PhotoProblem(this.code);

  /// The server's name for it.
  final String code;

  static PhotoProblem fromCode(String? code) =>
      values.firstWhere((p) => p.code == code, orElse: () => other);
}

/// The photo check's answer for one photo.
class PhotoVerdict {
  const PhotoVerdict.passed({this.teethChecked = true})
      : problem = null,
        message = null;

  const PhotoVerdict.rejected(PhotoProblem this.problem, {this.message})
      : teethChecked = true;

  /// Null when the photo passed.
  final PhotoProblem? problem;

  /// Whether the check looked for teeth, not only at light and focus.
  final bool teethChecked;

  /// What the server said to do, used for problems the app has no words for.
  final String? message;

  bool get passed => problem == null;
}

/// The check couldn't reach a verdict, so the photo is neither passed nor
/// rejected. It can't be kept until a check passes it.
class PhotoCheckException implements Exception {
  const PhotoCheckException({this.offline = false, this.message});

  final bool offline;

  /// From the server, already written for users (e.g. "slow down").
  final String? message;

  @override
  String toString() => 'PhotoCheckException(offline: $offline)';
}

/// Checks one photo right after it's taken, before it may be kept.
abstract class PhotoCheckService {
  /// Throws [PhotoCheckException] when no verdict could be reached.
  Future<PhotoVerdict> check(Uint8List bytes);
}

/// The server's check: quality, then whether the photo shows teeth. Analysis
/// runs the same check on every photo again, so this is never the only guard.
class ApiPhotoCheckService implements PhotoCheckService {
  ApiPhotoCheckService(this._api, {PhotoCheckService? whenUnavailable})
      : _unavailable = whenUnavailable ?? const LocalPhotoCheckService();

  final ApiClient _api;

  /// Used when the server has no analysis at all, so nothing will be analyzed.
  final PhotoCheckService _unavailable;

  @override
  Future<PhotoVerdict> check(Uint8List bytes) async {
    try {
      final body = await _api.send(
        'POST',
        '/api/screenings/validate-photo',
        bytes: bytes,
        contentType: imageContentType(bytes),
      );
      if (body['valid'] == true) return const PhotoVerdict.passed();
      return PhotoVerdict.rejected(
        PhotoProblem.fromCode(body['reason'] as String?),
        message: body['message'] as String?,
      );
    } on ApiException catch (e) {
      if (e.code == 'analysis_unavailable') return _unavailable.check(bytes);
      // The API won't take it as a photo at all: not a JPEG, PNG or WebP, or
      // too large. That's a verdict on the photo, with the API's reason.
      if (const {'unsupported_image', 'no_image', 'file_too_large'}
          .contains(e.code)) {
        return PhotoVerdict.rejected(PhotoProblem.other, message: e.message);
      }
      throw PhotoCheckException(
        message: e.code == 'rate_limited' ? e.message : null,
      );
    } on SocketException {
      throw const PhotoCheckException(offline: true);
    } on http.ClientException {
      throw const PhotoCheckException(offline: true);
    } on TimeoutException {
      throw const PhotoCheckException();
    }
  }
}

/// Light, focus and size, measured on the phone with ml/inference's numbers.
/// Only for where nothing gets analyzed: without a server, or one with no
/// analysis. It can't tell whether a photo shows teeth.
class LocalPhotoCheckService implements PhotoCheckService {
  const LocalPhotoCheckService();

  @override
  Future<PhotoVerdict> check(Uint8List bytes) async {
    final quality = await PhotoQuality.measure(bytes);
    final problem = switch (quality) {
      null => PhotoProblem.unreadable,
      PhotoQuality(tooSmall: true) => PhotoProblem.tooSmall,
      PhotoQuality(light: PhotoLight.dark) => PhotoProblem.tooDark,
      PhotoQuality(light: PhotoLight.glare) => PhotoProblem.tooBright,
      PhotoQuality(focus: PhotoFocus.soft) => PhotoProblem.blurry,
      _ => null,
    };
    return problem == null
        ? const PhotoVerdict.passed(teethChecked: false)
        : PhotoVerdict.rejected(problem);
  }
}

/// The server's check whenever the app talks to the DENTRA API; the on-device
/// one in demo mode, where scans aren't analyzed.
final photoCheckServiceProvider = Provider<PhotoCheckService>((ref) {
  final api = ref.watch(apiClientProvider);
  return api == null
      ? const LocalPhotoCheckService()
      : ApiPhotoCheckService(api);
});
