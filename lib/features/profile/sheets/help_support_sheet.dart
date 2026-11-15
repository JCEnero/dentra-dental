import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_radius.dart';
import '../data/profile_content.dart';
import '../widgets/profile_settings.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../core/constants/app_glass.dart';

/// Help & support: FAQs plus ways to reach the team.
///
/// [hostContext] is the page behind the sheet, used for feedback shown
/// after the sheet closes.
Future<void> showHelpSupportSheet(BuildContext hostContext) {
  return showGlassSheet<void>(
    context: hostContext,
    title: 'Help & support',
    subtitle: 'Find quick answers, or get in touch with our team.',
    builder: (sheetContext) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (q, a) in ProfileContent.faqs)
          _FaqItem(question: q, answer: a),
        const SizedBox(height: 14),
        Text(
          'STILL NEED HELP?',
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 10),
        ProfileSheetCard(
          children: [
            ProfileSettingsTile(
              icon: Icons.mail_outline_rounded,
              title: 'Email support',
              subtitle:
                  '${ProfileContent.supportEmail} · Replies within 24 hours',
              onTap: () async {
                // Close first so any fallback message is visible.
                Navigator.of(sheetContext).pop();
                final opened = await _composeEmail(
                  subject: 'DENTRA support request',
                  body: '',
                );
                if (!opened && hostContext.mounted) {
                  showDentraSnack(
                    hostContext,
                    _noEmailAppMessage,
                    tone: DentraFeedbackTone.info,
                  );
                }
              },
            ),
            ProfileSettingsTile(
              icon: Icons.flag_outlined,
              title: 'Report a problem',
              subtitle: 'Tell us what went wrong',
              onTap: () {
                Navigator.of(sheetContext).pop();
                showReportProblemSheet(hostContext);
              },
            ),
          ],
        ),
      ],
    ),
  );
}

/// A short form that turns a problem report into a pre-filled email.
Future<void> showReportProblemSheet(BuildContext hostContext) async {
  final sent = await showGlassSheet<bool>(
    context: hostContext,
    title: 'Report a problem',
    subtitle: 'Describe what happened. We will open your email app with '
        'the report ready to send.',
    builder: (_) => const _ReportProblemForm(),
  );
  if (sent == true && hostContext.mounted) {
    showDentraSnack(hostContext, 'Report ready in your email app.');
  }
}

/// Copy shown when no email app could be opened.
const _noEmailAppMessage = 'No email app found. We copied '
    '${ProfileContent.supportEmail} so you can paste it into any mail app.';

/// Opens the user's email app addressed to support. When no email app is
/// available, copies the address instead and returns false so the caller
/// can explain (a snackbar would be hidden behind an open sheet).
Future<bool> _composeEmail({
  required String subject,
  required String body,
}) async {
  // Encoded by hand: Uri.queryParameters turns spaces into '+', which
  // several mail apps show literally.
  final uri = Uri(
    scheme: 'mailto',
    path: ProfileContent.supportEmail,
    query: 'subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body)}',
  );

  var opened = false;
  try {
    opened = await launchUrl(uri);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    await Clipboard.setData(
      const ClipboardData(text: ProfileContent.supportEmail),
    );
  }
  return opened;
}

class _ReportProblemForm extends StatefulWidget {
  const _ReportProblemForm();

  @override
  State<_ReportProblemForm> createState() => _ReportProblemFormState();
}

class _ReportProblemFormState extends State<_ReportProblemForm> {
  static const _minLength = 15;

  final _descCtrl = TextEditingController();
  final _descFocus = FocusNode();
  String? _category;
  String? _categoryError;
  String? _descError;
  bool _submitted = false;
  bool _opening = false;
  String? _launchError;

  @override
  void dispose() {
    _descCtrl.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  String? _validateDesc() {
    final text = _descCtrl.text.trim();
    if (text.isEmpty) return 'Describe the problem.';
    if (text.length < _minLength) {
      return 'Add a little more detail (at least $_minLength characters).';
    }
    return null;
  }

  Future<void> _submit() async {
    if (_opening) return;
    setState(() {
      _submitted = true;
      _launchError = null;
      _categoryError = _category == null ? 'Choose a category.' : null;
      _descError = _validateDesc();
    });
    if (_categoryError != null) return;
    if (_descError != null) {
      _descFocus.requestFocus();
      return;
    }

    setState(() => _opening = true);
    final body = '${_descCtrl.text.trim()}\n\n'
        '---\nCategory: $_category\n'
        'App version: ${ProfileContent.appVersion}\n'
        'Platform: ${kIsWeb ? 'web' : defaultTargetPlatform.name}';
    final opened = await _composeEmail(
      subject: 'Problem report: $_category',
      body: body,
    );
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop(true);
      return;
    }
    // The report text stays in the form so nothing is lost.
    setState(() {
      _opening = false;
      _launchError = _noEmailAppMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final descHasError = _descError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Category',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final cat in ProfileContent.problemCategories)
              DentraChoiceChip(
                label: cat,
                selected: _category == cat,
                onSelected: () => setState(() {
                  _category = cat;
                  _categoryError = null;
                }),
              ),
          ],
        ),
        DentraInlineNotice(message: _categoryError),
        const SizedBox(height: 20),
        Text(
          'What happened?',
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 7),
        TextField(
          controller: _descCtrl,
          focusNode: _descFocus,
          minLines: 4,
          maxLines: 8,
          maxLength: 1000,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_submitted || _descError != null) {
              setState(() => _descError = _validateDesc());
            }
          },
          style: GoogleFonts.outfit(fontSize: 14, color: AppColors.navy),
          decoration: InputDecoration(
            hintText: 'What were you doing, and what did you expect to happen?',
            hintStyle: GoogleFonts.outfit(
              fontSize: 14,
              color: AppColors.secondaryText.withValues(alpha: 0.6),
            ),
            errorText: _descError,
            errorStyle: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.coral,
            ),
            counterStyle: GoogleFonts.outfit(
              fontSize: 11,
              color: AppColors.secondaryText,
            ),
            filled: true,
            fillColor: descHasError
                ? const Color(0xFFFFF5F3)
                : AppColors.white.withValues(alpha: 0.8),
            contentPadding: const EdgeInsets.all(14),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.border),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide:
                  BorderSide(color: AppColors.coral.withValues(alpha: 0.6)),
            ),
            focusedErrorBorder: const OutlineInputBorder(
              borderRadius: AppRadius.mdAll,
              borderSide: BorderSide(color: AppColors.coral, width: 1.5),
            ),
          ),
        ),
        DentraInlineNotice(
          message: _launchError,
          tone: DentraFeedbackTone.info,
        ),
        const SizedBox(height: 18),
        DentraPillButton(
          label: 'Continue in email',
          loadingLabel: 'Opening email…',
          icon: Icons.send_rounded,
          loading: _opening,
          onPressed: _submit,
        ),
      ],
    );
  }
}

/// Expandable FAQ row.
class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final duration = dentraMotion(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: duration,
        decoration: BoxDecoration(
          color: _expanded ? AppGlass.fillHigh : AppGlass.fillLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _expanded
                ? AppColors.g2.withValues(alpha: 0.4)
                : AppColors.g2.withValues(alpha: 0.12),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    button: true,
                    expanded: _expanded,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.question,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: duration,
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 22,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: duration,
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _expanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10, right: 8),
                            child: Text(
                              widget.answer,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                color: AppColors.secondaryText,
                                height: 1.55,
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
