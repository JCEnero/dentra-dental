import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

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
  Future<void> renameSession(String sessionId, String title);
  Future<void> deleteSession(String sessionId);
  Future<void> deleteAll();

  void close();
}

/// Rabi through the DENTRA backend (`/api/ai`). The Gemini key stays on
/// the server, and chats are saved to the user's account.
///
/// Works with both server styles: a single JSON `{"reply": ...}`, or
/// server-sent events (see [_readEvents]) for text that shows as it's
/// written. The server picks; the request accepts either.
class ApiRabiService implements RabiService {
  ApiRabiService(
    this._api, {
    this.firstReplyTimeout = const Duration(seconds: 15),
    this.chunkTimeout = const Duration(seconds: 12),
  });

  final ApiClient _api;

  /// Longest wait for the server to start answering (the whole reply,
  /// for a JSON answer).
  final Duration firstReplyTimeout;

  /// Longest gap between streamed chunks.
  final Duration chunkTimeout;

  static const _troubleMessage =
      'Rabi had trouble answering. Please try again.';

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
      final response = await _api
          .openStream(
            'POST',
            '/api/ai/chat',
            json: {
              'session_id': sessionId,
              'message': message,
              if (prompt != null) 'prompt': prompt,
              // Latest answered turns (already trimmed), for a server that
              // doesn't keep the conversation itself.
              'history': [
                for (final (isUser, text) in context)
                  {'role': isUser ? 'user' : 'model', 'text': text},
              ],
            },
            accept: 'text/event-stream, application/json',
          )
          .timeout(firstReplyTimeout);

      final type = response.headers['content-type'] ?? '';
      final text = type.contains('text/event-stream')
          ? await _readEvents(response, onPartial)
          : await _readJson(response);
      if (text.trim().isEmpty) {
        throw const GeminiException(
          "I'm sorry, I didn't get a response. Please try again.",
        );
      }
      return text.trim();
    } on GeminiException {
      rethrow;
    } on ApiException catch (e) {
      throw GeminiException(e.message);
    } on TimeoutException {
      throw const GeminiException(
        'Rabi is taking too long to answer. Please try again.',
      );
    } catch (_) {
      throw const GeminiException(
        "Couldn't reach Rabi. Check your connection and try again.",
      );
    }
  }

  Future<String> _readJson(http.StreamedResponse response) async {
    final body = _api.decode(
      await http.Response.fromStream(response).timeout(firstReplyTimeout),
    );
    return body['reply'] as String? ?? '';
  }

  /// Server-sent events, one `data:` line each:
  /// `{"delta": "..."}` adds text, `{"reply": "..."}` replaces it with the
  /// full reply, `{"error": {"message": "..."}}` fails, `[DONE]` ends.
  Future<String> _readEvents(
    http.StreamedResponse response,
    void Function(String textSoFar)? onPartial,
  ) async {
    final reply = StringBuffer();
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(chunkTimeout);
    await for (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final data = line.substring(5).trim();
      if (data == '[DONE]') break;
      final event = jsonDecode(data);
      if (event is! Map<String, dynamic>) continue;
      if (event['error'] case final Map<String, dynamic> error) {
        throw GeminiException(error['message'] as String? ?? _troubleMessage);
      }
      if (event['delta'] case final String delta) {
        reply.write(delta);
      } else if (event['reply'] case final String full) {
        reply
          ..clear()
          ..write(full);
      } else {
        continue;
      }
      onPartial?.call(reply.toString());
    }
    return reply.toString();
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
  Future<void> renameSession(String sessionId, String title) => _api.send(
        'PATCH',
        '/api/ai/sessions/${Uri.encodeComponent(sessionId)}',
        json: {'title': title},
      );

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
  Future<void> renameSession(String sessionId, String title) async {}

  @override
  Future<void> deleteSession(String sessionId) async {}

  @override
  Future<void> deleteAll() async {}

  @override
  void close() => _gemini.close();
}
