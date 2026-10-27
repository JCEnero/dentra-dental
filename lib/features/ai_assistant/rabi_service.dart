import 'dart:async';

import '../../core/network/api_client.dart';
import '../../core/services/gemini_service.dart';
import 'ai_chat_controller.dart';

/// Where Rabi's answers come from, and whether chats are saved there.
abstract class RabiService {
  /// Asks for a reply to [message] in conversation [sessionId]. [prompt]
  /// replaces [message] for the model when set. [context] holds the
  /// earlier answered turns as (isUser, text); only services that don't
  /// keep the conversation themselves use it. Services that stream call
  /// [onPartial] with the reply so far as it arrives.
  ///
  /// Throws [GeminiException] with a message that is safe to show.
  Future<String> reply({
    required String sessionId,
    required String message,
    String? prompt,
    required List<(bool, String)> context,
    void Function(String textSoFar)? onPartial,
  });

  /// Whether conversations are saved by the service (the server), rather
  /// than on this device.
  bool get savesHistory;

  Future<List<ChatSession>> loadSessions();
  Future<void> deleteSession(String sessionId);
  Future<void> deleteAll();

  void close();
}

/// Rabi through the DENTRA backend (`/api/ai`). The Gemini key stays on
/// the server, and chats are saved to the user's account.
class ApiRabiService implements RabiService {
  ApiRabiService(this._api);

  final ApiClient _api;

  @override
  bool get savesHistory => true;

  @override
  Future<String> reply({
    required String sessionId,
    required String message,
    String? prompt,
    required List<(bool, String)> context,
    void Function(String textSoFar)? onPartial,
  }) async {
    try {
      final body = await _api.send('POST', '/api/ai/chat', json: {
        'session_id': sessionId,
        'message': message,
        if (prompt != null) 'prompt': prompt,
      });
      return body['reply'] as String;
    } on ApiException catch (e) {
      throw GeminiException(e.message);
    } catch (_) {
      throw const GeminiException(
        "Couldn't reach Rabi. Check your connection and try again.",
      );
    }
  }

  @override
  Future<List<ChatSession>> loadSessions() async {
    final body = await _api.send('GET', '/api/ai/sessions');
    return [
      for (final item in body['items'] as List<dynamic>)
        ChatSession.fromJson(item as Map<String, dynamic>),
    ];
  }

  @override
  Future<void> deleteSession(String sessionId) => _api.send(
        'DELETE',
        '/api/ai/sessions/${Uri.encodeComponent(sessionId)}',
      );

  @override
  Future<void> deleteAll() => _api.send('DELETE', '/api/ai/sessions');

  @override
  void close() {}
}

/// Rabi straight from Gemini, for demo builds without a backend. Needs
/// GEMINI_API_KEY in the app's `.env`; chats stay on this device.
class DirectRabiService implements RabiService {
  DirectRabiService([GeminiService? gemini])
      : _gemini = gemini ?? GeminiService();

  final GeminiService _gemini;

  @override
  bool get savesHistory => false;

  @override
  Future<String> reply({
    required String sessionId,
    required String message,
    String? prompt,
    required List<(bool, String)> context,
    void Function(String textSoFar)? onPartial,
  }) {
    _gemini.restoreSession(context);
    return _gemini.chat(prompt ?? message, onPartial: onPartial);
  }

  @override
  Future<List<ChatSession>> loadSessions() async => const [];

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  void close() => _gemini.close();
}
