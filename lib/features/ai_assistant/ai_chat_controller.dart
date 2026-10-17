import 'dart:convert';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/gemini_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime sentAt;

  /// An assistant-side error notice (shown with a retry), not a reply.
  final bool isError;

  /// What was actually sent to the model, when it differs from [text]
  /// (e.g. a question with the user's screening data attached).
  final String? prompt;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.sentAt,
    this.isError = false,
    this.prompt,
  });

  String get modelText => prompt ?? text;

  Map<String, dynamic> toJson() => {
        'text': text,
        'is_user': isUser,
        'sent_at': sentAt.toUtc().toIso8601String(),
        if (isError) 'is_error': true,
        if (prompt != null) 'prompt': prompt,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        isUser: json['is_user'] as bool,
        sentAt: DateTime.parse(json['sent_at'] as String).toLocal(),
        isError: json['is_error'] as bool? ?? false,
        prompt: json['prompt'] as String?,
      );
}

/// A saved chat.
class ChatSession {
  final String id;

  /// The first user question, used as the title in the history list.
  final String title;
  final List<ChatMessage> messages;

  /// Last activity.
  final DateTime savedAt;

  const ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.savedAt,
  });

  int get questionCount => messages.where((m) => m.isUser).length;

  /// Last assistant reply, for the history preview.
  String? get preview => messages
      .lastWhere((m) => !m.isUser && !m.isError,
          orElse: () => ChatMessage(
                text: '',
                isUser: false,
                sentAt: savedAt,
              ))
      .text
      .replaceAll(RegExp(r'[*_#`]'), '')
      .trim();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'saved_at': savedAt.toUtc().toIso8601String(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        title: json['title'] as String,
        savedAt: DateTime.parse(json['saved_at'] as String).toLocal(),
        messages: (json['messages'] as List<dynamic>)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A ready-made question. [prompt] is sent instead of [label] when the
/// question needs extra context (e.g. screening data).
class ChatSuggestion {
  const ChatSuggestion(this.label, {this.prompt, this.personal = false});

  final String label;
  final String? prompt;

  /// Uses the user's own data; shown first and marked in the UI.
  final bool personal;
}

enum ChatView { chat, history, session }

/// Holds all AI chat state and is shared across the entire app shell.
/// Attach one instance to AppShell and pass it down via [AiChatScope].
///
/// Chats are saved per user on this device as they happen, so nothing is
/// lost if the app is closed mid-conversation.
class AiChatController extends ChangeNotifier {
  AiChatController({GeminiService? gemini}) : _gemini = gemini ?? GeminiService() {
    _suggestions = _pickQuestions();
  }

  final GeminiService _gemini;
  final _rng = Random();

  static const maxInputLength = 1000;
  static const _maxSessions = 30;

  static const _questionPool = [
    'What are the early signs of tooth decay?',
    'How often should I visit the dentist?',
    'How can I improve my gum health?',
    'What causes tooth sensitivity?',
    'Are my wisdom teeth a concern?',
    'How do I prevent cavities?',
    'What is a root canal procedure?',
    'Is teeth whitening safe?',
    'What should I do after a tooth extraction?',
    'How do I know if I have gum disease?',
    'What is the best way to brush my teeth?',
    'Why do my gums bleed when I floss?',
  ];

  List<String> _suggestions = const [];
  List<String> _lastSuggestions = const [];

  /// Personal suggestion built from the latest screening, set by the UI.
  ChatSuggestion? personalSuggestion;

  List<ChatSuggestion> get suggestions => [
        if (personalSuggestion != null) personalSuggestion!,
        for (final q in _suggestions) ChatSuggestion(q),
      ];

  List<String> _pickQuestions() {
    final pool =
        _questionPool.where((q) => !_lastSuggestions.contains(q)).toList();
    final source = pool.length >= 4 ? pool : List<String>.from(_questionPool);
    source.shuffle(_rng);
    return source.take(4).toList();
  }

  // ── State ───────────────────────────────────────────────────────────────

  /// Messages of the active chat. Empty means the welcome screen shows.
  final List<ChatMessage> messages = [];
  String _sessionId = _newId();

  /// Saved chats, newest first, including the active one once it has
  /// a question.
  final List<ChatSession> _sessions = [];

  /// Saved chats other than the active one.
  List<ChatSession> get history =>
      _sessions.where((s) => s.id != _sessionId).toList();

  bool isOpen = false;
  bool isMinimized = false;

  /// True while waiting for a reply.
  bool isLoading = false;

  ChatView view = ChatView.chat;
  ChatSession? selectedSession;

  String? _userId;

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
  static String _key(String userId) => 'ai_chat.sessions.v1.$userId';

  // ── Account ─────────────────────────────────────────────────────────────

  /// Loads the chats of [userId]. A different user never sees the
  /// previous user's conversation.
  Future<void> bindUser(String userId) async {
    if (userId == _userId) return;
    _userId = userId;
    _resetActive();
    _sessions.clear();
    view = ChatView.chat;
    selectedSession = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      if (raw == null || userId != _userId) return;
      for (final e in jsonDecode(raw) as List<dynamic>) {
        try {
          _sessions.add(ChatSession.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // Skip a damaged record rather than losing all history.
        }
      }
      _sessions.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    } catch (_) {
      // History is a convenience; chatting still works without it.
    }
    notifyListeners();
  }

  /// Removes [userId]'s saved chats from this device, e.g. when the
  /// account is deleted.
  static Future<void> deleteStoredHistory(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId));
  }

  // ── Panel ───────────────────────────────────────────────────────────────

  void open() {
    isOpen = true;
    isMinimized = false;
    notifyListeners();
  }

  void minimize() {
    isMinimized = true;
    notifyListeners();
  }

  void expand() {
    isMinimized = false;
    notifyListeners();
  }

  void close() {
    isOpen = false;
    isMinimized = false;
    view = ChatView.chat;
    selectedSession = null;
    notifyListeners();
  }

  void showHistory() {
    view = ChatView.history;
    selectedSession = null;
    notifyListeners();
  }

  void showChat() {
    view = ChatView.chat;
    selectedSession = null;
    notifyListeners();
  }

  void selectSession(ChatSession session) {
    selectedSession = session;
    view = ChatView.session;
    notifyListeners();
  }

  // ── Chat ────────────────────────────────────────────────────────────────

  /// Sends [text]. Pass [prompt] to send something richer to the model
  /// than what is shown in the bubble.
  Future<void> sendMessage(String text, {String? prompt}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isLoading) return;
    final clipped = trimmed.length > maxInputLength
        ? trimmed.substring(0, maxInputLength)
        : trimmed;

    view = ChatView.chat;
    selectedSession = null;
    messages.add(ChatMessage(
      text: clipped,
      isUser: true,
      sentAt: DateTime.now(),
      prompt: prompt,
    ));
    await _requestReply();
  }

  /// Retries the last question after an error.
  Future<void> retry() async {
    if (isLoading || messages.isEmpty || !messages.last.isError) return;
    messages.removeLast();
    await _requestReply();
  }

  Future<void> _requestReply() async {
    final question = messages.lastWhere((m) => m.isUser);
    final sessionId = _sessionId;
    isLoading = true;
    notifyListeners();

    ChatMessage reply;
    try {
      final text = await _gemini.chat(question.modelText);
      reply = ChatMessage(text: text, isUser: false, sentAt: DateTime.now());
    } on GeminiException catch (e) {
      reply = ChatMessage(
        text: e.message,
        isUser: false,
        isError: true,
        sentAt: DateTime.now(),
      );
    } catch (_) {
      reply = ChatMessage(
        text: 'Something went wrong. Please try again.',
        isUser: false,
        isError: true,
        sentAt: DateTime.now(),
      );
    }

    // The user started a new chat while waiting; drop the stale reply.
    if (sessionId != _sessionId) return;
    messages.add(reply);
    isLoading = false;
    _saveActive();
    notifyListeners();
  }

  /// Starts a fresh chat. The current one stays in history.
  void newChat() {
    if (isLoading) return;
    _resetActive();
    view = ChatView.chat;
    selectedSession = null;
    _lastSuggestions = List.unmodifiable(_suggestions);
    _suggestions = _pickQuestions();
    notifyListeners();
  }

  /// Makes a saved chat the active one, with its context restored.
  void continueSession(ChatSession session) {
    if (isLoading) return;
    _sessionId = session.id;
    messages
      ..clear()
      ..addAll(session.messages);
    _gemini.restoreSession(_contextTurns(session.messages));
    view = ChatView.chat;
    selectedSession = null;
    notifyListeners();
  }

  void deleteSession(String id) {
    _sessions.removeWhere((s) => s.id == id);
    if (selectedSession?.id == id) {
      selectedSession = null;
      view = ChatView.history;
    }
    _persist();
    notifyListeners();
  }

  /// Deletes all saved chats, including the active one.
  void clearHistory() {
    _sessions.clear();
    if (!isLoading) _resetActive();
    view = ChatView.chat;
    selectedSession = null;
    _persist();
    notifyListeners();
  }

  @override
  void dispose() {
    _gemini.close();
    super.dispose();
  }

  // ── Internals ───────────────────────────────────────────────────────────

  void _resetActive() {
    messages.clear();
    _sessionId = _newId();
    isLoading = false;
    _gemini.resetSession();
  }

  /// Answered turns only: failed questions and error notices are left
  /// out so the model sees a clean alternating conversation.
  static Iterable<(bool, String)> _contextTurns(List<ChatMessage> all) sync* {
    for (var i = 0; i < all.length; i++) {
      final m = all[i];
      if (m.isError) continue;
      if (m.isUser) {
        final next = i + 1 < all.length ? all[i + 1] : null;
        if (next == null || next.isUser || next.isError) continue;
      }
      yield (m.isUser, m.modelText);
    }
  }

  void _saveActive() {
    if (!messages.any((m) => m.isUser)) return;
    final session = ChatSession(
      id: _sessionId,
      title: messages.firstWhere((m) => m.isUser).text,
      messages: List.unmodifiable(messages),
      savedAt: DateTime.now(),
    );
    _sessions
      ..removeWhere((s) => s.id == _sessionId)
      ..insert(0, session);
    if (_sessions.length > _maxSessions) {
      _sessions.removeRange(_maxSessions, _sessions.length);
    }
    _persist();
  }

  Future<void> _persist() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key(userId),
        jsonEncode(_sessions.map((s) => s.toJson()).toList()),
      );
    } catch (_) {
      // Best-effort; the chat itself is unaffected.
    }
  }
}

/// Passes [AiChatController] down the widget tree.
class AiChatScope extends InheritedNotifier<AiChatController> {
  const AiChatScope({
    super.key,
    required AiChatController controller,
    required super.child,
  }) : super(notifier: controller);

  static AiChatController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AiChatScope>();
    assert(scope != null, 'No AiChatScope found in widget tree');
    return scope!.notifier!;
  }

  /// For callbacks: reads the controller without subscribing to changes.
  static AiChatController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AiChatScope>();
    assert(scope != null, 'No AiChatScope found in widget tree');
    return scope!.notifier!;
  }
}
