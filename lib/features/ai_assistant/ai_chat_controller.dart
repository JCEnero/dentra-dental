import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../core/services/gemini_service.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  const ChatMessage({required this.text, required this.isUser});
}

/// Holds all AI chat state and is shared across the entire app shell.
/// Attach one instance to AppShell and pass it down via InheritedWidget.
class AiChatController extends ChangeNotifier {
  final _gemini = GeminiService();

  final List<ChatMessage> messages = [
    const ChatMessage(
      text:
          "Hi! I'm your DENTRA AI assistant. Ask me anything about your oral health, screening results, or dental care tips.",
      isUser: false,
    ),
  ];

  /// Whether the chat panel is visible at all.
  bool isOpen = false;

  /// When true the panel collapses to a small floating pill.
  bool isMinimized = false;

  /// True while waiting for a Gemini response.
  bool isLoading = false;

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
    notifyListeners();
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || isLoading) return;

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

  /// Clears message history and resets the Gemini chat session.
  void clearChat() {
    messages
      ..clear()
      ..add(const ChatMessage(
        text:
            "Hi! I'm your DENTRA AI assistant. Ask me anything about your oral health, screening results, or dental care tips.",
        isUser: false,
      ));
    _gemini.resetSession();
    notifyListeners();
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
