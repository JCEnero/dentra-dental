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
You are DENTRA AI, a helpful dental health assistant built into the DENTRA app.
Your role is to answer questions about oral health, dental hygiene, screening results,
common dental conditions, treatment options, and when to see a dentist.

Guidelines:
- Be warm, clear, and concise.
- Always remind users that your answers are informational only and not a substitute
  for a professional dental examination or diagnosis.
- If a question is completely unrelated to oral/dental health, politely redirect the
  user and offer to help with dental questions instead.
- Use plain language — avoid heavy medical jargon unless the user asks for detail.
''';

  final String _apiKey;

  /// Conversation history: list of {role, parts} maps sent with every request.
  final List<Map<String, dynamic>> _history = [];

  GeminiService()
      : _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '' {
    assert(_apiKey.isNotEmpty,
        'GEMINI_API_KEY is missing from your .env file');
  }

  /// Sends [userMessage] to Gemini and returns the assistant reply.
  Future<String> chat(String userMessage) async {
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
        // Parse API error message for a readable error.
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final message =
            (json['error'] as Map<String, dynamic>?)?['message'] as String? ??
                'Unknown API error (status ${response.statusCode})';
        throw GeminiException(message);
      }
    } on GeminiException {
      rethrow;
    } catch (e) {
      throw GeminiException(
        'Could not reach the AI service. Please check your connection and try again.',
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
}

/// Thrown when [GeminiService.chat] encounters an unrecoverable error.
class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);

  @override
  String toString() => 'GeminiException: $message';
}
