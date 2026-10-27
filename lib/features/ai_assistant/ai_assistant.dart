import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_glass.dart';
import '../../core/utils/dentra_dates.dart';
import '../../shared/widgets/dentra_glass_ui.dart';
import '../../shared/widgets/glass_card.dart';
import '../auth/providers/auth_provider.dart';
import '../profile/providers/profile_provider.dart';
import '../scan/data/scan_regions.dart';
import '../screening/data/models/screening_session.dart';
import '../screening/providers/screening_sessions_provider.dart';
import 'ai_chat_controller.dart';
import 'rabi_service.dart';

/// Rabi, the in-app dental assistant.
///
/// A frosted-glass panel over the whole app shell. Minimizes to a
/// draggable pill so a conversation can continue while browsing.
class AiChatOverlay extends ConsumerStatefulWidget {
  const AiChatOverlay({super.key});

  @override
  ConsumerState<AiChatOverlay> createState() => _AiChatOverlayState();
}

class _AiChatOverlayState extends ConsumerState<AiChatOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _panel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    reverseDuration: const Duration(milliseconds: 220),
  );

  AiChatController? _ctrl;
  Offset? _pillOffset;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ctrl = AiChatScope.of(context);
    if (_ctrl == null) {
      // Each account gets its own chat history.
      ref.listenManual<String?>(
        authServiceProvider.select((a) => a.currentUserId),
        // Deferred: the first call happens during build, where the
        // controller must not notify listeners.
        (_, userId) => Future.microtask(() {
          // Signed in with the backend: Rabi answers through the DENTRA
          // API, so the Gemini key never ships in the app.
          final api = ref.read(apiClientProvider);
          return ctrl.bindUser(
            userId ?? 'guest',
            rabi: api == null ? null : ApiRabiService(api),
          );
        }),
        fireImmediately: true,
      );
    }
    _ctrl = ctrl;
    final showPanel = ctrl.isOpen && !ctrl.isMinimized;
    if (MediaQuery.disableAnimationsOf(context)) {
      _panel.value = showPanel ? 1 : 0;
    } else if (showPanel) {
      _panel.forward();
    } else {
      _panel.reverse();
    }
  }

  @override
  void dispose() {
    _panel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl!;
    ctrl.personalSuggestion = _screeningSuggestion(
      ref.watch(screeningSessionsProvider).valueOrNull?.firstOrNull,
    );
    final firstName = ref.watch(profileProvider).valueOrNull?.firstName ?? '';

    return AnimatedBuilder(
      animation: _panel,
      builder: (context, _) {
        final t = _panel.value;
        final curved = Curves.easeOutCubic.transform(t);
        return Stack(
          children: [
            if (t > 0) ...[
              // Scrim: tap to minimize.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: ctrl.minimize,
                  child: ColoredBox(
                    color: AppColors.navy.withValues(alpha: 0.32 * curved),
                  ),
                ),
              ),
              Positioned.fill(
                child: FractionalTranslation(
                  translation: Offset(0, 1 - curved),
                  child: _ChatPanel(ctrl: ctrl, firstName: firstName),
                ),
              ),
            ],
            if (ctrl.isOpen && ctrl.isMinimized) _buildPill(ctrl),
          ],
        );
      },
    );
  }

  Widget _buildPill(AiChatController ctrl) {
    final media = MediaQuery.of(context);
    const pillSize = Size(132, 48);
    final maxX = media.size.width - pillSize.width - 12;
    final maxY =
        media.size.height - pillSize.height - media.padding.bottom - 96;
    final offset = _pillOffset ?? Offset(maxX, maxY);
    Offset clamp(Offset o) => Offset(
          o.dx.clamp(12, maxX),
          o.dy.clamp(media.padding.top + 12, maxY),
        );
    final position = clamp(offset);

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onPanUpdate: (d) =>
            setState(() => _pillOffset = clamp(position + d.delta)),
        child: _MinimizedPill(loading: ctrl.isLoading, onTap: ctrl.expand),
      ),
    );
  }

  /// Offers to explain the latest screening, with its data attached to the
  /// question so the answer is about this user, not screenings in general.
  static ChatSuggestion? _screeningSuggestion(ScreeningSession? s) {
    if (s == null) return null;
    final regions = [
      for (final id in s.capturedRegions)
        scanRegions.where((r) => r.id == id).firstOrNull?.label ?? id,
    ];
    final analysis = s.analysis;
    final prompt = StringBuffer()
      ..writeln('Here is my latest DENTRA screening:')
      ..writeln('- Date: ${DentraDates.medium(s.completedAt)}')
      ..writeln('- Status: ${s.status.label} '
          '(${s.capturedRegions.length} of ${s.totalRegions} regions captured)')
      ..writeln(
          '- Regions captured: ${regions.isEmpty ? 'none' : regions.join(', ')}')
      ..writeln(analysis == null
          ? '- Screening analysis: none available for this screening'
          : '- Screening analysis summary: ${analysis.summary}');
    if (analysis != null) {
      for (final f in analysis.findings) {
        prompt.writeln('- Finding: ${f.label}'
            '${f.detail != null ? ' (${f.detail})' : ''}');
      }
    }
    prompt.writeln(
        'Explain what this means in plain terms and what I should do next.');
    return ChatSuggestion(
      'Explain my latest screening',
      prompt: prompt.toString(),
      personal: true,
    );
  }
}

// ── Panel ─────────────────────────────────────────────────────────────────

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({required this.ctrl, required this.firstName});

  final AiChatController ctrl;
  final String firstName;

  static const _radius = BorderRadius.vertical(top: Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(
        top: media.padding.top + 12,
        bottom: media.viewInsets.bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Material(
            type: MaterialType.transparency,
            child: ClipRRect(
              borderRadius: _radius,
              child: GlassBlur(
                strong: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: _radius,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppGlass.floatHigh,
                        AppColors.lightLavender
                            .withValues(alpha: AppGlass.floatLow.a),
                      ],
                    ),
                    border: const Border(
                      top: BorderSide(color: AppGlass.border, width: 1.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag the handle down to minimize.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragEnd: (d) {
                          if ((d.primaryVelocity ?? 0) > 250) ctrl.minimize();
                        },
                        child: Column(
                          children: [
                            Center(
                              child: Container(
                                margin: const EdgeInsets.only(top: 10),
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.navy.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                            _Header(ctrl: ctrl),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, color: AppGlass.divider),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: dentraMotion(context, 200),
                          child: switch (ctrl.view) {
                            ChatView.chat => _ChatBody(
                                key: const ValueKey('chat'),
                                ctrl: ctrl,
                                firstName: firstName,
                              ),
                            ChatView.history => _HistoryView(
                                key: const ValueKey('history'),
                                ctrl: ctrl,
                              ),
                            ChatView.session => _SessionView(
                                key: ValueKey(ctrl.selectedSession?.id),
                                ctrl: ctrl,
                              ),
                          },
                        ),
                      ),
                      if (ctrl.view == ChatView.chat) _InputBar(ctrl: ctrl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.ctrl});

  final AiChatController ctrl;

  @override
  Widget build(BuildContext context) {
    final session = ctrl.selectedSession;

    final (Widget leading, String title, String subtitle) = switch (ctrl.view) {
      ChatView.chat => (
          const _RabiAvatar(size: 40),
          'Rabi',
          ctrl.isLoading ? 'Typing…' : 'Your dental care assistant',
        ),
      ChatView.history => (
          _HeaderButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back to chat',
            onPressed: ctrl.showChat,
          ),
          'Chat history',
          '${ctrl.history.length} saved chat${ctrl.history.length == 1 ? '' : 's'}',
        ),
      ChatView.session => (
          _HeaderButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back to history',
            onPressed: ctrl.showHistory,
          ),
          session?.title ?? '',
          session == null ? '' : _dateTime(session.savedAt),
        ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 12),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: dentraMotion(context, 160),
                  child: Text(
                    subtitle,
                    key: ValueKey(subtitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: ctrl.isLoading && ctrl.view == ChatView.chat
                          ? AppColors.g2
                          : AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ..._actions(context),
        ],
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    switch (ctrl.view) {
      case ChatView.chat:
        return [
          _HeaderButton(
            icon: Icons.history_rounded,
            tooltip: 'Chat history',
            onPressed: ctrl.showHistory,
          ),
          _HeaderButton(
            icon: Icons.add_comment_outlined,
            tooltip: 'New chat',
            onPressed:
                ctrl.messages.isEmpty || ctrl.isLoading ? null : ctrl.newChat,
          ),
          _HeaderButton(
            icon: Icons.keyboard_arrow_down_rounded,
            tooltip: 'Minimize',
            onPressed: ctrl.minimize,
          ),
          _HeaderButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onPressed: ctrl.close,
          ),
        ];
      case ChatView.history:
        return [
          _HeaderButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: 'Delete all chats',
            onPressed: ctrl.history.isEmpty
                ? null
                : () async {
                    final ok = await showGlassConfirmDialog(
                      context: context,
                      icon: Icons.delete_sweep_outlined,
                      title: 'Delete all chats?',
                      message: 'Every saved conversation with Rabi on this '
                          "device will be removed. This can't be undone.",
                      confirmLabel: 'Delete all',
                      destructive: true,
                    );
                    if (ok) ctrl.clearHistory();
                  },
          ),
        ];
      case ChatView.session:
        final session = ctrl.selectedSession;
        return [
          _HeaderButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete chat',
            onPressed: session == null
                ? null
                : () async {
                    if (await _confirmDeleteChat(context)) {
                      ctrl.deleteSession(session.id);
                    }
                  },
          ),
        ];
    }
  }
}

/// Asks before a single saved chat is deleted.
Future<bool> _confirmDeleteChat(BuildContext context) => showGlassConfirmDialog(
      context: context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete this chat?',
      message: "This conversation with Rabi will be removed. This can't be "
          'undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        foregroundColor: AppColors.navy,
        disabledForegroundColor: AppColors.navy.withValues(alpha: 0.25),
        highlightColor: AppColors.lightLavender,
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icon, size: 21),
    );
  }
}

/// Rabi's mark: the bunny logo.
class _RabiAvatar extends StatelessWidget {
  const _RabiAvatar({this.size = 32});

  final double size;

  static const String asset = 'assets/images/rabi_avatar.png';

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(asset, fit: BoxFit.contain),
      ),
    );
  }
}

// ── Chat ──────────────────────────────────────────────────────────────────

class _ChatBody extends StatefulWidget {
  const _ChatBody({super.key, required this.ctrl, required this.firstName});

  final AiChatController ctrl;
  final String firstName;

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> {
  final ScrollController _scroll = ScrollController();
  bool _showJump = false;

  @override
  void initState() {
    super.initState();
    // The list is reversed, so offset 0 is the newest message.
    _scroll.addListener(() {
      final show = _scroll.hasClients && _scroll.offset > 240;
      if (show != _showJump) setState(() => _showJump = show);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpToLatest() {
    _scroll.animateTo(
      0,
      duration: dentraMotion(context, 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    if (ctrl.messages.isEmpty && !ctrl.isLoading) {
      return _Welcome(ctrl: ctrl, firstName: widget.firstName);
    }

    final messages = ctrl.messages;
    final extra = ctrl.isLoading ? 1 : 0;
    return Stack(
      children: [
        ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          itemCount: messages.length + extra,
          itemBuilder: (context, i) {
            if (ctrl.isLoading && i == 0) {
              final partial = ctrl.streamingText;
              if (partial == null) return const _TypingBubble();
              // The reply as it streams in; replaced by the saved message.
              return _MessageTile(
                message: ChatMessage(
                  text: partial,
                  isUser: false,
                  sentAt: DateTime.now(),
                ),
                streaming: true,
              );
            }
            final index = messages.length - 1 - (i - extra);
            final m = messages[index];
            final isLast = index == messages.length - 1;
            return _MessageTile(
              key: ValueKey('${m.sentAt.microsecondsSinceEpoch}-${m.isUser}'),
              message: m,
              onRetry:
                  m.isError && isLast && !ctrl.isLoading ? ctrl.retry : null,
            );
          },
        ),
        Positioned(
          right: 16,
          bottom: 12,
          child: IgnorePointer(
            ignoring: !_showJump,
            child: AnimatedScale(
              scale: _showJump ? 1 : 0,
              duration: dentraMotion(context, 180),
              child: _GlassCircleButton(
                icon: Icons.arrow_downward_rounded,
                tooltip: 'Jump to latest',
                onPressed: _jumpToLatest,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.ctrl, required this.firstName});

  final AiChatController ctrl;
  final String firstName;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        const Center(child: _RabiAvatar(size: 96)),
        const SizedBox(height: 18),
        Text(
          firstName.isEmpty ? "Hi, I'm Rabi" : "Hi $firstName, I'm Rabi",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.navy,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Ask me about oral health, your screening results or a treatment.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 14,
            color: AppColors.secondaryText,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'TRY ASKING',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.secondaryText,
            ),
          ),
        ),
        for (final s in ctrl.suggestions) ...[
          _SuggestionTile(
            suggestion: s,
            onTap: () => ctrl.sendMessage(s.label, prompt: s.prompt),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.suggestion, required this.onTap});

  final ChatSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final personal = suggestion.personal;
    return GlassCard(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      borderColor: personal ? AppColors.g2.withValues(alpha: 0.35) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Icon(
              personal
                  ? Icons.auto_awesome_rounded
                  : Icons.chat_bubble_outline_rounded,
              size: 18,
              color: AppColors.g2,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.label,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: personal ? FontWeight.w700 : FontWeight.w500,
                      color: AppColors.navy,
                      height: 1.35,
                    ),
                  ),
                  if (personal)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Uses your most recent scan',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.north_east_rounded,
              size: 16,
              color: AppColors.navy.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Messages ──────────────────────────────────────────────────────────────

class _MessageTile extends StatelessWidget {
  const _MessageTile({
    super.key,
    required this.message,
    this.onRetry,
    this.streaming = false,
  });

  final ChatMessage message;

  /// Shown on the latest error notice.
  final VoidCallback? onRetry;

  /// A reply still arriving: no time or copy button yet.
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onLongPress: () => _copy(context, message.text),
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.cardSolid, AppColors.g2],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Text(
                  message.text,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    color: AppColors.white,
                    height: 1.45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _Meta(text: DentraDates.time(message.sentAt)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: _RabiAvatar(size: 28),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                message.isError
                    ? _ErrorBubble(
                        message: message.text,
                        maxWidth: maxWidth,
                        onRetry: onRetry,
                      )
                    : GestureDetector(
                        onLongPress: () => _copy(context, message.text),
                        child: Container(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.62),
                            border: Border.all(color: AppGlass.border),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              topRight: Radius.circular(20),
                              bottomLeft: Radius.circular(20),
                              bottomRight: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.navy.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: _RichReply(text: message.text),
                        ),
                      ),
                const SizedBox(height: 2),
                // Wraps instead of overflowing at very large text sizes.
                if (!streaming)
                  Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    _Meta(text: DentraDates.time(message.sentAt)),
                    if (!message.isError) _CopyButton(text: message.text),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

void _copy(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: _plain(text)));
  HapticFeedback.selectionClick();
  showDentraSnack(context, 'Copied to clipboard.');
}

/// Strips the light markdown Rabi uses, for copying.
String _plain(String text) => text
    .replaceAll('**', '')
    .replaceAll(RegExp(r'^\s*[*-]\s+', multiLine: true), '• ');

class _Meta extends StatelessWidget {
  const _Meta({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 11,
          color: AppColors.secondaryText.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _plain(widget.text)));
    if (!mounted) return;
    setState(() => _copied = true);
    _reset?.cancel();
    _reset = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: _copied,
      child: TextButton.icon(
        onPressed: _copy,
        style: TextButton.styleFrom(
          foregroundColor: _copied ? AppColors.g2 : AppColors.secondaryText,
          minimumSize: const Size(44, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: Icon(
          _copied ? Icons.check_rounded : Icons.content_copy_rounded,
          size: 14,
        ),
        label: Text(_copied ? 'Copied' : 'Copy'),
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({
    required this.message,
    required this.maxWidth,
    required this.onRetry,
  });

  final String message;
  final double maxWidth;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.07),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.22)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: AppColors.navy,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(44, 40),
                    textStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Try again'),
                ),
              )
            else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

/// Renders Rabi's light markdown: paragraphs, `-`/`*` bullets, numbered
/// lists, `#` headings (as bold lines) and inline `**bold**`.
class _RichReply extends StatelessWidget {
  const _RichReply({required this.text});

  final String text;

  static final _bullet = RegExp(r'^\s*[-*•]\s+(.*)$');
  static final _numbered = RegExp(r'^\s*(\d+)[.)]\s+(.*)$');
  static final _heading = RegExp(r'^\s*#{1,6}\s+(.*)$');

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.outfit(
      fontSize: 15,
      color: AppColors.navy,
      height: 1.5,
    );
    final blocks = <Widget>[];
    var gap = false;

    void add(Widget w) {
      if (blocks.isNotEmpty) blocks.add(SizedBox(height: gap ? 10 : 4));
      blocks.add(w);
      gap = false;
    }

    for (final raw in text.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        gap = true;
        continue;
      }
      final bullet = _bullet.firstMatch(line);
      final numbered = _numbered.firstMatch(line);
      final heading = _heading.firstMatch(line);
      if (bullet != null) {
        add(_ListItem(marker: '•', text: bullet.group(1)!, style: base));
      } else if (numbered != null) {
        add(_ListItem(
          marker: '${numbered.group(1)}.',
          text: numbered.group(2)!,
          style: base,
        ));
      } else if (heading != null) {
        add(Text.rich(
          _inline(
              heading.group(1)!, base.copyWith(fontWeight: FontWeight.w700)),
        ));
      } else {
        add(Text.rich(_inline(line, base)));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  static TextSpan _inline(String text, TextStyle style) {
    final spans = <TextSpan>[];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      // Odd segments sit between ** pairs. An unmatched ** stays plain.
      final bold = i.isOdd && i < parts.length - 1;
      spans.add(TextSpan(
        text: parts[i].replaceAll('*', ''),
        style: bold ? style.copyWith(fontWeight: FontWeight.w700) : null,
      ));
    }
    return TextSpan(style: style, children: spans);
  }
}

class _ListItem extends StatelessWidget {
  const _ListItem({
    required this.marker,
    required this.text,
    required this.style,
  });

  final String marker;
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Text(
            marker,
            style: style.copyWith(
              color: AppColors.g2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Text.rich(_RichReply._inline(text, style))),
      ],
    );
  }
}

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rabi is typing',
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            const _RabiAvatar(size: 28),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.88),
                border: Border.all(color: AppGlass.border),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final phase = ((_ctrl.value - i * 0.18) % 1.0);
                      final lift = phase < 0.4
                          ? (phase < 0.2 ? phase : 0.4 - phase) * 5
                          : 0.0;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        transform: Matrix4.translationValues(0, -lift * 4, 0),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: AppColors.g2
                              .withValues(alpha: 0.45 + lift * 0.55),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Input ─────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  const _InputBar({required this.ctrl});

  final AiChatController ctrl;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final TextEditingController _input = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _input.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _canSend => _input.text.trim().isNotEmpty && !widget.ctrl.isLoading;

  void _send() {
    if (!_canSend) return;
    widget.ctrl.sendMessage(_input.text);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final length = _input.text.length;
    const max = AiChatController.maxInputLength;
    final keyboardOpen = media.viewInsets.bottom > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppGlass.barFill,
        border: Border(top: BorderSide(color: AppGlass.divider)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          12,
          (keyboardOpen ? 10 : media.padding.bottom + 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _focus.hasFocus
                            ? AppColors.g2.withValues(alpha: 0.45)
                            : AppColors.g2.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Focus(
                      onFocusChange: (_) => setState(() {}),
                      child: TextField(
                        controller: _input,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(max),
                        ],
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          color: AppColors.navy,
                          height: 1.4,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask Rabi about your teeth…',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 15,
                            color: AppColors.secondaryText,
                          ),
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.fromLTRB(18, 13, 18, 13),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _SendButton(
                  enabled: _canSend,
                  loading: widget.ctrl.isLoading,
                  onPressed: _send,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'General information only, not a diagnosis.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
                if (length > max - 200)
                  Text(
                    '$length/$max',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: length >= max
                          ? AppColors.danger
                          : AppColors.secondaryText,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: loading ? 'Waiting for Rabi' : 'Send message',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: dentraMotion(context, 160),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: enabled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.cardSolid, AppColors.g2],
                )
              : null,
          color: enabled ? null : AppColors.g2.withValues(alpha: 0.12),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppColors.g2.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            child: Center(
              child: loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.g2,
                      ),
                    )
                  : Icon(
                      Icons.arrow_upward_rounded,
                      size: 22,
                      color: enabled
                          ? AppColors.white
                          : AppColors.navy.withValues(alpha: 0.3),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── History ───────────────────────────────────────────────────────────────

class _HistoryView extends StatelessWidget {
  const _HistoryView({super.key, required this.ctrl});

  final AiChatController ctrl;

  @override
  Widget build(BuildContext context) {
    final sessions = ctrl.history;
    if (sessions.isEmpty) {
      return _CenteredMessage(
        icon: Icons.forum_outlined,
        title: 'No saved chats yet',
        message: 'Your conversations with Rabi are saved here so you can '
            'pick them up later.',
        action: DentraPillButton(
          label: 'Start a chat',
          icon: Icons.add_comment_outlined,
          onPressed: ctrl.showChat,
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final s = sessions[i];
        final preview = s.preview;
        return Dismissible(
          key: ValueKey('chat-${s.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDeleteChat(context),
          onDismissed: (_) => ctrl.deleteSession(s.id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 22),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.danger,
            ),
          ),
          child: Semantics(
            customSemanticsActions: {
              const CustomSemanticsAction(label: 'Delete chat'): () async {
                if (await _confirmDeleteChat(context)) {
                  ctrl.deleteSession(s.id);
                }
              },
            },
            child: GlassCard(
              onTap: () => ctrl.selectSession(s),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          if (preview != null && preview.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              preview,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: AppColors.secondaryText,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text(
                            '${s.questionCount} question'
                            '${s.questionCount == 1 ? '' : 's'} · '
                            '${_dateTime(s.savedAt)}',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.navy.withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SessionView extends StatelessWidget {
  const _SessionView({super.key, required this.ctrl});

  final AiChatController ctrl;

  @override
  Widget build(BuildContext context) {
    final session = ctrl.selectedSession;
    if (session == null) return const SizedBox.shrink();
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: session.messages.length,
            itemBuilder: (_, i) => _MessageTile(message: session.messages[i]),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppGlass.barFill,
            border: Border(top: BorderSide(color: AppGlass.divider)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.paddingOf(context).bottom,
            ),
            child: DentraPillButton(
              label: 'Continue this chat',
              icon: Icons.reply_rounded,
              onPressed:
                  ctrl.isLoading ? null : () => ctrl.continueSession(session),
            ),
          ),
        ),
      ],
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white.withValues(alpha: 0.8),
                  border: Border.all(color: AppGlass.border),
                ),
                child: Icon(icon, size: 28, color: AppColors.g2),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                  height: 1.5,
                ),
              ),
              if (action != null) ...[
                const SizedBox(height: 22),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small pieces ──────────────────────────────────────────────────────────

class _GlassCircleButton extends StatelessWidget {
  const _GlassCircleButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: GlassBlur(
          child: DecoratedBox(
            decoration: AppGlass.surface(
              borderRadius: BorderRadius.circular(22),
              tint: AppColors.white,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onPressed,
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(icon, size: 20, color: AppColors.navy),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimizedPill extends StatelessWidget {
  const _MinimizedPill({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: loading ? 'Rabi is typing. Open chat' : 'Open Rabi chat',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.g2.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: GlassBlur(
            child: DecoratedBox(
              decoration: AppGlass.surface(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: onTap,
                  child: SizedBox(
                    height: 48,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _RabiAvatar(size: 36),
                          const SizedBox(width: 10),
                          Text(
                            'Rabi',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                          ),
                          if (loading) ...[
                            const SizedBox(width: 10),
                            const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.g2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Today, 3:42 PM", "Yesterday, 9:10 AM" or "Oct 3, 2026".
String _dateTime(DateTime d) {
  final now = DateTime.now();
  if (DentraDates.sameDay(d, now)) return 'Today, ${DentraDates.time(d)}';
  final yesterday = now.subtract(const Duration(days: 1));
  if (DentraDates.sameDay(d, yesterday)) {
    return 'Yesterday, ${DentraDates.time(d)}';
  }
  return DentraDates.medium(d);
}
