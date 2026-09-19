import 'dart:math';

import 'package:flutter/widgets.dart';
import '../../core/services/gemini_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  const ChatMessage({required this.text, required this.isUser});
}

/// A saved snapshot of one complete chat session.
class ChatSession {
  /// The first user question, used as the session title in the history list.
  final String title;

  /// Full message list for this session (excluding the greeting).
  final List<ChatMessage> messages;

  /// When this session was saved.
  final DateTime savedAt;

  const ChatSession({
    required this.title,
    required this.messages,
    required this.savedAt,
  });
}

/// Holds all AI chat state and is shared across the entire app shell.
/// Attach one instance to AppShell and pass it down via InheritedWidget.
class AiChatController extends ChangeNotifier {
  final _gemini = GeminiService();
  final _rng = Random();

  static const _greeting = ChatMessage(
    text:
        "Hi! I'm your DENTRA AI assistant. Ask me anything about your oral health, screening results, or dental care tips.",
    isUser: false,
  );

  /// Full pool of predefined questions to draw from.
  static const _questionPool = [
    'What are the early signs of tooth decay?',
    'How often should I visit the dentist?',
    'What does my screening score mean?',
    'How can I improve my gum health?',
    'What causes tooth sensitivity?',
    'Are my wisdom teeth a concern?',
    'How do I prevent cavities?',
    'What is a root canal procedure?',
    'Is teeth whitening safe?',
    'What should I do after a tooth extraction?',
    'How do I know if I have gum disease?',
    'What is the best way to brush my teeth?',
  ];

  /// The 4 questions shown in the current session.
  late List<String> suggestedQuestions;

  /// Questions shown in the previous session — used to avoid repeats.
  List<String> _lastSuggestedQuestions = [];

  /// Picks 4 questions that don't overlap with [_lastSuggestedQuestions].
  List<String> _pickQuestions() {
    final pool = _questionPool
        .where((q) => !_lastSuggestedQuestions.contains(q))
        .toList();
    // If the pool is somehow smaller than 4 (shouldn't happen), fall back to full pool.
    final source = pool.length >= 4 ? pool : List<String>.from(_questionPool);
    source.shuffle(_rng);
    return source.take(4).toList();
  }

  AiChatController() {
    suggestedQuestions = _pickQuestions();
  }

  final List<ChatMessage> messages = [_greeting];

  /// All previous sessions, newest first.
  final List<ChatSession> chatHistory = [];

  /// Whether the chat panel is visible at all.
  bool isOpen = false;

  /// When true the panel collapses to a small floating pill.
  bool isMinimized = false;

  /// True while waiting for a Gemini response.
  bool isLoading = false;

  /// True when the history list is being shown instead of the active chat.
  bool isShowingHistory = false;

  /// When non-null, shows the detail view for this past session.
  ChatSession? selectedSession;

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
    // Save the current session before closing if it has real messages.
    _saveCurrentSession();
    isOpen = false;
    isMinimized = false;
    isShowingHistory = false;
    selectedSession = null;
    notifyListeners();
  }

  void showHistory() {
    isShowingHistory = true;
    selectedSession = null;
    notifyListeners();
  }

  void hideHistory() {
    isShowingHistory = false;
    selectedSession = null;
    notifyListeners();
  }

  void selectSession(ChatSession session) {
    selectedSession = session;
    notifyListeners();
  }

  void deselectSession() {
    selectedSession = null;
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isLoading) return;

    // If we were in the history view, go back to active chat first.
    if (isShowingHistory) {
      isShowingHistory = false;
      selectedSession = null;
    }

    // Add user message and show loading state.
    messages.add(ChatMessage(text: trimmed, isUser: true));
    isLoading = true;
    notifyListeners();

    try {
      final reply = await _gemini.chat(trimmed);
      messages.add(ChatMessage(text: reply, isUser: false));
    } on GeminiException catch (e) {
      messages.add(ChatMessage(text: e.message, isUser: false));
    } catch (_) {
      messages.add(const ChatMessage(
        text:
            'Something went wrong. Please check your connection and try again.',
        isUser: false,
      ));
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Saves the current active session (if it contains user messages) to
  /// [chatHistory], then starts a fresh session.
  void clearChat() {
    _saveCurrentSession();
    messages
      ..clear()
      ..add(_greeting);
    isShowingHistory = false;
    selectedSession = null;
    _gemini.resetSession();
    // Rotate suggested questions — exclude the ones just shown.
    _lastSuggestedQuestions = List.unmodifiable(suggestedQuestions);
    suggestedQuestions = _pickQuestions();
    notifyListeners();
  }

  /// Saves current session to history if it has at least one user message.
  void _saveCurrentSession() {
    final userMessages = messages.where((m) => m.isUser).toList();
    if (userMessages.isEmpty) return;

    // Use the first user question as the session title.
    final title = userMessages.first.text;

    chatHistory.insert(
      0,
      ChatSession(
        title: title,
        messages: List.unmodifiable(messages),
        savedAt: DateTime.now(),
      ),
    );
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
    final scope =
        context.dependOnInheritedWidgetOfExactType<AiChatScope>();
    assert(scope != null, 'No AiChatScope found in widget tree');
    return scope!.notifier!;
  }
}
