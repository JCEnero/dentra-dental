import 'dart:async';
import 'dart:convert';

import 'package:dentra_mobile/core/network/api_client.dart';
import 'package:dentra_mobile/core/services/gemini_service.dart';
import 'package:dentra_mobile/features/ai_assistant/ai_chat_controller.dart';
import 'package:dentra_mobile/features/ai_assistant/rabi_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ChatMessage _msg(String text, {bool user = false, bool error = false}) =>
    ChatMessage(
      text: text,
      isUser: user,
      isError: error,
      sentAt: DateTime(2026),
    );

/// [count] answered question/reply pairs.
List<ChatMessage> _pairs(int count) => [
      for (var i = 0; i < count; i++) ...[
        _msg('q$i', user: true),
        _msg('a$i'),
      ],
    ];

/// An API whose /api/ai/chat answers with [handler], recording the body.
(ApiRabiService, List<Map<String, dynamic>>) _service(
  Future<http.StreamedResponse> Function() handler, {
  Duration firstReplyTimeout = const Duration(seconds: 15),
  Duration chunkTimeout = const Duration(seconds: 12),
}) {
  final bodies = <Map<String, dynamic>>[];
  final client = MockClient.streaming((request, bodyStream) async {
    bodies.add(jsonDecode(await bodyStream.bytesToString())
        as Map<String, dynamic>);
    return handler();
  });
  final api = ApiClient(
    baseUrl: 'https://api.test',
    accessToken: () async => 'token',
    client: client,
  );
  return (
    ApiRabiService(api,
        firstReplyTimeout: firstReplyTimeout, chunkTimeout: chunkTimeout),
    bodies,
  );
}

http.StreamedResponse _response(
  Stream<String> body, {
  int status = 200,
  String type = 'application/json',
}) =>
    http.StreamedResponse(body.transform(utf8.encoder), status,
        headers: {'content-type': type});

Future<String> _ask(ApiRabiService rabi,
        {void Function(String)? onPartial, List<(bool, String)>? context}) =>
    rabi.reply(
      sessionId: 's1',
      message: 'How often should I floss?',
      context: context ?? const [],
      onPartial: onPartial,
    );

void main() {
  group('history trimming', () {
    test('keeps every turn of a short chat', () {
      final turns = AiChatController.contextFor(_pairs(2));
      expect(turns, [(true, 'q0'), (false, 'a0'), (true, 'q1'), (false, 'a1')]);
    });

    test('keeps only the latest 8 turns, starting on a question', () {
      final turns = AiChatController.contextFor(_pairs(10));
      expect(turns, hasLength(AiChatController.maxContextTurns));
      expect(turns.first, (true, 'q6'));
      expect(turns.last, (false, 'a9'));
    });

    test('drops failed questions and error notices', () {
      final turns = AiChatController.contextFor([
        ..._pairs(1),
        _msg('lost question', user: true),
        _msg('Rabi had trouble answering.', error: true),
      ]);
      expect(turns, [(true, 'q0'), (false, 'a0')]);
    });
  });

  group('backend replies', () {
    test('reads a single JSON reply and sends the trimmed history', () async {
      final (rabi, bodies) = _service(() async =>
          _response(Stream.value(jsonEncode({'reply': ' Daily. '}))));
      final history = AiChatController.contextFor(_pairs(10));

      expect(await _ask(rabi, context: history), 'Daily.');
      final sent = bodies.single['history'] as List<dynamic>;
      expect(sent, hasLength(8));
      expect(sent.first, {'role': 'user', 'text': 'q6'});
    });

    test('streams server-sent events as they arrive', () async {
      final (rabi, _) = _service(() async => _response(
            Stream.fromIterable([
              'data: {"delta": "Floss "}\n\n',
              'data: {"delta": "once a day."}\n\n',
              'data: [DONE]\n\n',
            ]),
            type: 'text/event-stream',
          ));
      final partials = <String>[];

      expect(await _ask(rabi, onPartial: partials.add), 'Floss once a day.');
      expect(partials, ['Floss ', 'Floss once a day.']);
    });

    test('shows the message of a streamed error event', () async {
      final (rabi, _) = _service(() async => _response(
            Stream.value(
                'data: {"error": {"message": "Rabi is busy right now."}}\n\n'),
            type: 'text/event-stream',
          ));
      expect(
        _ask(rabi),
        throwsA(isA<GeminiException>()
            .having((e) => e.message, 'message', 'Rabi is busy right now.')),
      );
    });

    test('shows the message of an error body', () async {
      final (rabi, _) = _service(() async => _response(
            Stream.value(jsonEncode({
              'error': {'code': 'ai_failed', 'message': 'Try again soon.'}
            })),
            status: 502,
          ));
      expect(
        _ask(rabi),
        throwsA(isA<GeminiException>()
            .having((e) => e.message, 'message', 'Try again soon.')),
      );
    });

    test('times out with a friendly message when the server is silent',
        () async {
      final (rabi, _) = _service(
        () => Completer<http.StreamedResponse>().future, // never answers
        firstReplyTimeout: const Duration(milliseconds: 50),
      );
      expect(
        _ask(rabi),
        throwsA(isA<GeminiException>().having((e) => e.message, 'message',
            'Rabi is taking too long to answer. Please try again.')),
      );
    });

    test('times out when a stream stalls midway', () async {
      final stalled = StreamController<String>();
      final (rabi, _) = _service(
        () async {
          stalled.add('data: {"delta": "Floss "}\n\n'); // then nothing
          return _response(stalled.stream, type: 'text/event-stream');
        },
        chunkTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        _ask(rabi),
        throwsA(isA<GeminiException>().having((e) => e.message, 'message',
            'Rabi is taking too long to answer. Please try again.')),
      );
      await stalled.close();
    });
  });
}
