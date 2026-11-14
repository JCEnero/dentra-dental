import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_radius.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../auth/widgets/auth_text_field.dart';
import '../data/models/dental_record.dart';
import '../providers/dental_records_provider.dart';
import '../services/record_file_picker.dart';
import '../widgets/record_source_label.dart';
import '../widgets/tooth_number_field.dart';
import 'record_detail_screen.dart';

/// Adds or edits a clinic visit, personal photo or personal note. Only
/// what's essential to recognise the record is required; everything a
/// user may not know (dentist, teeth, follow-up) is optional.
class RecordEditorScreen extends ConsumerStatefulWidget {
  const RecordEditorScreen({
    super.key,
    required this.source,
    this.existing,
    this.initialTeeth,
  }) : assert(source != RecordSource.aiScreening);

  final RecordSource source;

  /// The record being edited; null to add a new one.
  final DentalRecord? existing;

  /// Tooth numbers to start a new record with.
  final List<String>? initialTeeth;

  static Route<void> route(
    RecordSource source, {
    DentalRecord? existing,
    List<String>? initialTeeth,
  }) =>
      MaterialPageRoute<void>(
        builder: (_) => RecordEditorScreen(
          source: source,
          existing: existing,
          initialTeeth: initialTeeth,
        ),
      );

  @override
  ConsumerState<RecordEditorScreen> createState() => _RecordEditorScreenState();
}

class _RecordEditorScreenState extends ConsumerState<RecordEditorScreen> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _clinic = TextEditingController(text: widget.existing?.clinicName);
  late final _dentist =
      TextEditingController(text: widget.existing?.dentistName);
  late final _procedure =
      TextEditingController(text: widget.existing?.procedure);
  late final _clinicNotes =
      TextEditingController(text: widget.existing?.clinicNotes);
  late final _notes = TextEditingController(text: widget.existing?.notes);

  late DateTime _date =
      widget.existing?.recordDate ?? DentraDates.dateOnly(DateTime.now());
  late bool _dateUnknown = widget.existing?.dateUnknown ?? false;
  late DateTime? _followUp = widget.existing?.followUpDate;
  late List<String> _teeth =
      widget.existing?.toothNumbers ?? widget.initialTeeth ?? const [];

  /// Files picked while adding a record, uploaded once it is saved.
  final List<PickedFile> _pending = [];

  bool _saving = false;
  bool _dirty = false;
  String? _formError;
  final Map<String, String> _errors = {};

  bool get _isNew => widget.existing == null;
  RecordSource get _source => widget.source;

  @override
  void dispose() {
    for (final c in [_title, _clinic, _dentist, _procedure, _clinicNotes, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed([String? field]) => setState(() {
        _dirty = true;
        _formError = null;
        if (field != null) _errors.remove(field);
      });

  String get _pageTitle => switch (_source) {
        RecordSource.clinicRecord => _isNew ? 'Add clinic visit' : 'Edit clinic visit',
        RecordSource.personalPhoto => _isNew ? 'Add personal photo' : 'Edit photo details',
        RecordSource.personalNote => _isNew ? 'Add personal note' : 'Edit note',
        RecordSource.aiScreening => '',
      };

  String get _dateLabel => switch (_source) {
        RecordSource.clinicRecord => 'Visit date',
        RecordSource.personalPhoto => 'Date taken',
        _ => 'Date',
      };

  // ── Validation (mirrors the API; it checks again) ─────────────

  bool _validate() {
    _errors.clear();
    String t(TextEditingController c) => c.text.trim();
    if (_source == RecordSource.clinicRecord &&
        t(_clinic).isEmpty &&
        t(_procedure).isEmpty) {
      _errors['clinic_name'] =
          'Add the clinic name or the procedure, so you can recognise this visit.';
    }
    if (_source == RecordSource.personalNote && t(_notes).isEmpty) {
      _errors['notes'] = 'Write your note first.';
    }
    if (_followUp != null && _followUp!.isBefore(_date)) {
      _errors['follow_up_date'] = 'The follow-up date has to be on or after the visit.';
    }
    if (_source == RecordSource.personalPhoto && _isNew && _pending.isEmpty) {
      _errors['photo'] = 'Choose a photo to add.';
    }
    setState(() {});
    return _errors.isEmpty;
  }

  DentalRecordInput get _input => DentalRecordInput(
        source: _source,
        recordDate: _date,
        dateUnknown: _source == RecordSource.personalPhoto && _dateUnknown,
        title: _source == RecordSource.personalNote ? _title.text : widget.existing?.title,
        clinicName: _clinic.text,
        dentistName: _dentist.text,
        procedure: _procedure.text,
        clinicNotes: _clinicNotes.text,
        followUpDate: _followUp,
        toothNumbers: _teeth,
        notes: _notes.text,
      );

  // ── Saving ─────────────────────────────────────────────────────

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_validate()) return;
    setState(() => _saving = true);
    final notifier = ref.read(dentalRecordsProvider.notifier);
    final navigator = Navigator.of(context);
    final toast = DentraToast.of(context);
    try {
      final DentalRecord saved;
      if (_isNew) {
        saved = await notifier.create(_input);
      } else {
        saved = await notifier.save(widget.existing!.id, _input);
      }

      var failed = 0;
      for (final file in _pending) {
        try {
          await notifier.addAttachment(saved.id, file.bytes, fileName: file.name);
        } catch (_) {
          failed++;
        }
      }

      toast.show(
        failed == 0
            ? (_isNew ? 'Added to your history.' : 'Changes saved.')
            : 'Saved, but $failed ${failed == 1 ? 'file' : 'files'} '
                "couldn't upload. You can add them from the record.",
        tone: failed == 0 ? DentraFeedbackTone.success : DentraFeedbackTone.error,
      );
      if (_isNew) {
        navigator.pushReplacement(RecordDetailScreen.route(saved.id));
      } else {
        navigator.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _formError = dentalRecordErrorMessage(
            e, "Couldn't save. Check your connection and try again.");
      });
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty || _saving) return !_saving;
    return showGlassConfirmDialog(
      context: context,
      icon: Icons.edit_off_rounded,
      title: 'Discard changes?',
      message: "What you've entered here won't be saved.",
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
  }

  // ── Pickers ────────────────────────────────────────────────────

  Future<DateTime?> _pickDate({
    required DateTime initial,
    required DateTime first,
    required DateTime last,
    required String help,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initial.isAfter(last) ? last : (initial.isBefore(first) ? first : initial),
      firstDate: first,
      lastDate: last,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      barrierColor: AppGlass.barrier,
      helpText: help,
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
  }

  Future<void> _chooseDate() async {
    final today = DentraDates.dateOnly(DateTime.now());
    final picked = await _pickDate(
      initial: _date,
      first: DateTime(today.year - 30),
      last: today,
      help: _dateLabel,
    );
    if (picked == null) return;
    _date = picked;
    _changed('follow_up_date');
  }

  Future<void> _chooseFollowUp() async {
    final picked = await _pickDate(
      initial: _followUp ?? _date.add(const Duration(days: 180)),
      first: _date,
      last: DateTime(_date.year + 5, 12, 31),
      help: 'Follow-up date',
    );
    if (picked == null) return;
    _followUp = picked;
    _changed('follow_up_date');
  }

  Future<void> _addFile({required bool document, bool camera = false}) async {
    final picker = ref.read(recordFilePickerProvider);
    try {
      final file = document
          ? await picker.pickDocument()
          : await picker.pickPhoto(camera: camera);
      if (file == null) return;
      setState(() {
        if (_source == RecordSource.personalPhoto) _pending.clear();
        _pending.add(file);
      });
      _changed('photo');
    } on PickFileException catch (e) {
      if (mounted) {
        showDentraSnack(context, e.message, tone: DentraFeedbackTone.error);
      }
    }
  }

  // ── UI ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty && !_saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          setState(() => _dirty = false);
          navigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.lightLavender,
        body: AppBackdrop(
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DentraPageHeader(
                  title: _pageTitle,
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Divider(height: 1, thickness: 1, color: AppGlass.divider),
                Expanded(child: _form()),
                _actionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _form() {
    final provenance = switch (_source) {
      RecordSource.clinicRecord =>
        "Saved as you enter it. DENTRA doesn't verify clinic details or "
            'documents, and isn\'t connected to clinic systems.',
      RecordSource.personalPhoto =>
        "Saved as your own photo, separate from smart screenings. It isn't "
            'analysed or checked by a dentist.',
      _ => 'Only you can see your notes.',
    };

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenH, 18, AppSpacing.screenH, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RecordSourceHeader(source: _source),
              const SizedBox(height: 6),
              Text(
                provenance,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              ...switch (_source) {
                RecordSource.clinicRecord => _clinicFields(),
                RecordSource.personalPhoto => _photoFields(),
                _ => _noteFields(),
              },
              DentraInlineNotice(message: _formError),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _clinicFields() => [
        _Section(children: [
          AuthTextField(
            label: 'Clinic name',
            placeholder: 'e.g. Smile Dental Clinic',
            controller: _clinic,
            errorText: _errors['clinic_name'],
            textCapitalization: TextCapitalization.words,
            maxLength: 120,
            onChanged: (_) => _changed('clinic_name'),
          ),
          const SizedBox(height: 16),
          _DateField(
            label: _dateLabel,
            value: _date,
            onTap: _chooseDate,
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Procedure or treatment',
            placeholder: 'e.g. Cleaning, filling, extraction',
            controller: _procedure,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 160,
            onChanged: (_) => _changed('clinic_name'),
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Dentist (optional)',
            placeholder: 'If you know it',
            controller: _dentist,
            textCapitalization: TextCapitalization.words,
            maxLength: 120,
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: 16),
          ToothNumberField(
            value: _teeth,
            onChanged: (v) {
              _teeth = v;
              _changed();
            },
          ),
        ]),
        const SizedBox(height: 14),
        _Section(children: [
          AuthTextField(
            label: 'What the clinic noted (optional)',
            placeholder: 'Findings or instructions from your dentist',
            controller: _clinicNotes,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            minLines: 3,
            maxLines: 8,
            maxLength: 4000,
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Your own notes (optional)',
            placeholder: 'How it went, questions for next time',
            controller: _notes,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            minLines: 2,
            maxLines: 6,
            maxLength: 4000,
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: 16),
          _DateField(
            label: 'Follow-up date (optional)',
            value: _followUp,
            errorText: _errors['follow_up_date'],
            onTap: _chooseFollowUp,
            onClear: _followUp == null
                ? null
                : () {
                    _followUp = null;
                    _changed('follow_up_date');
                  },
          ),
        ]),
        if (_isNew) ...[
          const SizedBox(height: 14),
          _Section(children: [
            _PendingFiles(
              title: 'Photos or documents (optional)',
              hint: 'Receipts, x-ray photos or treatment notes. Labelled as '
                  'provided by you.',
              files: _pending,
              onRemove: (f) => setState(() => _pending.remove(f)),
              actions: [
                _FileAction(
                  icon: Icons.photo_library_outlined,
                  label: 'Photo',
                  onTap: () => _addFile(document: false),
                ),
                _FileAction(
                  icon: Icons.description_outlined,
                  label: 'PDF or file',
                  onTap: () => _addFile(document: true),
                ),
              ],
            ),
          ]),
        ],
      ];

  List<Widget> _photoFields() => [
        if (_isNew) ...[
          _Section(children: [
            _PendingFiles(
              title: 'Photo',
              files: _pending,
              errorText: _errors['photo'],
              onRemove: (f) => setState(() => _pending.remove(f)),
              actions: [
                _FileAction(
                  icon: Icons.photo_library_outlined,
                  label: _pending.isEmpty ? 'Choose photo' : 'Replace',
                  onTap: () => _addFile(document: false),
                ),
                if (ref.read(recordFilePickerProvider).supportsCamera)
                  _FileAction(
                    icon: Icons.photo_camera_outlined,
                    label: 'Camera',
                    onTap: () => _addFile(document: false, camera: true),
                  ),
              ],
            ),
          ]),
          const SizedBox(height: 14),
        ],
        _Section(children: [
          _DateField(
            label: _dateLabel,
            value: _dateUnknown ? null : _date,
            placeholder: "Unknown, saved with today's date",
            onTap: _dateUnknown ? null : _chooseDate,
          ),
          const SizedBox(height: 6),
          _CheckRow(
            label: "I don't know when it was taken",
            value: _dateUnknown,
            onChanged: (v) {
              _dateUnknown = v;
              if (v && _isNew) _date = DentraDates.dateOnly(DateTime.now());
              _changed();
            },
          ),
          const SizedBox(height: 12),
          AuthTextField(
            label: 'Description (optional)',
            placeholder: 'What the photo shows',
            controller: _notes,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            minLines: 2,
            maxLines: 6,
            maxLength: 4000,
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: 16),
          ToothNumberField(
            value: _teeth,
            onChanged: (v) {
              _teeth = v;
              _changed();
            },
          ),
        ]),
      ];

  List<Widget> _noteFields() => [
        _Section(children: [
          AuthTextField(
            label: 'Title (optional)',
            placeholder: 'e.g. Ask about sensitivity',
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 120,
            onChanged: (_) => _changed(),
          ),
          const SizedBox(height: 16),
          AuthTextField(
            label: 'Note',
            placeholder: 'Observations, concerns or reminders',
            controller: _notes,
            errorText: _errors['notes'],
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            minLines: 4,
            maxLines: 12,
            maxLength: 4000,
            onChanged: (_) => _changed('notes'),
          ),
          const SizedBox(height: 16),
          _DateField(label: _dateLabel, value: _date, onTap: _chooseDate),
          const SizedBox(height: 16),
          ToothNumberField(
            value: _teeth,
            onChanged: (v) {
              _teeth = v;
              _changed();
            },
          ),
        ]),
      ];

  Widget _actionBar() {
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
                onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
              ),
              primary: DentraPillButton(
                label: _isNew ? 'Save' : 'Save changes',
                loadingLabel: 'Saving…',
                loading: _saving,
                onPressed: _isNew || _dirty ? _save : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
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
    this.placeholder = 'Choose a date',
  });

  final String label;
  final DateTime? value;

  /// Null disables the field.
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final String? errorText;
  final String placeholder;

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
          button: onTap != null,
          label: '$label, ${value == null ? placeholder : DentraDates.medium(value!)}',
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        value == null ? placeholder : DentraDates.long(value!),
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight:
                              value == null ? FontWeight.w400 : FontWeight.w500,
                          color: value == null
                              ? AppColors.secondaryText.withValues(alpha: 0.75)
                              : AppColors.navy,
                        ),
                      ),
                    ),
                    if (onClear != null)
                      IconButton(
                        onPressed: onClear,
                        tooltip: 'Clear $label',
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
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 5, left: 2),
            child: Text(
              errorText!,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.coral,
              ),
            ),
          ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: AppRadius.smAll,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: AppColors.g2,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(fontSize: 13, color: AppColors.navy),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileAction {
  const _FileAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// Files waiting to upload with the new record, plus pick buttons.
class _PendingFiles extends StatelessWidget {
  const _PendingFiles({
    required this.title,
    required this.files,
    required this.onRemove,
    required this.actions,
    this.hint,
    this.errorText,
  });

  final String title;
  final String? hint;
  final List<PickedFile> files;
  final ValueChanged<PickedFile> onRemove;
  final List<_FileAction> actions;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.navy,
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 2),
          Text(
            hint!,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.secondaryText,
              height: 1.4,
            ),
          ),
        ],
        if (files.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final f in files)
                _PendingTile(file: f, onRemove: () => onRemove(f)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in actions)
              OutlinedButton.icon(
                onPressed: a.onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.g2,
                  minimumSize: const Size(44, 44),
                  side: BorderSide(color: AppColors.g2.withValues(alpha: 0.3)),
                  shape: const StadiumBorder(),
                  textStyle: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                icon: Icon(a.icon, size: 18),
                label: Text(a.label),
              ),
          ],
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 2),
            child: Text(
              errorText!,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.coral,
              ),
            ),
          ),
      ],
    );
  }
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.file, required this.onRemove});

  final PickedFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 88,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: file.isPdf
                  ? Container(
                      color: AppColors.lightLavender,
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined,
                              color: AppColors.g2),
                          const SizedBox(height: 4),
                          Text(
                            file.name ?? 'Document',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                                fontSize: 10, color: AppColors.navy),
                          ),
                        ],
                      ),
                    )
                  : Image.memory(
                      file.bytes,
                      fit: BoxFit.cover,
                      cacheWidth: 264,
                      semanticLabel: 'Selected photo',
                    ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              onPressed: onRemove,
              tooltip: 'Remove',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.white.withValues(alpha: 0.9),
                foregroundColor: AppColors.navy,
                minimumSize: const Size(32, 32),
                fixedSize: const Size(32, 32),
                padding: EdgeInsets.zero,
              ),
              icon: const Icon(Icons.close_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
