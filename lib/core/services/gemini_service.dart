import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Calls the Gemini REST API directly so we are not tied to any SDK version.
/// Uses a flash-lite model for low latency, and streams the reply (SSE) so
/// text shows as soon as the first words arrive.
class GeminiService {
  static const _model = 'gemini-3.5-flash-lite';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:streamGenerateContent';

  /// How long to wait for the first words, and then between chunks.
  static const _firstChunkTimeout = Duration(seconds: 15);
  static const _chunkTimeout = Duration(seconds: 12);

  /// Dental-focused system instruction so Gemini stays on topic.
  static const _systemInstruction = '''
You are Rabi, the helpful dental health assistant built into the DENTRA app.
Your role is to answer questions about oral health, dental hygiene, screening results,
common dental conditions, treatment options, and when to see a dentist.

Guidelines:
- Be warm, clear, and concise.
- The app already shows a "general information, not a diagnosis" note, so don't
  repeat a disclaimer in every answer. When symptoms sound urgent (severe pain,
  swelling, fever, bleeding that won't stop, trauma), say to see a dentist soon.
- If a question is not about oral or dental health, reply in one or two friendly
  sentences that you focus on dental topics, and offer an example dental question
  you can help with. Don't answer the off-topic question.
- You don't know the user's location. If they ask for a clinic or dentist nearby,
  suggest the Clinics tab in DENTRA, which lists nearby clinics once location is
  turned on, or ask which city or area they are in. Never invent clinic names,
  addresses or prices.
- Use plain language — avoid heavy medical jargon unless the user asks for detail.
- Keep answers short and scannable: a brief answer first, then short bullet
  points if useful. Use **bold** sparingly for key terms. No headings or tables.
- When the message includes the user's screening data, explain it in plain
  terms without inventing findings that are not in the data.
''';

  final String _apiKey;

  /// One client for the whole chat, so follow-up questions reuse the open
  /// connection instead of a new TCP/TLS handshake each time.
  final http.Client _client;

  /// Conversation history: list of {role, parts} maps sent with every request.
  final List<Map<String, dynamic>> _history = [];

  GeminiService({http.Client? client})
      : _apiKey = _readKey(),
        _client = client ?? http.Client();

  /// Releases the connection. The service can't be used afterwards.
  void close() => _client.close();

  static String _readKey() {
    try {
      return dotenv.env['GEMINI_API_KEY'] ?? '';
    } catch (_) {
      // dotenv not loaded (e.g. in tests).
      return '';
    }
  }

  /// Sends [userMessage] to Gemini and returns the assistant reply.
  /// [onPartial] receives the reply so far each time more text arrives.
  ///
  /// On failure the user turn is removed again, so a retry doesn't send
  /// the same question twice in the conversation context.
  Future<String> chat(
    String userMessage, {
    void Function(String textSoFar)? onPartial,
  }) async {
    if (_apiKey.isEmpty) {
      throw const GeminiException(
        "Rabi isn't set up on this build yet. Please try again later.",
      );
    }
    try {
      return await _send(userMessage, onPartial);
    } catch (_) {
      if (_history.isNotEmpty && _history.last['role'] == 'user') {
        _history.removeLast();
      }
      rethrow;
    }
  }

  Future<String> _send(
    String userMessage,
    void Function(String textSoFar)? onPartial,
  ) async {
    // Add user turn to history.
    _history.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    final url = Uri.parse('$_baseUrl?alt=sse&key=$_apiKey');

    final body = jsonEncode({
      'system_instruction': {
        'parts': [
          {'text': _systemInstruction}
        ],
      },
      'contents': _history,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 512,
      },
    });

    try {
      final request = http.Request('POST', url)
        ..headers['Content-Type'] = 'application/json'
        ..body = body;
      final response = await _client.send(request).timeout(_firstChunkTimeout);

      if (response.statusCode != 200) {
        // Raw API messages can mention keys and quotas; keep them out of
        // the UI and explain by status instead.
        throw GeminiException(switch (response.statusCode) {
          429 => 'Rabi is getting a lot of questions right now. '
              'Please try again in a minute.',
          400 ||
          401 ||
          403 =>
            "Rabi isn't available right now. Please try again later.",
          _ => 'Rabi had trouble answering. Please try again.',
        });
      }

      // Each SSE event is a `data: {...}` line holding the next piece.
      final reply = StringBuffer();
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(_chunkTimeout);
      await for (final line in lines) {
        if (!line.startsWith('data:')) continue;
        final chunk = _extractText(
          jsonDecode(line.substring(5)) as Map<String, dynamic>,
        );
        if (chunk.isEmpty) continue;
        reply.write(chunk);
        onPartial?.call(reply.toString());
      }

      final text = reply.toString().trim();
      if (text.isEmpty) {
        throw const GeminiException(
          "I'm sorry, I didn't get a response. Please try again.",
        );
      }

      // Add model turn to history so future messages have context.
      _history.add({
        'role': 'model',
        'parts': [
          {'text': text}
        ],
      });
      return text;
    } on GeminiException {
      rethrow;
    } on TimeoutException {
      throw const GeminiException(
        'Rabi is taking too long to answer. Please try again.',
      );
    } catch (e) {
      throw const GeminiException(
        "Couldn't reach Rabi. Check your connection and try again.",
      );
    }
  }

  /// Text of one streamed chunk; empty when it carries none (e.g. the
  /// final chunk with only usage data).
  String _extractText(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return '';
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>? ?? const [];
    return [
      for (final part in parts.cast<Map<String, dynamic>>())
        // Thinking models can stream their reasoning as `thought` parts.
        if (part['thought'] != true && part['text'] is String)
          part['text'] as String,
    ].join();
  }

  /// Replaces the conversation context, e.g. to continue a saved chat.
  /// [turns] are (isUser, text) pairs in order.
  void restoreSession(Iterable<(bool, String)> turns) {
    _history
      ..clear()
      ..addAll([
        for (final (isUser, text) in turns)
          {
            'role': isUser ? 'user' : 'model',
            'parts': [
              {'text': text}
            ],
          },
      ]);
  }
}

/// Thrown when [GeminiService.chat] encounters an unrecoverable error.
class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);

  @override
  String toString() => 'GeminiException: $message';
}
