import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/widgets/auth_scaffold.dart' show AuthErrorSlot;
import '../../auth/widgets/auth_text_field.dart';
import '../data/models/user_profile.dart';
import '../providers/profile_provider.dart';
import '../services/profile_service.dart';
import '../../../core/utils/dentra_dates.dart';
import '../utils/profile_validators.dart';
import '../widgets/avatar_picker.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';

/// Full-page form for editing the profile. Pops with `true` after a
/// successful save.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.initial});

  final UserProfile initial;

  static Route<bool> route(UserProfile initial) => MaterialPageRoute<bool>(
        builder: (_) => EditProfileScreen(initial: initial),
      );

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

enum _Field { name, email, phone }

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _connectionError =
      "We couldn't reach Dentra. Check your connection and try again.";

  late final Map<_Field, TextEditingController> _controllers;
  final _focusNodes = {for (final f in _Field.values) f: FocusNode()};
  final _errors = <_Field, String?>{};

  /// What is saved right now; becomes the new baseline after a save, even
  /// a partial one, so "unsaved changes" stays accurate.
  late UserProfile _saved;

  DateTime? _dob;
  String? _dobError;
  Gender? _gender;
  Uint8List? _avatar;

  bool _submitted = false;
  bool _saving = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _saved = widget.initial;
    _controllers = {
      _Field.name: TextEditingController(text: _saved.fullName),
      _Field.email: TextEditingController(text: _saved.email),
      _Field.phone: TextEditingController(text: _saved.phone ?? ''),
    };
    _dob = _saved.dateOfBirth;
    _gender = _saved.gender;
    _avatar = _saved.avatarBytes;
    for (final f in _Field.values) {
      _focusNodes[f]!.addListener(() => _onFocusChanged(f));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final n in _focusNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  // ── State helpers ─────────────────────────────────────────────

  String _text(_Field f) => _controllers[f]!.text.trim();

  /// Normalizes spaces so "Ana  Cruz " saves as "Ana Cruz".
  String get _name => _text(_Field.name).replaceAll(RegExp(r'\s+'), ' ');

  bool get _avatarChanged => !identical(_avatar, _saved.avatarBytes);

  bool get _detailsChanged =>
      _name != _saved.fullName ||
      _text(_Field.email) != _saved.email ||
      _text(_Field.phone) != (_saved.phone ?? '') ||
      _dob != _saved.dateOfBirth ||
      _gender != _saved.gender;

  bool get _isDirty => _detailsChanged || _avatarChanged;

  String? _validate(_Field f) => switch (f) {
        _Field.name => ProfileValidators.fullName(_name),
        _Field.email => ProfileValidators.email(_text(f)),
        _Field.phone => ProfileValidators.phone(_text(f)),
      };

  /// Validates when the user leaves a field, without nagging about an
  /// untouched empty field before the first save attempt.
  void _onFocusChanged(_Field f) {
    if (_focusNodes[f]!.hasFocus) return;
    if (_text(f).isEmpty && !_submitted) return;
    setState(() => _errors[f] = _validate(f));
  }

  void _onChanged(_Field f) {
    setState(() {
      _formError = null;
      if (_submitted || _errors[f] != null) _errors[f] = _validate(f);
    });
  }

  // ── Inputs that aren't text fields ────────────────────────────

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      barrierColor: AppGlass.barrier,
      helpText: 'Date of birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.g2,
                onPrimary: AppColors.white,
              ),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      _dob = picked;
      _dobError = ProfileValidators.dateOfBirth(picked);
      _formError = null;
    });
  }

  Future<void> _changeAvatar() async {
    final choice = await chooseAvatar(context, hasPhoto: _avatar != null);
    if (choice == null || !mounted) return;
    setState(() {
      _avatar = switch (choice) {
        AvatarPicked(:final bytes) => bytes,
        AvatarRemoved() => null,
      };
      _formError = null;
    });
  }

  // ── Save / cancel ─────────────────────────────────────────────

  Future<void> _save() async {
    if (_saving) return;
    if (!_isDirty) {
      Navigator.of(context).pop(false);
      return;
    }

    setState(() {
      _submitted = true;
      _formError = null;
      for (final f in _Field.values) {
        _errors[f] = _validate(f);
      }
      _dobError = ProfileValidators.dateOfBirth(_dob);
    });

    final firstInvalid =
        _Field.values.where((f) => _errors[f] != null).firstOrNull;
    if (firstInvalid != null) {
      _focusNodes[firstInvalid]!.requestFocus();
      return;
    }
    if (_dobError != null) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final notifier = ref.read(profileProvider.notifier);

    try {
      if (_detailsChanged) {
        final phone = _text(_Field.phone);
        await notifier.saveDetails(
          _saved.copyWith(
            fullName: _name,
            email: _text(_Field.email),
            phone: () => phone.isEmpty ? null : phone,
            dateOfBirth: () => _dob,
            gender: () => _gender,
          ),
        );
        _saved = ref.read(profileProvider).requireValue;
      }
      if (_avatarChanged) {
        await notifier.setAvatar(_avatar);
        _saved = ref.read(profileProvider).requireValue;
        // Keep identity so the dirty check sees the saved photo.
        _avatar = _saved.avatarBytes;
      }
    } on ProfileException catch (e) {
      _onSaveFailed(e.message, field: e.field);
      return;
    } catch (_) {
      _onSaveFailed(_connectionError);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// Keeps every input as typed so the user can fix it and retry.
  void _onSaveFailed(String message, {ProfileField? field}) {
    if (!mounted) return;
    final partial =
        !_detailsChanged && _avatarChanged && _saved != widget.initial;
    final fieldKey = switch (field) {
      ProfileField.fullName => _Field.name,
      ProfileField.email => _Field.email,
      ProfileField.phone => _Field.phone,
      _ => null,
    };
    setState(() {
      _saving = false;
      if (fieldKey != null) {
        _errors[fieldKey] = message;
      } else if (field == ProfileField.dateOfBirth) {
        _dobError = message;
      } else {
        _formError = partial
            ? 'Your details were saved, but your photo was not. $message'
            : message;
      }
    });
    if (fieldKey != null) {
      _focusNodes[fieldKey]!.requestFocus();
    } else {
      showDentraSnack(
        context,
        partial ? 'Photo not saved.' : "Changes weren't saved.",
        tone: DentraFeedbackTone.error,
        onRetry: _save,
      );
    }
  }

  /// Confirms before throwing away unsaved edits.
  Future<void> _cancel() async {
    if (_saving) return;
    if (!_isDirty) {
      Navigator.of(context).pop(false);
      return;
    }
    final discard = await showGlassConfirmDialog(
      context: context,
      icon: Icons.edit_off_outlined,
      title: 'Discard changes?',
      message: 'Your edits to this profile will be lost.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop(false);
  }

  // ── Build ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty && !_saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancel();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightLavender,
        body: AppBackdrop(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                DentraPageHeader(title: 'Edit Profile', onBack: _cancel),
                Divider(height: 1, thickness: 1, color: AppGlass.divider),
                Expanded(child: _buildForm()),
                _buildActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, 20, AppSpacing.screenH, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: AbsorbPointer(
            absorbing: _saving,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AvatarEditor(
                  bytes: _avatar,
                  initials: UserProfile(fullName: _name, email: '').initials,
                  changed: _avatarChanged,
                  onChange: _changeAvatar,
                ),
                const SizedBox(height: 20),
                _FormSection(
                  title: 'Basic information',
                  children: [
                    AuthTextField(
                      label: 'Full name',
                      placeholder: 'e.g. Ana Cruz',
                      controller: _controllers[_Field.name]!,
                      focusNode: _focusNodes[_Field.name],
                      errorText: _errors[_Field.name],
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      prefixIcon: const Icon(Icons.person_outline_rounded,
                          size: 18, color: AppColors.secondaryText),
                      onChanged: (_) => _onChanged(_Field.name),
                      onEditingComplete: () =>
                          _focusNodes[_Field.email]!.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    AuthTextField(
                      label: 'Email',
                      placeholder: 'you@example.com',
                      controller: _controllers[_Field.email]!,
                      focusNode: _focusNodes[_Field.email],
                      errorText: _errors[_Field.email],
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      prefixIcon: const Icon(Icons.mail_outline_rounded,
                          size: 18, color: AppColors.secondaryText),
                      onChanged: (_) => _onChanged(_Field.email),
                      onEditingComplete: () =>
                          _focusNodes[_Field.phone]!.requestFocus(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FormSection(
                  title: 'Personal details',
                  subtitle: 'Optional. Helps clinics prepare for your visit.',
                  children: [
                    AuthTextField(
                      label: 'Phone number',
                      placeholder: '+63 912 345 6789',
                      controller: _controllers[_Field.phone]!,
                      focusNode: _focusNodes[_Field.phone],
                      errorText: _errors[_Field.phone],
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      prefixIcon: const Icon(Icons.phone_outlined,
                          size: 18, color: AppColors.secondaryText),
                      onChanged: (_) => _onChanged(_Field.phone),
                      onEditingComplete: () => FocusScope.of(context).unfocus(),
                    ),
                    const SizedBox(height: 16),
                    _DateField(
                      label: 'Date of birth',
                      value: _dob,
                      errorText: _dobError,
                      onTap: _pickDob,
                      onClear: _dob == null
                          ? null
                          : () => setState(() {
                                _dob = null;
                                _dobError = null;
                              }),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gender',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final g in Gender.values)
                          DentraChoiceChip(
                            label: g.label,
                            selected: _gender == g,
                            // Tapping the selected chip clears the answer.
                            onSelected: () => setState(() {
                              _gender = _gender == g ? null : g;
                              _formError = null;
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
                AuthErrorSlot(message: _formError),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return GlassBar(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            AppSpacing.screenH, 12, AppSpacing.screenH, 12 + bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: DentraButtonRow(
              secondary: DentraPillButton(
                label: 'Cancel',
                variant: DentraButtonVariant.outline,
                onPressed: _saving ? null : _cancel,
              ),
              primary: DentraPillButton(
                label: 'Save changes',
                loadingLabel: 'Saving…',
                loading: _saving,
                // Disabled until something changes, so a no-op save
                // can't be sent.
                onPressed: _isDirty ? _save : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: GoogleFonts.outfit(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.bytes,
    required this.initials,
    required this.changed,
    required this.onChange,
  });

  final Uint8List? bytes;
  final String initials;
  final bool changed;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: bytes == null ? 'Add profile photo' : 'Change profile photo',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onChange,
            child: Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.cardGradient,
              ),
              child: Container(
                padding: const EdgeInsets.all(2.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white,
                ),
                child: AnimatedSwitcher(
                  duration: dentraMotion(context, 260),
                  child: AvatarWidget(
                    key: ValueKey(bytes?.length ?? initials),
                    size: 96,
                    initials: initials.isEmpty ? '?' : initials,
                    imageBytes: bytes,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: onChange,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.g2,
            minimumSize: const Size(44, 44),
          ),
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(
            bytes == null ? 'Add photo' : 'Change photo',
            style:
                GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        AnimatedSwitcher(
          duration: dentraMotion(context),
          child: changed
              ? Text(
                  'New photo will be saved with your changes',
                  key: const ValueKey('pending'),
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                )
              : const SizedBox.shrink(key: ValueKey('none')),
        ),
      ],
    );
  }
}

/// Read-only field that opens a date picker, styled like [AuthTextField].
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
    this.errorText,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 7),
        Semantics(
          button: true,
          label:
              '$label, ${value == null ? 'not set' : DentraDates.medium(value!)}',
          excludeSemantics: true,
          child: Material(
            color: hasError ? const Color(0xFFFFF5F3) : AppColors.lightLavender,
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.mdAll,
              side: BorderSide(
                color: hasError
                    ? AppColors.coral.withValues(alpha: 0.6)
                    : AppColors.border,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              customBorder:
                  const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.cake_outlined,
                        size: 18, color: AppColors.secondaryText),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        value == null
                            ? 'Select your date of birth'
                            : DentraDates.medium(value!),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight:
                              value == null ? FontWeight.w400 : FontWeight.w500,
                          color: value == null
                              ? AppColors.secondaryText.withValues(alpha: 0.6)
                              : AppColors.navy,
                        ),
                      ),
                    ),
                    if (onClear != null)
                      IconButton(
                        onPressed: onClear,
                        tooltip: 'Clear date of birth',
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.secondaryText),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: Icon(Icons.calendar_today_outlined,
                            size: 16, color: AppColors.secondaryText),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: hasError
              ? Padding(
                  padding: const EdgeInsets.only(top: 5, left: 2),
                  child: Text(
                    errorText!,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.coral,
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
