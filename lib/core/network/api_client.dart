import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// The DENTRA API answered with an error. [message] comes from the server
/// and is written to be shown to users.
class ApiException implements Exception {
  final int statusCode;

  /// Stable, machine-readable code, e.g. `email_taken`.
  final String code;
  final String message;

  /// Per-field messages, keyed by the request's JSON field name.
  final Map<String, String> fields;

  const ApiException(
    this.statusCode,
    this.code,
    this.message, {
    this.fields = const {},
  });

  /// The session can't be continued; the user has to sign in again.
  bool get isUnauthenticated => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode, $code)';
}

/// Supplies the current access token, refreshing it when needed. Null
/// when nobody is signed in.
typedef AccessTokenProvider = Future<String?> Function();

/// Thin JSON client for the DENTRA REST API.
///
/// Network failures surface as the usual `http`/`dart:io` exceptions (or
/// [TimeoutException]); callers decide how to explain them.
class ApiClient {
  ApiClient({
    required String baseUrl,
    this.accessToken,
    http.Client? client,
  })  : baseUrl = baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;

  /// Used by [authorized] requests. Null for a client that only makes
  /// public calls (sign-in).
  final AccessTokenProvider? accessToken;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);
  static const _genericError = 'Something went wrong. Please try again.';

  /// Turns a URL the API returned (images may be relative to it) into an
  /// absolute one the app can load.
  String resolve(String url) => Uri.parse('$baseUrl/').resolve(url).toString();

  /// Sends a request and returns its JSON body (empty for 204).
  ///
  /// With [authorized], attaches the signed-in user's token, or fails with
  /// a 401 [ApiException] when there is none. [bearer] passes a token
  /// explicitly instead.
  Future<Map<String, dynamic>> send(
    String method,
    String path, {
    Map<String, dynamic>? json,
    Map<String, String>? query,
    Uint8List? bytes,
    String? contentType,
    bool authorized = true,
    String? bearer,
  }) async {
    var token = bearer;
    if (token == null && authorized) {
      token = await accessToken?.call();
      if (token == null) {
        throw const ApiException(
          401,
          'unauthenticated',
          'Your session has ended. Please sign in again.',
        );
      }
    }

    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (json != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(json);
    } else if (bytes != null) {
      request.headers['Content-Type'] =
          contentType ?? 'application/octet-stream';
      request.bodyBytes = bytes;
    }

    final streamed = await _client.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed).timeout(_timeout);
    return _decode(response);
  }

  /// Downloads raw bytes, e.g. a signed image URL from the API.
  Future<Uint8List> download(String url) async {
    final response = await _client.get(Uri.parse(resolve(url))).timeout(_timeout);
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, 'download_failed', _genericError);
    }
    return response.bodyBytes;
  }

  /// Returns the JSON body of a 2xx response, or throws [ApiException].
  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic>? body;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } on FormatException {
        // A proxy error page or similar; handled below.
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body ?? const {};
    }

    final error = body?['error'];
    if (error is Map<String, dynamic>) {
      final fields = error['fields'];
      throw ApiException(
        response.statusCode,
        error['code'] as String? ?? 'unknown',
        error['message'] as String? ?? _genericError,
        fields: fields is Map
            ? fields.map((k, v) => MapEntry('$k', '$v'))
            : const {},
      );
    }
    throw ApiException(response.statusCode, 'unknown', _genericError);
  }
}

/// Content type for image bytes, from their first bytes. The API checks
/// the bytes too; this just labels the upload correctly.
String imageContentType(Uint8List bytes) {
  bool starts(List<int> sig, [int offset = 0]) =>
      bytes.length >= offset + sig.length &&
      [for (var i = 0; i < sig.length; i++) bytes[offset + i] == sig[i]]
          .every((m) => m);
  if (starts([0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (starts([0x89, 0x50, 0x4e, 0x47])) return 'image/png';
  if (starts([0x52, 0x49, 0x46, 0x46]) && starts([0x57, 0x45, 0x42, 0x50], 8)) {
    return 'image/webp';
  }
  return 'application/octet-stream';
}
