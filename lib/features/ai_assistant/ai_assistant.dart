import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'ai_chat_controller.dart';

/// Floating chat panel that overlays the entire app shell.
/// Renders nothing when [AiChatController.isOpen] is false.
/// Collapses to a pill when [AiChatController.isMinimized] is true.
class AiChatOverlay extends StatefulWidget {
  const AiChatOverlay({super.key});

  @override
  State<AiChatOverlay> createState() => _AiChatOverlayState();
}

class _AiChatOverlayState extends State<AiChatOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final AnimationController _anim;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  // Draggable position of the minimized pill (bottom-right by default)
  Offset _pillOffset = const Offset(double.infinity, double.infinity);
  bool _pillOffsetInitialized = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _scale = CurvedAnimation(parent: _anim, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _anim.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(AiChatController ctrl) {
    if (ctrl.isLoading || _input.text.trim().isEmpty) return;
    ctrl.sendMessage(_input.text);
    _input.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = AiChatScope.of(context);

    if (!ctrl.isOpen) return const SizedBox.shrink();

    // Drive animation
    if (ctrl.isMinimized) {
      _anim.reverse();
    } else {
      _anim.forward();
    }

    final size = MediaQuery.of(context).size;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Default pill position: bottom-right, above bottom nav (~80px)
    if (!_pillOffsetInitialized) {
      _pillOffset = Offset(size.width - 164, size.height - 180);
      _pillOffsetInitialized = true;
    }

    return Stack(
      children: [
        // ── Expanded panel ──────────────────────────────────────
        if (!ctrl.isMinimized)
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomInset,
            top: 0,
            child: _buildExpandedPanel(ctrl, size),
          ),

        // ── Minimized pill ──────────────────────────────────────
        if (ctrl.isMinimized)
          Positioned(
            left: _pillOffset.dx,
            top: _pillOffset.dy,
            child: _buildMinimizedPill(ctrl),
          ),
      ],
    );
  }

  Widget _buildExpandedPanel(AiChatController ctrl, Size size) {
    return FadeTransition(
      opacity: _fade,
      child: Column(
        children: [
          // Scrim — tap to minimize
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: ctrl.minimize,
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),

          // Chat panel
          ScaleTransition(
            scale: _scale,
            alignment: Alignment.bottomCenter,
            child: Container(
              height: size.height * 0.62,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 24,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildHeader(ctrl),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  // ── Body: switches between chat, history list, session detail
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: ctrl.selectedSession != null
                          ? _SessionDetailView(
                              key: ValueKey(ctrl.selectedSession!.savedAt),
                              session: ctrl.selectedSession!,
                              onBack: ctrl.deselectSession,
                            )
                          : ctrl.isShowingHistory
                              ? _HistoryListView(
                                  key: const ValueKey('history'),
                                  ctrl: ctrl,
                                )
                              : _buildMessageList(ctrl),
                    ),
                  ),
                  // Input bar hidden when browsing history
                  if (!ctrl.isShowingHistory && ctrl.selectedSession == null)
                    _buildInputBar(ctrl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────

  Widget _buildHeader(AiChatController ctrl) {
    // Determine what secondary action to show in the left area.
    final bool inHistory =
        ctrl.isShowingHistory || ctrl.selectedSession != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
      child: Row(
        children: [
          // Back button when in history, icon when in chat
          if (inHistory)
            _HeaderIconButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: 'Back to chat',
              onTap: ctrl.selectedSession != null
                  ? ctrl.deselectSession
                  : ctrl.hideHistory,
            )
          else
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: Colors.white),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  inHistory
                      ? (ctrl.selectedSession != null
                          ? 'Session detail'
                          : 'Chat history')
                      : 'DENTRA AI',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  inHistory
                      ? (ctrl.selectedSession != null
                          ? _formatDate(ctrl.selectedSession!.savedAt)
                          : '${ctrl.chatHistory.length} saved session${ctrl.chatHistory.length == 1 ? '' : 's'}')
                      : 'Dental care assistant',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          // History toggle — only visible on the active chat view
          if (!inHistory) ...[
            _HeaderIconButton(
              icon: Icons.history_rounded,
              tooltip: 'Chat history',
              onTap: ctrl.showHistory,
            ),
            const SizedBox(width: 4),
            // New chat (save current + clear)
            _HeaderIconButton(
              icon: Icons.edit_note_rounded,
              tooltip: 'New chat',
              onTap: ctrl.clearChat,
            ),
            const SizedBox(width: 4),
          ],
          // Minimize
          _HeaderIconButton(
            icon: Icons.remove_rounded,
            tooltip: 'Minimize',
            onTap: ctrl.minimize,
          ),
          const SizedBox(width: 4),
          // Close
          _HeaderIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onTap: ctrl.close,
          ),
        ],
      ),
    );
  }

  // ── Active chat message list ────────────────────────────────────

  Widget _buildMessageList(AiChatController ctrl) {
    _scrollToBottom();
    // Show only the greeting + no user messages yet → show suggested questions
    final hasUserMessages = ctrl.messages.any((m) => m.isUser);
    final itemCount = ctrl.messages.length + (ctrl.isLoading ? 1 : 0);
    return ListView.builder(
      key: const ValueKey('chat'),
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: itemCount + (!hasUserMessages && !ctrl.isLoading ? 1 : 0),
      itemBuilder: (context, i) {
        // Insert suggested questions after the greeting bubble
        if (!hasUserMessages && !ctrl.isLoading && i == 1) {
          return _SuggestedQuestions(
            questions: ctrl.suggestedQuestions,
            onTap: (q) {
              _input.clear();
              ctrl.sendMessage(q);
              _scrollToBottom();
            },
          );
        }
        // Offset index when the suggestions row is injected
        final msgIndex = (!hasUserMessages && !ctrl.isLoading && i > 1) ? i - 1 : i;
        if (msgIndex == ctrl.messages.length && ctrl.isLoading) {
          return const _TypingIndicator();
        }
        return _MessageBubble(message: ctrl.messages[msgIndex]);
      },
    );
  }

  // ── Input bar ───────────────────────────────────────────────────

  Widget _buildInputBar(AiChatController ctrl) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF4F5FF),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _input,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(ctrl),
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.navy,
                ),
                decoration: InputDecoration(
                  hintText: 'Ask something…',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 12),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: ctrl.isLoading ? null : () => _send(ctrl),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: ctrl.isLoading ? null : AppColors.primaryGradient,
                color: ctrl.isLoading ? const Color(0xFFDDDDDD) : null,
                borderRadius: BorderRadius.circular(22),
              ),
              child: ctrl.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ── Minimized pill ──────────────────────────────────────────────

  Widget _buildMinimizedPill(AiChatController ctrl) {
    return Draggable(
      feedback: _PillWidget(onTap: ctrl.expand),
      childWhenDragging: const SizedBox.shrink(),
      onDragEnd: (details) {
        setState(() => _pillOffset = details.offset);
      },
      child: _PillWidget(onTap: ctrl.expand),
    );
  }
}

// ── Suggested / predefined questions ─────────────────────────────

class _SuggestedQuestions extends StatelessWidget {
  final List<String> questions;
  final void Function(String question) onTap;
  const _SuggestedQuestions({required this.questions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              'Commonly asked questions',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: questions
                .map((q) => _QuestionChip(label: q, onTap: () => onTap(q)))
                .toList(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _QuestionChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _QuestionChip({required this.label, required this.onTap});

  @override
  State<_QuestionChip> createState() => _QuestionChipState();
}

class _QuestionChipState extends State<_QuestionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _pressed ? AppColors.lightLavender : Colors.white,
          border: Border.all(
            color: _pressed
                ? AppColors.primary
                : const Color(0xFFDDE0F5),
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _pressed
              ? []
              : [
                  const BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
        ),
        child: Text(
          widget.label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _pressed ? AppColors.primary : AppColors.navy,
          ),
        ),
      ),
    );
  }
}

// ── History list view ─────────────────────────────────────────────

class _HistoryListView extends StatelessWidget {
  final AiChatController ctrl;
  const _HistoryListView({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    if (ctrl.chatHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded,
                size: 44, color: AppColors.secondaryText.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              'No history yet',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start a chat and your sessions\nwill appear here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.secondaryText.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: ctrl.chatHistory.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
      itemBuilder: (context, i) {
        final session = ctrl.chatHistory[i];
        final userCount =
            session.messages.where((m) => m.isUser).length;
        return _SessionTile(
          session: session,
          userCount: userCount,
          onTap: () => ctrl.selectSession(session),
        );
      },
    );
  }
}

// ── Individual session tile ───────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final int userCount;
  final VoidCallback onTap;
  const _SessionTile({
    required this.session,
    required this.userCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.lightLavender,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded,
                  size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$userCount question${userCount == 1 ? '' : 's'} · ${_formatDate(session.savedAt)}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.secondaryText),
          ],
        ),
      ),
    );
  }
}

// ── Session detail view ───────────────────────────────────────────

class _SessionDetailView extends StatelessWidget {
  final ChatSession session;
  final VoidCallback onBack;
  const _SessionDetailView({
    super.key,
    required this.session,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: session.messages.length,
      itemBuilder: (context, i) {
        return _MessageBubble(message: session.messages[i]);
      },
    );
  }
}

// ── Shared date formatter ─────────────────────────────────────────

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(dt.year, dt.month, dt.day);

  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff < 7) return '$diff days ago';

  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

// ── Pill shown when minimized ─────────────────────────────────────

class _PillWidget extends StatelessWidget {
  final VoidCallback onTap;
  const _PillWidget({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x334DD8C8),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_awesome_rounded,
                size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              'DENTRA AI',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header icon button ────────────────────────────────────────────

class _HeaderIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _HeaderIconButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppColors.lightLavender
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(widget.icon,
                size: 18, color: AppColors.secondaryText),
          ),
        ),
      ),
    );
  }
}

// ── Typing indicator (three bouncing dots) ────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) {
                final phase = (_ctrl.value - i * 0.3).clamp(0.0, 1.0);
                final bounce =
                    (phase < 0.5) ? phase * 2 : (1 - phase) * 2;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 7,
                  height: 7 + bounce * 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary
                        .withValues(alpha: 0.55 + bounce * 0.45),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

// ── Message bubble ────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: isUser ? AppColors.primaryGradient : null,
          color: isUser ? null : const Color(0xFFF4F5FF),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.outfit(
            fontSize: 13,
            color: isUser ? Colors.white : AppColors.navy,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
