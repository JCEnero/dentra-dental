import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Calls the Gemini REST API directly so we are not tied to any SDK version.
/// Uses gemini-2.5-flash-lite — free tier, low latency, supports generateContent.
class GeminiService {
  static const _model = 'gemini-3.5-flash-lite';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent';

  /// Dental-focused system instruction so Gemini stays on topic.
  static const _systemInstruction = '''
You are Rabi, the helpful dental health assistant built into the DENTRA app.
Your role is to answer questions about oral health, dental hygiene, screening results,
common dental conditions, treatment options, and when to see a dentist.

Guidelines:
- Be warm, clear, and concise.
- Always remind users that your answers are informational only and not a substitute
  for a professional dental examination or diagnosis.
- If a question is completely unrelated to oral/dental health, politely redirect the
  user and offer to help with dental questions instead.
- Use plain language — avoid heavy medical jargon unless the user asks for detail.
- Keep answers short and scannable: a brief answer first, then short bullet
  points if useful. Use **bold** sparingly for key terms. No headings or tables.
- When the message includes the user's screening data, explain it in plain
  terms without inventing findings that are not in the data.
''';

  final String _apiKey;

  /// Conversation history: list of {role, parts} maps sent with every request.
  final List<Map<String, dynamic>> _history = [];

  GeminiService() : _apiKey = _readKey();

  static String _readKey() {
    try {
      return dotenv.env['GEMINI_API_KEY'] ?? '';
    } catch (_) {
      // dotenv not loaded (e.g. in tests).
      return '';
    }
  }

  /// Sends [userMessage] to Gemini and returns the assistant reply.
  ///
  /// On failure the user turn is removed again, so a retry doesn't send
  /// the same question twice in the conversation context.
  Future<String> chat(String userMessage) async {
    if (_apiKey.isEmpty) {
      throw const GeminiException(
        "Rabi isn't set up on this build yet. Please try again later.",
      );
    }
    try {
      return await _send(userMessage);
    } catch (_) {
      if (_history.isNotEmpty && _history.last['role'] == 'user') {
        _history.removeLast();
      }
      rethrow;
    }
  }

  Future<String> _send(String userMessage) async {
    // Add user turn to history.
    _history.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    final url = Uri.parse('$_baseUrl?key=$_apiKey');

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
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = _extractText(json);

        // Add model turn to history so future messages have context.
        _history.add({
          'role': 'model',
          'parts': [
            {'text': reply}
          ],
        });

        return reply;
      } else {
        // Raw API messages can mention keys and quotas; keep them out of
        // the UI and explain by status instead.
        throw GeminiException(switch (response.statusCode) {
          429 => 'Rabi is getting a lot of questions right now. '
              'Please try again in a minute.',
          400 || 401 || 403 =>
            "Rabi isn't available right now. Please try again later.",
          _ => 'Rabi had trouble answering. Please try again.',
        });
      }
    } on GeminiException {
      rethrow;
    } catch (e) {
      throw const GeminiException(
        "Couldn't reach Rabi. Check your connection and try again.",
      );
    }
  }

  String _extractText(Map<String, dynamic> json) {
    final candidates = json['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      return "I'm sorry, I didn't get a response. Please try again.";
    }
    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    final text = parts?.firstOrNull?['text'] as String?;
    return text?.trim() ??
        "I'm sorry, I didn't get a response. Please try again.";
  }

  /// Resets the conversation history, starting a fresh session.
  void resetSession() => _history.clear();

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
