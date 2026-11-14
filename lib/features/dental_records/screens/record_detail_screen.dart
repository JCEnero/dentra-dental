import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/utils/dentra_dates.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/dentra_glass_ui.dart';
import '../../../shared/widgets/dentra_image_viewer.dart';
import '../../../shared/widgets/dentra_page_header.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../dental_explorer/data/tooth_catalog.dart';
import '../../history/widgets/tooth_history.dart';
import '../data/models/dental_record.dart';
import '../providers/dental_records_provider.dart';
import '../services/record_file_picker.dart';
import '../widgets/record_format.dart';
import '../widgets/record_source_label.dart';
import 'record_editor_screen.dart';

/// Everything saved for one clinic visit, personal photo or note, with
/// its attachments. Shows only what the user entered; nothing here is
/// presented as verified.
class RecordDetailScreen extends ConsumerStatefulWidget {
  const RecordDetailScreen({super.key, required this.recordId});

  final String recordId;

  static Route<void> route(String recordId) => MaterialPageRoute<void>(
        builder: (_) => RecordDetailScreen(recordId: recordId),
      );

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  // Last seen record, so a delete doesn't flash "missing" before closing.
  DentalRecord? _record;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Fresh attachment links (signed URLs expire after an hour).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(dentalRecordsProvider.notifier)
          .refreshRecord(widget.recordId)
          .catchError((Object _) {});
    });
  }

  DentalRecordsNotifier get _notifier =>
      ref.read(dentalRecordsProvider.notifier);

  Future<void> _delete(DentalRecord r) async {
    final confirmed = await showGlassConfirmDialog(
      context: context,
      icon: Icons.delete_outline_rounded,
      title: 'Delete this ${r.source.label.toLowerCase()}?',
      message: r.attachments.isEmpty
          ? 'It will be removed from your history. This cannot be undone.'
          : 'It and its ${r.attachments.length} '
              '${r.attachments.length == 1 ? 'file' : 'files'} will be removed '
              'from your history. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final toast = DentraToast.of(context);
    try {
      await _notifier.delete(r.id);
      toast.show('Removed from your history.');
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      toast.show(
        dentalRecordErrorMessage(e, "Couldn't delete this record."),
        tone: DentraFeedbackTone.error,
      );
    }
  }

  Future<void> _addFile(DentalRecord r, {required bool document}) async {
    final picker = ref.read(recordFilePickerProvider);
    try {
      final file =
          document ? await picker.pickDocument() : await picker.pickPhoto();
      if (file == null || !mounted) return;
      setState(() => _busy = true);
      await _notifier.addAttachment(r.id, file.bytes, fileName: file.name);
      if (mounted) showDentraSnack(context, 'File added.');
    } on PickFileException catch (e) {
      if (mounted) showDentraSnack(context, e.message, tone: DentraFeedbackTone.error);
    } catch (e) {
      if (mounted) {
        showDentraSnack(
          context,
          dentalRecordErrorMessage(e, "Couldn't upload this file."),
          tone: DentraFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeFile(DentalRecord r, RecordAttachment a) async {
    final confirmed = await showGlassConfirmDialog(
      context: context,
      icon: Icons.delete_outline_rounded,
      title: a.isImage ? 'Remove this photo?' : 'Remove this document?',
      message: 'It will be deleted from this record. This cannot be undone.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await _notifier.removeAttachment(r.id, a.id);
    } catch (e) {
      if (mounted) {
        showDentraSnack(
          context,
          dentalRecordErrorMessage(e, "Couldn't remove this file."),
          tone: DentraFeedbackTone.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openDocument(RecordAttachment a) async {
    final url = a.url;
    final opened = url != null &&
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
            .catchError((Object _) => false);
    if (!opened && mounted) {
      showDentraSnack(
        context,
        url == null
            ? 'This document is only stored for this app session.'
            : "Couldn't open this document.",
        tone: DentraFeedbackTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(dentalRecordsProvider);
    final found = async.valueOrNull?.where((r) => r.id == widget.recordId).firstOrNull;
    if (found != null) _record = found;
    final r = _record;

    return Scaffold(
      backgroundColor: AppColors.lightLavender,
      body: AppBackdrop(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DentraPageHeader(
                title: switch (r?.source) {
                  RecordSource.clinicRecord => 'Clinic Visit',
                  RecordSource.personalPhoto => 'Personal Photo',
                  RecordSource.personalNote => 'Personal Note',
                  _ => 'Record',
                },
                onBack: () => Navigator.of(context).maybePop(),
                trailing: r == null
                    ? null
                    : IconButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).push(
                                RecordEditorScreen.route(r.source, existing: r)),
                        tooltip: 'Edit',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.lightLavender,
                          foregroundColor: AppColors.navy,
                          fixedSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 20),
                      ),
              ),
              Divider(height: 1, thickness: 1, color: AppGlass.divider),
              Expanded(
                child: r == null
                    ? _Missing(loading: !async.hasValue)
                    : _body(r),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(DentalRecord r) {
    final canAddFiles = switch (r.source) {
      RecordSource.clinicRecord => r.attachments.length < 10,
      RecordSource.personalPhoto => r.images.isEmpty,
      _ => false,
    };

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(AppSpacing.screenH, 20, AppSpacing.screenH,
          32 + MediaQuery.paddingOf(context).bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Summary(record: r),
              if (r.source == RecordSource.clinicRecord &&
                  r.clinicNotes != null) ...[
                const _SectionTitle('What the clinic noted'),
                _TextCard(
                  text: r.clinicNotes!,
                  caption: 'As recorded by you from your visit',
                ),
              ],
              if (r.notes != null) ...[
                _SectionTitle(switch (r.source) {
                  RecordSource.personalPhoto => 'Description',
                  RecordSource.personalNote => 'Note',
                  _ => 'Your notes',
                }),
                _TextCard(text: r.notes!),
              ],
              if (r.source != RecordSource.personalNote) ...[
                _SectionTitle(
                    r.source == RecordSource.personalPhoto ? 'Photo' : 'Attachments'),
                _Attachments(
                  record: r,
                  busy: _busy,
                  onOpenDocument: _openDocument,
                  onRemove: (a) => _removeFile(r, a),
                ),
                if (canAddFiles) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AddButton(
                        icon: Icons.photo_library_outlined,
                        label: 'Add photo',
                        onTap: _busy ? null : () => _addFile(r, document: false),
                      ),
                      if (r.source == RecordSource.clinicRecord)
                        _AddButton(
                          icon: Icons.description_outlined,
                          label: 'Add PDF or file',
                          onTap: _busy ? null : () => _addFile(r, document: true),
                        ),
                    ],
                  ),
                ],
              ],
              if (r.teeth.isNotEmpty) ...[
                const _SectionTitle('Tooth history'),
                _ToothLinks(teeth: r.teeth),
              ],
              const SizedBox(height: 20),
              _ProvenanceNote(source: r.source),
              const SizedBox(height: 16),
              Center(
                child: TextButton.icon(
                  onPressed: _busy ? null : () => _delete(r),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(
                    'Delete this record',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sections ────────────────────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({required this.record});

  final DentalRecord record;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final facts = <(String, String)>[
      if (r.source == RecordSource.clinicRecord) ...[
        if (r.clinicName != null) ('Clinic', r.clinicName!),
        if (r.procedure != null) ('Procedure', r.procedure!),
        if (r.dentistName != null) ('Dentist', r.dentistName!),
        if (r.followUpDate != null) ('Follow-up', DentraDates.long(r.followUpDate!)),
      ],
      ('Teeth', r.toothNumbers.isEmpty ? 'No specific tooth' : r.toothNumbers.join(', ')),
    ];

    return GlassCard(
      borderRadius: BorderRadius.circular(20),
      borderColor: recordSourceColor(r.source).withValues(alpha: 0.35),
      borderWidth: 1.5,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RecordSourceHeader(source: r.source),
          const SizedBox(height: 14),
          Text(
            r.displayTitle,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            r.source == RecordSource.clinicRecord
                ? 'Visited ${recordDateLabel(r)}'
                : recordDateLabel(r),
            style: GoogleFonts.outfit(fontSize: 13, color: AppColors.secondaryText),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < facts.length; i++)
            _FactRow(facts[i].$1, facts[i].$2, last: i == facts.length - 1),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value, {this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: AppGlass.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(
                label,
                style: GoogleFonts.outfit(fontSize: 13, color: AppColors.secondaryText),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({required this.text, this.caption});

  final String text;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: BorderRadius.circular(18),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            text,
            style: GoogleFonts.outfit(fontSize: 14, color: AppColors.navy, height: 1.55),
          ),
          if (caption != null) ...[
            const SizedBox(height: 8),
            Text(
              caption!,
              style: GoogleFonts.outfit(fontSize: 11.5, color: AppColors.secondaryText),
            ),
          ],
        ],
      ),
    );
  }
}

class _Attachments extends StatelessWidget {
  const _Attachments({
    required this.record,
    required this.busy,
    required this.onOpenDocument,
    required this.onRemove,
  });

  final DentalRecord record;
  final bool busy;
  final ValueChanged<RecordAttachment> onOpenDocument;
  final ValueChanged<RecordAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    final images = record.images;
    final docs = record.documents;
    if (images.isEmpty && docs.isEmpty) {
      return _Note(
        text: record.source == RecordSource.personalPhoto
            ? 'No photo is attached to this entry yet.'
            : 'No photos or documents attached.',
      );
    }

    final caption = record.source == RecordSource.personalPhoto
        ? 'Personal Photo · ${recordDateLabel(record)}'
        : 'Clinic Record · provided by you · ${recordDateLabel(record)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (images.isNotEmpty)
          LayoutBuilder(builder: (context, c) {
            final single = images.length == 1;
            final columns = single ? 1 : (c.maxWidth > 420 ? 3 : 2);
            const gap = 10.0;
            final size = (c.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final a in images)
                  _ImageTile(
                    width: size,
                    height: single ? size * 0.75 : size,
                    image: attachmentImage(a),
                    caption: caption,
                    onRemove: busy ? null : () => onRemove(a),
                  ),
              ],
            );
          }),
        if (images.isNotEmpty && docs.isNotEmpty) const SizedBox(height: 10),
        for (final d in docs) ...[
          _DocumentRow(
            attachment: d,
            onOpen: () => onOpenDocument(d),
            onRemove: busy ? null : () => onRemove(d),
          ),
          if (d != docs.last) const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        Text(
          'Provided by you. DENTRA does not verify uploaded documents.',
          style: GoogleFonts.outfit(fontSize: 11.5, color: AppColors.secondaryText),
        ),
      ],
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.width,
    required this.height,
    required this.image,
    required this.caption,
    required this.onRemove,
  });

  final double width;
  final double height;
  final ImageProvider? image;
  final String caption;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final img = image;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Semantics(
              button: img != null,
              label: img == null
                  ? 'Photo stored for this app session only'
                  : 'Photo. Opens full size.',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: img == null
                    ? null
                    : () => showDentraImageViewer(context, image: img, caption: caption),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: img == null
                      ? const DentraImageError()
                      : DentraCoverImage(image: img),
                ),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: onRemove,
                tooltip: 'Remove photo',
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.white.withValues(alpha: 0.88),
                  foregroundColor: AppColors.navy,
                  fixedSize: const Size(36, 36),
                  minimumSize: const Size(36, 36),
                  padding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.attachment,
    required this.onOpen,
    required this.onRemove,
  });

  final RecordAttachment attachment;
  final VoidCallback onOpen;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final kb = (attachment.sizeBytes / 1024).ceil();
    final size = kb >= 1024 ? '${(kb / 1024).toStringAsFixed(1)} MB' : '$kb KB';
    return GlassCard(
      borderRadius: BorderRadius.circular(14),
      onTap: onOpen,
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_outlined, color: AppColors.g2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName ?? 'Clinic document',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  'PDF · $size · added ${DentraDates.medium(attachment.uploadedAt)}',
                  style: GoogleFonts.outfit(fontSize: 12, color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              tooltip: 'Remove document',
              icon: const Icon(Icons.delete_outline_rounded,
                  size: 20, color: AppColors.secondaryText),
            ),
        ],
      ),
    );
  }
}

class _ToothLinks extends StatelessWidget {
  const _ToothLinks({required this.teeth});

  final List<int> teeth;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final fdi in teeth)
          ActionChip(
            onPressed: () => showToothHistorySheet(context, fdi),
            tooltip: 'History of ${ToothCatalog.byFdi(fdi)!.name}',
            backgroundColor: AppColors.white.withValues(alpha: 0.75),
            side: BorderSide(color: AppColors.g2.withValues(alpha: 0.2)),
            shape: const StadiumBorder(),
            avatar: const Icon(Icons.history_rounded, size: 16, color: AppColors.g2),
            label: Text(
              'Tooth $fdi',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.g2,
        minimumSize: const Size(44, 44),
        side: BorderSide(color: AppColors.g2.withValues(alpha: 0.3)),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _ProvenanceNote extends StatelessWidget {
  const _ProvenanceNote({required this.source});

  final RecordSource source;

  @override
  Widget build(BuildContext context) {
    final text = switch (source) {
      RecordSource.clinicRecord =>
        "Recorded by you. DENTRA doesn't verify clinic information and isn't "
            'connected to clinic records. Ask your clinic for official records.',
      RecordSource.personalPhoto =>
        "Your own photo. It isn't a smart screening result or clinical evidence.",
      _ => 'Your own note. It is kept apart from smart screenings and clinic records.',
    };
    return _Note(text: text);
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.lightLavender,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 15, color: AppColors.primary.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.navy,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
      child: Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: AppColors.secondaryText,
          ),
        ),
      ),
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'This record is no longer in your history.',
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(fontSize: 15, color: AppColors.secondaryText),
        ),
      ),
    );
  }
}
