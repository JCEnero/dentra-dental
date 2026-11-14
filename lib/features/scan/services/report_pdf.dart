import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/dentra_dates.dart';
import '../../dental_records/data/models/dental_record.dart';
import '../../profile/data/models/user_profile.dart';
import '../data/care_plan.dart';
import '../data/patient_context.dart';
import '../data/scan_outcomes.dart';
import '../data/scan_regions.dart';
import '../data/scan_report.dart';
import '../data/tooth_guidance.dart';

/// A photo ready for the PDF.
/// One PDF image per photo, so a photo used for several teeth is embedded
/// in the file once instead of once per crop.
final _pdfImages = Expando<pw.MemoryImage>();

pw.MemoryImage _pdfImageOf(ReportPhoto photo) =>
    _pdfImages[photo] ??= pw.MemoryImage(photo.jpeg);

class ReportPhoto {
  const ReportPhoto({
    required this.jpeg,
    required this.width,
    required this.height,
  });

  final Uint8List jpeg;
  final int width;
  final int height;
}

/// The app font, embedded so the PDF looks the same everywhere.
class ReportFonts {
  ReportFonts({
    required ByteData regular,
    required ByteData medium,
    required ByteData semiBold,
    required ByteData bold,
  })  : regular = pw.Font.ttf(regular),
        medium = pw.Font.ttf(medium),
        semiBold = pw.Font.ttf(semiBold),
        bold = pw.Font.ttf(bold),
        _glyphs = TtfParser(regular).charToGlyphIndexMap.keys.toSet();

  final pw.Font regular;
  final pw.Font medium;
  final pw.Font semiBold;
  final pw.Font bold;
  final Set<int> _glyphs;

  /// [text] with anything the font can't draw (emoji, other scripts) replaced,
  /// since a user's own words can hold anything.
  String safe(String text) {
    final out = StringBuffer();
    for (final rune in text.runes) {
      out.writeCharCode(
        _glyphs.contains(rune) || rune == 0x0A || rune == 0x20 ? rune : 0x3F,
      );
    }
    return out.toString();
  }
}

/// Everything a report says, from real stored data. Missing data is left out,
/// never filled in.
class ReportPdfData {
  const ReportPdfData({
    required this.report,
    required this.patient,
    required this.plan,
    required this.trend,
    required this.fonts,
    required this.generatedAt,
    this.person,
    this.sessionId,
    this.photos = const {},
    this.logo,
  });

  final ScreeningReport report;
  final PatientContext patient;
  final CarePlan plan;
  final ScanTrend trend;
  final ReportFonts fonts;
  final DateTime generatedAt;
  final UserProfile? person;
  final String? sessionId;
  final Map<String, ReportPhoto> photos;
  final Uint8List? logo;
}

/// The line every page carries, and the first thing the summary says.
const String screeningNotice =
    'These are preliminary AI-assisted screening findings, not a professional '
    'dental diagnosis.';

const _navy = PdfColor.fromInt(0xFF1A2E35);
const _grey = PdfColor.fromInt(0xFF6B7B80);
const _ink = PdfColor.fromInt(0xFF17807D);
const _teal = PdfColor.fromInt(0xFF2CA6A4);
const _strong = PdfColor.fromInt(0xFF1F6F71);
const _possible = PdfColor.fromInt(0xFF2A9493);
const _faint = PdfColor.fromInt(0xFF3BBFB8);
const _clear = PdfColor.fromInt(0xFFB2EDE7);
const _tint = PdfColor.fromInt(0xFFE8F8F7);
const _rule = PdfColor.fromInt(0xFFE0E5E4);
const _edge = PdfColor.fromInt(0xFFB7C3C5);
const _white = PdfColors.white;

/// Photos shown with their marks. The rest are summarised in the coverage table.
const int _maxPhotos = 6;

/// A record table longer than this stops listing.
const int _maxRecords = 15;

PdfColor _stateColor(AreaState s) => switch (s) {
      AreaState.strong => _strong,
      AreaState.possible => _possible,
      AreaState.faint => _faint,
      AreaState.clear => _clear,
      _ => _white,
    };

String _stateWord(AreaState s) => switch (s) {
      AreaState.strong => 'Strong sign',
      AreaState.possible => 'Possible sign',
      AreaState.faint => 'Faint sign',
      AreaState.clear => 'Nothing flagged',
      AreaState.retake => 'Needs a retake',
      AreaState.notRead => 'Not read yet',
      AreaState.notTaken => 'No photo',
    };

Future<Uint8List> buildReportPdf(ReportPdfData d) async {
  final f = d.fonts;
  final doc = pw.Document(
    title: 'DENTRA screening report',
    author: 'DENTRA',
    creator: 'DENTRA',
    subject: 'Preliminary AI-assisted dental screening',
  );
  final content = _Report(d);
  doc.addPage(
    pw.MultiPage(
      maxPages: 40,
      pageTheme: pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 38, 40, 34),
        theme: pw.ThemeData.withFont(
          base: f.regular,
          bold: f.bold,
          italic: f.regular,
          boldItalic: f.bold,
        ).copyWith(
          defaultTextStyle: pw.TextStyle(
            font: f.regular,
            fontSize: 9.5,
            lineSpacing: 2,
            color: _navy,
          ),
        ),
      ),
      header: content.header,
      footer: content.footer,
      build: (_) => content.build(),
    ),
  );
  return doc.save();
}

class _Report {
  _Report(this.d);

  final ReportPdfData d;

  ScreeningReport get r => d.report;
  PatientContext get p => d.patient;
  CarePlan get plan => d.plan;
  ReportFonts get f => d.fonts;

  // ── Type ──────────────────────────────────────────────────────────

  pw.TextStyle get _h1 =>
      pw.TextStyle(font: f.bold, fontSize: 17, color: _navy, lineSpacing: 1);
  pw.TextStyle get _h2 =>
      pw.TextStyle(font: f.bold, fontSize: 12.5, color: _navy);
  pw.TextStyle get _h3 =>
      pw.TextStyle(font: f.semiBold, fontSize: 10, color: _navy);
  pw.TextStyle get _body => pw.TextStyle(
      font: f.regular, fontSize: 9.5, color: _navy, lineSpacing: 2);
  pw.TextStyle get _small => pw.TextStyle(
      font: f.regular, fontSize: 8, color: _grey, lineSpacing: 1.5);
  pw.TextStyle get _label =>
      pw.TextStyle(font: f.medium, fontSize: 8, color: _grey);
  pw.TextStyle get _value => pw.TextStyle(
      font: f.semiBold, fontSize: 9.5, color: _navy, lineSpacing: 1.5);

  pw.Widget _t(String text, pw.TextStyle style, {pw.TextAlign? align}) =>
      pw.Text(f.safe(text), style: style, textAlign: align);

  // ── Page furniture ────────────────────────────────────────────────

  pw.Widget header(pw.Context c) {
    if (c.pageNumber == 1) return pw.SizedBox();
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _rule, width: 0.7)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _t('DENTRA screening report', _label),
          _t(DentraDates.long(p.at), _label),
        ],
      ),
    );
  }

  pw.Widget footer(pw.Context c) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 10),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _rule, width: 0.7)),
        ),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _t(screeningNotice, _small)),
            pw.SizedBox(width: 16),
            _t('Page ${c.pageNumber} of ${c.pagesCount}', _small),
          ],
        ),
      );

  // ── The whole report ──────────────────────────────────────────────

  List<pw.Widget> build() => [
        _title(),
        pw.SizedBox(height: 14),
        _patientCard(),
        pw.SizedBox(height: 12),
        if (plan.isEmergency) ...[_emergency(), pw.SizedBox(height: 12)],
        _summary(),
        ..._checkSaw(),
        ..._teeth(),
        ..._comparison(),
        ..._told(),
        ..._records(),
        ..._connections(),
        ..._recommendations(),
        ..._limits(),
      ];

  pw.Widget _title() => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (d.logo case final logo?) ...[
            pw.Image(pw.MemoryImage(logo), height: 30),
            pw.SizedBox(width: 10),
          ],
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _t('Dental screening report', _h1),
                _t(
                  'Scan of ${DentraDates.long(p.at)}, ${DentraDates.time(p.at)}',
                  _small,
                ),
              ],
            ),
          ),
        ],
      );

  /// Who it's for and which scan it is. Only what's on their account.
  pw.Widget _patientCard() {
    final person = d.person;
    final name = person?.fullName.trim() ?? '';
    final born = person?.dateOfBirth;
    final cells = <(String, String)>[
      if (name.isNotEmpty) ('Name', name),
      if (born != null) ('Date of birth', DentraDates.long(born)),
      if (born != null) ('Age at scan', '${_ageAt(born, p.at)}'),
      (
        'Scan date and time',
        '${DentraDates.long(p.at)}, ${DentraDates.time(p.at)}'
      ),
      (
        r.guided ? 'Views read' : 'Photos read',
        '${r.viewsRead} of ${r.viewsTotal}',
      ),
      if (d.sessionId case final id?) ('Reference', _shortRef(id)),
      ('Report made', DentraDates.long(d.generatedAt)),
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(12, 9, 12, 9),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _rule, width: 0.7),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Wrap(
        spacing: 16,
        runSpacing: 7,
        children: [
          for (final (label, value) in cells)
            pw.SizedBox(
              width: 150,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [_t(label, _label), _t(value, _value)],
              ),
            ),
        ],
      ),
    );
  }

  static int _ageAt(DateTime born, DateTime at) {
    var age = at.year - born.year;
    if (at.month < born.month ||
        (at.month == born.month && at.day < born.day)) {
      age--;
    }
    return age;
  }

  static String _shortRef(String id) =>
      id.length <= 10 ? id : id.substring(id.length - 10);

  pw.Widget _emergency() {
    final step = plan.steps.first;
    final recent = d.generatedAt.difference(p.at).inHours <= 48;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _strong,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _t(
            recent ? step.title : 'At this scan, you needed emergency care',
            pw.TextStyle(font: f.bold, fontSize: 12, color: _white),
          ),
          pw.SizedBox(height: 3),
          _t(
            step.detail,
            pw.TextStyle(
              font: f.regular,
              fontSize: 9.5,
              color: _white,
              lineSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 3),
          _t(
            'From what you told us. Not something the check saw.',
            pw.TextStyle(font: f.semiBold, fontSize: 8, color: _clear),
          ),
        ],
      ),
    );
  }

  /// The result at a glance, for a dentist who reads only this box.
  pw.Widget _summary() {
    final range = r.confidenceRange;
    final figures = <(String, String)>[
      ('Areas read', '${r.areasRead} of ${MouthArea.values.length}'),
      ('Areas flagged', '${r.areasFlagged}'),
      (
        r.faintCount > 0 ? 'Signs, plus ${r.faintCount} faint' : 'Signs',
        '${r.signCount}',
      ),
      if (range != null)
        (
          'Model confidence',
          range.$1 == range.$2 ? '${range.$1}%' : '${range.$1}–${range.$2}%',
        ),
      ('Photos read', '${r.photosRead} of ${r.photoIds.length}'),
    ];
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: _tint,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _t('Summary',
              pw.TextStyle(font: f.semiBold, fontSize: 8.5, color: _ink)),
          pw.SizedBox(height: 2),
          _t(r.findingLine, _h1),
          pw.SizedBox(height: 3),
          _t(screeningNotice, _body),
          pw.SizedBox(height: 11),
          _t(
            'When to see a dentist',
            pw.TextStyle(font: f.semiBold, fontSize: 8.5, color: _ink),
          ),
          pw.SizedBox(height: 1),
          _t(plan.title, _h2),
          pw.SizedBox(height: 1),
          _t(plan.because, _small),
          if (!plan.isEmergency) ...[pw.SizedBox(height: 7), _careScale()],
          pw.SizedBox(height: 11),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final (label, value) in figures)
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _t(
                          value,
                          pw.TextStyle(
                              font: f.bold, fontSize: 13, color: _navy)),
                      _t(label, _small),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The same scale as the app: a stop for each step, named underneath.
  pw.Widget _careScale() {
    const stops = [
      CareLevel.routine,
      CareLevel.nextVisit,
      CareLevel.soon,
      CareLevel.prompt,
    ];
    final index = stops.indexOf(plan.level);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(
          height: 10,
          child: pw.CustomPaint(
            size: const PdfPoint(double.infinity, 10),
            painter: (canvas, size) {
              final y = size.y / 2;
              final cell = size.x / stops.length;
              double x(int i) => i == 0
                  ? 5
                  : i == stops.length - 1
                      ? size.x - 5
                      : cell * (i + 0.5);
              canvas
                ..setStrokeColor(_clear)
                ..setLineWidth(2)
                ..drawLine(x(0), y, x(stops.length - 1), y)
                ..strokePath()
                ..setStrokeColor(_teal)
                ..drawLine(x(0), y, x(index), y)
                ..strokePath();
              for (var i = 0; i < stops.length; i++) {
                final reached = i <= index;
                canvas
                  ..setFillColor(reached ? _teal : _white)
                  ..drawEllipse(x(i), y, i == index ? 5 : 3, i == index ? 5 : 3)
                  ..fillPath();
                if (!reached) {
                  canvas
                    ..setStrokeColor(_teal)
                    ..setLineWidth(0.8)
                    ..drawEllipse(x(i), y, 3, 3)
                    ..strokePath();
                }
              }
              canvas
                ..setFillColor(_white)
                ..drawEllipse(x(index), y, 2, 2)
                ..fillPath();
            },
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            for (final (i, stop) in stops.indexed)
              pw.Expanded(
                child: _t(
                  stop.short,
                  pw.TextStyle(
                    font: i == index ? f.bold : f.regular,
                    fontSize: 8,
                    color: i == index ? _ink : _grey,
                  ),
                  align: i == 0
                      ? pw.TextAlign.left
                      : i == stops.length - 1
                          ? pw.TextAlign.right
                          : pw.TextAlign.center,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Stays on one page. A column on its own would split between its children,
  /// and only a horizontal layout is never split.
  pw.Widget _together(List<pw.Widget> children) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      );

  /// A section's heading and what kind of information it holds.
  pw.Widget _heading(String title, {String? note}) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 16, bottom: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _t(title, _h2),
            if (note != null) ...[pw.SizedBox(height: 1), _t(note, _small)],
          ],
        ),
      );

  // ── What the check saw ────────────────────────────────────────────

  List<pw.Widget> _checkSaw() {
    final spots = r.spots;
    final issues = r.analysis.qualityIssues;
    final severities = spots.any((s) => s.finding.severity != null);
    return [
      _together([
        _heading(
          'What the check saw',
          note: 'Found by computer vision in your photos alone. Your answers '
              'and records played no part in these findings.',
        ),
        _areaGrid(),
        pw.SizedBox(height: 5),
        _legend(),
      ]),
      pw.SizedBox(height: 10),
      if (spots.isEmpty)
        _t(
          r.photosRead == 0
              ? 'No photo could be read, so nothing can be said about your teeth.'
              : 'Nothing was flagged in the ${r.photosRead} '
                  '${r.photosRead == 1 ? 'photo' : 'photos'} the check could '
                  'read. This check can miss early decay, so it can\'t promise '
                  'there\'s none.',
          _body,
        )
      else
        _table(
          widths: severities
              ? const [2.6, 2.2, 2.2, 1.5, 1.1, 1]
              : const [2.8, 2.4, 2.4, 1.6, 1.2],
          head: [
            'Finding',
            'General area',
            'Photo',
            'Strength',
            'Confidence',
            if (severities) 'Severity',
          ],
          rows: [
            for (final s in spots)
              [
                s.finding.label,
                s.where,
                s.photo.label,
                s.strength.label,
                s.percent == null ? 'Not reported' : '${s.percent}%',
                if (severities) s.finding.severity ?? 'Not reported',
              ],
          ],
        ),
      pw.SizedBox(height: 5),
      for (final strength in SignStrength.values.reversed)
        if (r.countOf(strength) > 0)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.RichText(
              text: pw.TextSpan(
                style: _small,
                children: [
                  pw.TextSpan(
                    text: '${strength.label}: ',
                    style: pw.TextStyle(
                      font: f.semiBold,
                      fontSize: 8,
                      color: _navy,
                    ),
                  ),
                  pw.TextSpan(text: signMeaning[strength]),
                ],
              ),
            ),
          ),
      pw.SizedBox(height: 2),
      _t(
        'The check works in general mouth areas. It can\'t identify a tooth '
        'number, and strength is how sure the model is, not how far along or '
        'how serious something is.',
        _small,
      ),
      if (r.dentalWorkLine case final work?) ...[
        pw.SizedBox(height: 6),
        _t('Also seen, not counted as a sign: $work.', _body),
      ],
      _byType(),
      ..._photos(),
      if (issues.isNotEmpty) ...[
        _heading('Photos to retake'),
        _table(
          widths: const [2, 5],
          head: const ['Photo', 'Why'],
          rows: [
            for (final i in issues)
              [
                findScanRegion(i.regionId)?.label ?? i.regionId,
                i.message,
              ],
          ],
        ),
      ],
      ..._coverage(),
    ];
  }

  /// The six areas as a dentist sees them: upper right on the left.
  pw.Widget _areaGrid() {
    const rows = [
      [MouthArea.upperRight, MouthArea.upperFront, MouthArea.upperLeft],
      [MouthArea.lowerRight, MouthArea.lowerFront, MouthArea.lowerLeft],
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) pw.SizedBox(height: 3),
          pw.Row(
            children: [
              for (final (j, area) in row.indexed) ...[
                if (j > 0) pw.SizedBox(width: 3),
                pw.Expanded(child: _areaCell(area)),
              ],
            ],
          ),
        ],
      ],
    );
  }

  pw.Widget _areaCell(MouthArea area) {
    final state = r.areas[area]!.state;
    final dark = state == AreaState.strong ||
        state == AreaState.possible ||
        state == AreaState.faint;
    return pw.Container(
      height: 36,
      padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: pw.BoxDecoration(
        color: _stateColor(state),
        borderRadius: pw.BorderRadius.circular(5),
        border: state.read ? null : pw.Border.all(color: _edge, width: 0.7),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          _t(
            area.label,
            pw.TextStyle(
              font: f.semiBold,
              fontSize: 8.5,
              color: dark ? _white : _navy,
            ),
          ),
          _t(
            _stateWord(state),
            pw.TextStyle(
              font: f.regular,
              fontSize: 7.5,
              color: dark ? _white : _grey,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _legend() {
    final shown = {for (final a in r.areas.values) a.state};
    Iterable<pw.Widget> item(AreaState s) sync* {
      yield pw.Container(
        width: 7,
        height: 7,
        decoration: pw.BoxDecoration(
          color: _stateColor(s),
          borderRadius: pw.BorderRadius.circular(2),
          border: s.read ? null : pw.Border.all(color: _edge, width: 0.6),
        ),
      );
      yield pw.SizedBox(width: 3);
      yield _t(_stateWord(s), _small);
      yield pw.SizedBox(width: 10);
    }

    return pw.Row(
      children: [
        for (final s in const [
          AreaState.strong,
          AreaState.possible,
          AreaState.faint,
          AreaState.clear,
          AreaState.notRead,
          AreaState.retake,
          AreaState.notTaken,
        ])
          if (shown.contains(s)) ...item(s),
      ],
    );
  }

  /// Their own photos with the marks on them. Rings only: a number next to a
  /// tooth would read as a tooth number.
  List<pw.Widget> _photos() {
    final ids = r.photosWithSigns.where(d.photos.containsKey).toList();
    if (ids.isEmpty) {
      if (r.photosWithSigns.isEmpty) return const [];
      return [
        pw.SizedBox(height: 6),
        _t('Your marked photos could not be loaded for this report.', _small),
      ];
    }
    final shown = ids.take(_maxPhotos).toList();
    return [
      _heading(
        'Your marked photos',
        note: 'Each ring is one place the check marked. '
            '${ids.length > shown.length ? 'The ${shown.length} photos with the strongest signs are shown.' : ''}',
      ),
      pw.Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [for (final id in shown) _photoCard(id)],
      ),
    ];
  }

  pw.Widget _photoCard(String id) {
    final photo = d.photos[id]!;
    const maxW = 252.0, maxH = 170.0;
    final aspect = photo.width / photo.height;
    final w = aspect >= maxW / maxH ? maxW : maxH * aspect;
    final h = w / aspect;
    final spots = r.spots.where((s) => s.photoId == id).toList();
    final region = findScanRegion(id);
    return pw.SizedBox(
      width: maxW,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.ClipRRect(
            horizontalRadius: 6,
            verticalRadius: 6,
            child: pw.SizedBox(
              width: w,
              height: h,
              child: pw.Stack(
                children: [
                  pw.Image(
                    _pdfImageOf(photo),
                    width: w,
                    height: h,
                    fit: pw.BoxFit.fill,
                  ),
                  for (final s in spots)
                    if (s.box case final b?)
                      ..._ring(
                        b.left * w,
                        b.top * h,
                        b.width * w,
                        b.height * h,
                      ),
                ],
              ),
            ),
          ),
          pw.SizedBox(height: 3),
          _t(region?.label ?? id, _h3),
          _t(
            [
              for (final s in spots)
                '${s.strength.label}${s.percent == null ? '' : ', ${s.percent}%'}',
            ].join(' · '),
            _small,
          ),
        ],
      ),
    );
  }

  /// What the check looked for, a bar each, and what it can't read yet.
  pw.Widget _byType() {
    final rows = r.conditions;
    final most = rows.fold<int>(1, (m, x) => (x.count ?? 0) > m ? x.count! : m);
    PdfColor fill(ConditionRow row) => switch (row.kind) {
          ConditionKind.faint => _faint,
          ConditionKind.dentalWork => _clear,
          _ => _possible,
        };
    return _together([
      _heading(
        'What the check looked for',
        note: 'Marks of each kind in the photos read. Rows with no bar are '
            'not read by this check yet.',
      ),
      for (final row in rows)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 5),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(width: 120, child: _t(row.name, _h3)),
              pw.Expanded(
                child: row.count == null
                    ? pw.Container(
                        height: 7,
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(3),
                          border: pw.Border.all(color: _edge, width: 0.6),
                        ),
                      )
                    : pw.Container(
                        height: 7,
                        decoration: pw.BoxDecoration(
                          color: _tint,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Row(
                          children: [
                            if (row.count! > 0)
                              pw.Expanded(
                                flex: row.count!,
                                child: pw.Row(
                                  children: [
                                    if (row.strong > 0)
                                      pw.Expanded(
                                        flex: row.strong,
                                        child: pw.Container(color: _strong),
                                      ),
                                    if (row.count! > row.strong)
                                      pw.Expanded(
                                        flex: row.count! - row.strong,
                                        child: pw.Container(color: fill(row)),
                                      ),
                                  ],
                                ),
                              ),
                            if (most > row.count!)
                              pw.Expanded(
                                flex: most - row.count!,
                                child: pw.SizedBox(),
                              ),
                          ],
                        ),
                      ),
              ),
              pw.SizedBox(width: 8),
              pw.SizedBox(
                width: 150,
                child: _t(
                  row.count == null
                      ? row.note
                      : '${row.count}${row.strong > 0 ? ' (${row.strong} strong)' : ''}. ${row.note}',
                  _small,
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  // ── Tooth by tooth ────────────────────────────────────────────────

  /// Each tooth the check marked, on its own: where, what was found, what it
  /// could mean, what the user said about it, what to do, and what a dentist
  /// may consider. Faint signs are listed after, more briefly.
  List<pw.Widget> _teeth() {
    final counted = [
      for (final g in plan.teeth)
        if (!g.faint) g,
    ];
    final faint = [
      for (final g in plan.teeth)
        if (g.faint) g,
    ];
    if (counted.isEmpty && faint.isEmpty) return const [];
    return [
      if (counted.isNotEmpty) ...[
        _together([
          _heading(
            'Tooth by tooth',
            note: 'Each marked tooth from the check, with its photo. Where a '
                'tooth is comes from the photo\'s view: the check can\'t give '
                'a tooth number. What you told us is labelled as yours.',
          ),
          _toothEntry(counted.first, 1, counted.length),
        ]),
        for (final (i, g) in counted.skip(1).indexed)
          _together([_toothEntry(g, i + 2, counted.length)]),
      ],
      if (faint.isNotEmpty)
        _together([
          _heading(
            'Faint signs to watch',
            note: 'Too unsure to act on. Compared on the next scan.',
          ),
          _table(
            widths: const [3.4, 2.2, 1.2],
            head: const ['Where', 'Photo', 'Confidence'],
            rows: [
              for (final g in faint)
                [
                  g.where,
                  g.spot.photo.label,
                  g.spot.percent == null
                      ? 'Not reported'
                      : '${g.spot.percent}%',
                ],
            ],
          ),
        ]),
    ];
  }

  pw.Widget _toothEntry(ToothGuidance g, int n, int of) {
    final s = g.spot;
    pw.Widget part(String label, String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _t(label,
                  pw.TextStyle(font: f.semiBold, fontSize: 8, color: _ink)),
              _t(text, _body),
            ],
          ),
        );
    final facts = [
      'Photo: ${s.photo.label}',
      s.strength.label,
      if (s.percent case final p?) '$p% model confidence',
    ].join(' · ');
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _rule, width: 0.7),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _toothCrop(s),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _t('Marked tooth $n of $of', _label),
                _t('${g.title}: ${g.where}', _h3),
                _t(facts, _small),
                part('What we found', g.found),
                part('What this could mean', g.meaning),
                if (g.pain case final pain?)
                  part(
                    'You told us (not detected by the check)',
                    '${pain.label}${g.answerNote == null ? '' : ' ${g.answerNote}'}'
                        '${g.symptomsToWatch.isEmpty ? '' : ' ${g.symptomsToWatch.join('; ')}.'}',
                  )
                else if (g.asks)
                  part(
                    'Pain or sensitivity in this tooth',
                    'Not answered.',
                  ),
                part(
                  'What to do next: ${g.urgency.title}',
                  '${g.nextStep} ${g.urgencyWhy}',
                ),
                if (g.treatments.isNotEmpty)
                  part(
                    'Treatments a dentist may consider (not a diagnosis)',
                    [
                      for (final t in g.treatments) '${t.name}: ${t.when}',
                      if (g.treatmentNote case final note?) note,
                    ].join(' '),
                  ),
                part('Why it matters', g.why),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A ring around a marked tooth, as in the app: white with a dark edge, so it
  /// shows on light teeth and dark photos alike.
  List<pw.Widget> _ring(double x, double y, double w, double h) => [
        pw.Positioned(
          left: x - 1.2,
          top: y - 1.2,
          child: pw.Container(
            width: w + 2.4,
            height: h + 2.4,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(5),
              border: pw.Border.all(color: _strong, width: 1.2),
            ),
          ),
        ),
        pw.Positioned(
          left: x,
          top: y,
          child: pw.Container(
            width: w,
            height: h,
            decoration: pw.BoxDecoration(
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: _white, width: 1.4),
            ),
          ),
        ),
      ];

  /// The marked tooth, cut from its photo with its ring, or a plain box when
  /// the photo couldn't be loaded.
  pw.Widget _toothCrop(ReportSpot s) {
    const w = 104.0, h = 78.0;
    final photo = d.photos[s.photoId];
    final box = s.box;
    if (photo == null || box == null) {
      return pw.Container(
        width: w,
        height: h,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: _tint,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child:
            _t('Photo not in this report', _small, align: pw.TextAlign.center),
      );
    }
    // A window around the box with the frame's shape, inside the photo.
    final aspect = photo.width / photo.height;
    final side = (box.width > box.height ? box.width : box.height) * 2.6;
    var vw = side.clamp(0.2, 1.0);
    var vh = (vw * aspect * h / w).clamp(0.2, 1.0);
    vw = vh * w / h / aspect;
    if (vw > 1) {
      vh = vh / vw;
      vw = 1;
    }
    final vx = (box.center.dx - vw / 2).clamp(0.0, 1 - vw);
    final vy = (box.center.dy - vh / 2).clamp(0.0, 1 - vh);
    final scaleX = w / vw, scaleY = h / vh;
    return pw.ClipRRect(
      horizontalRadius: 6,
      verticalRadius: 6,
      child: pw.SizedBox(
        width: w,
        height: h,
        child: pw.Stack(
          overflow: pw.Overflow.clip,
          children: [
            pw.Positioned(
              left: -vx * scaleX,
              top: -vy * scaleY,
              child: pw.Image(
                _pdfImageOf(photo),
                width: scaleX,
                height: scaleY,
                fit: pw.BoxFit.fill,
              ),
            ),
            ..._ring(
              (box.left - vx) * scaleX,
              (box.top - vy) * scaleY,
              box.width * scaleX,
              box.height * scaleY,
            ),
          ],
        ),
      ),
    );
  }

  /// What was and wasn't read, surface by surface.
  List<pw.Widget> _coverage() {
    final cells = r.coverage;
    if (cells == null) {
      return [
        _heading('What this scan covered'),
        _t(
          '${r.areasRead} of ${MouthArea.values.length} areas read, from '
          '${r.photosRead} of ${r.photoIds.length} photos.',
          _body,
        ),
      ];
    }
    const order = [
      MouthArea.upperRight,
      MouthArea.upperFront,
      MouthArea.upperLeft,
      MouthArea.lowerRight,
      MouthArea.lowerFront,
      MouthArea.lowerLeft,
    ];
    return [
      _together([
        _heading(
          'What this scan covered',
          note: 'Each surface against each area of the mouth.',
        ),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(1.1),
            for (var i = 1; i <= order.length; i++)
              i: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              children: [
                pw.SizedBox(),
                for (final a in order)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 3, right: 2),
                    child: _t(a.label, _small),
                  ),
              ],
            ),
            for (final surface in ToothSurface.values)
              pw.TableRow(
                verticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(right: 4),
                    child: _t(surface.label, _h3),
                  ),
                  for (final a in order)
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(1),
                      child: _coverageCell(cells[(surface, a)]!),
                    ),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 4),
        _t(
          'Not read by this check: plaque, tartar, gums and inner sides. It '
          'also misses many small cavities and decay between teeth. Inner '
          'side photos are saved, but no model can read them yet.',
          _small,
        ),
      ]),
    ];
  }

  pw.Widget _coverageCell(AreaState state) {
    final dark = state == AreaState.strong ||
        state == AreaState.possible ||
        state == AreaState.faint;
    return pw.Container(
      height: 17,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: _stateColor(state),
        borderRadius: pw.BorderRadius.circular(3),
        border: state.read ? null : pw.Border.all(color: _edge, width: 0.5),
      ),
      child: _t(
        switch (state) {
          AreaState.strong => 'Strong',
          AreaState.possible => 'Possible',
          AreaState.faint => 'Faint',
          AreaState.clear => 'Clear',
          AreaState.notRead => 'Not read',
          AreaState.retake => 'Retake',
          AreaState.notTaken => 'No photo',
        },
        pw.TextStyle(
          font: f.medium,
          fontSize: 7,
          color: dark ? _white : _grey,
        ),
      ),
    );
  }

  // ── Earlier scans ─────────────────────────────────────────────────

  /// Only areas both scans could read are compared, and nothing is called
  /// better or worse: an area was flagged, or it wasn't.
  List<pw.Widget> _comparison() {
    final t = d.trend;
    if (!t.hasHistory) return const [];
    final points = t.points;
    final most = points.fold<int>(
      1,
      (m, x) => x.report.spots.length > m ? x.report.spots.length : m,
    );
    String areas(List<MouthArea> list) =>
        describeAreas(list.toSet()).toLowerCase();
    final lines = t.mixedVersions
        ? [
            'Some of these scans came from an earlier version of the check, so '
                'a difference may come from the check rather than your teeth. '
                'They aren\'t compared here.',
          ]
        : [
            if (t.newAreas.isNotEmpty)
              'Flagged this time and not last time: ${areas(t.newAreas)}.',
            if (t.stillAreas.isNotEmpty)
              'Flagged in both: ${areas(t.stillAreas)}.',
            if (t.clearedAreas.isNotEmpty)
              'Flagged last time and not this time: ${areas(t.clearedAreas)}. '
                  'Photos differ, so this doesn\'t prove it has gone.',
            if (t.newAreas.isEmpty &&
                t.stillAreas.isEmpty &&
                t.clearedAreas.isEmpty)
              'No area read in both scans was flagged in either.',
            if (t.repeating.isNotEmpty)
              'Flagged in 3 or more scans in a row: '
                  '${areas(t.repeating.keys.toList())}. That doesn\'t show '
                  'whether it\'s changing, only that it keeps being marked.',
          ];
    return [
      _together([
        _heading(
          'Compared with your earlier scans',
          note: 'From the check alone. An area is only compared when both '
              'scans could read it.',
        ),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            for (final (i, x) in points.indexed) ...[
              if (i > 0) pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _t('${x.report.spots.length}', _h3),
                    pw.SizedBox(height: 2),
                    pw.Container(
                      height: 4 + 34 * x.report.spots.length / most,
                      decoration: pw.BoxDecoration(
                        color: i == points.length - 1 ? _teal : _clear,
                        borderRadius: pw.BorderRadius.circular(2),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    _t(
                      '${DentraDates.monthShort(x.at.month)} ${x.at.day}',
                      _small,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        pw.SizedBox(height: 2),
        _t(
          'Signs marked at each scan, faint ones included. The last bar is '
          'this scan.',
          _small,
        ),
        pw.SizedBox(height: 5),
        for (final line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: _t(line, _body),
          ),
      ]),
    ];
  }

  // ── What they told us ─────────────────────────────────────────────

  List<pw.Widget> _told() {
    final facts = [
      ...p.symptomFacts,
      ...p.treatmentFacts,
      for (final g in plan.teeth)
        if (g.pain case final pain?)
          ContextFact('Marked tooth, ${g.spot.photo.label} photo', pain.label),
      ...p.backgroundFacts,
    ];
    if (facts.isEmpty) return const [];
    return [
      _together([
        _heading(
          'What you told us',
          note: 'Your own answers. The check did not detect any of this.',
        ),
        _table(
          widths: const [2, 6],
          rows: [
            for (final fact in facts) [fact.label, fact.value],
          ],
          firstColumnQuiet: true,
        ),
      ]),
    ];
  }

  // ── Their records ─────────────────────────────────────────────────

  List<pw.Widget> _records() {
    final all = p.relevantRecords({
      for (final s in r.spots) ...s.areas,
      ...?p.symptoms?.areas,
    });
    if (all.isEmpty) {
      if (!p.recordsUnavailable) return const [];
      return [
        _heading('Your dental records'),
        _t('Your records couldn\'t be loaded when this report was made.',
            _body),
      ];
    }
    final shown = all.take(_maxRecords).toList();
    String what(ContextRecord x) => [
          x.title,
          if (x.record.clinicName case final clinic? when clinic != x.title)
            clinic,
          if (x.record.dentistName case final dentist?) dentist,
          if (x.record.followUpDate case final date?)
            'Follow-up ${DentraDates.medium(date)}',
          if (x.record.images.isNotEmpty)
            '${x.record.images.length} ${x.record.images.length == 1 ? 'photo' : 'photos'} attached',
          if (x.record.documents.isNotEmpty)
            '${x.record.documents.length} ${x.record.documents.length == 1 ? 'document' : 'documents'} attached',
        ].join(' · ');
    return [
      _together([
        _heading(
          'Your dental records',
          note:
              'Entries you added. DENTRA has not verified them, and a note or '
              'photo is your own, not proof of a condition.',
        ),
        _table(
          widths: const [1.6, 1.6, 1.2, 4.6],
          head: const ['Date', 'Kind', 'Teeth', 'Entry'],
          rows: [
            for (final x in shown)
              [
                x.dateLabel,
                switch (x.source) {
                  RecordSource.clinicRecord => 'Clinic record',
                  RecordSource.personalPhoto => 'Personal photo',
                  RecordSource.personalNote => 'Personal note',
                  RecordSource.aiScreening => 'Screening',
                },
                x.teeth.isEmpty ? 'None given' : x.teeth.join(', '),
                what(x),
              ],
          ],
        ),
      ]),
      if (all.length > shown.length) ...[
        pw.SizedBox(height: 3),
        _t('And ${all.length - shown.length} older entries in your account.',
            _small),
      ],
    ];
  }

  // ── How they fit together ─────────────────────────────────────────

  List<pw.Widget> _connections() {
    if (plan.links.isEmpty) return const [];
    pw.Widget entry(ContextLink link) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _t(link.title, _h3),
              _t(link.text, _body),
              _t(careSourcesInWords(link.sources), _small),
            ],
          ),
        );
    return [
      _together([
        _heading(
          'How this fits together',
          note:
              'What your answers and records have in common with your photos, '
              'only where the entries support it.',
        ),
        entry(plan.links.first),
      ]),
      for (final link in plan.links.skip(1)) _together([entry(link)]),
    ];
  }

  // ── What to do ────────────────────────────────────────────────────

  List<pw.Widget> _recommendations() {
    String when(CareLevel level) => switch (level) {
          CareLevel.emergency => 'Get help now',
          CareLevel.prompt => 'See a dentist promptly',
          CareLevel.soon => 'Book a visit soon',
          CareLevel.nextVisit => 'At your next check-up',
          CareLevel.routine => 'When it suits',
        };
    pw.Widget list(List<String> items) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final item in items)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _t('·  ', _body),
                    pw.Expanded(child: _t(item, _body)),
                  ],
                ),
              ),
          ],
        );
    pw.Widget entry(CareStep step) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 7),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: _t(step.title, _h3)),
                  pw.SizedBox(width: 10),
                  _t(
                    when(step.level),
                    pw.TextStyle(font: f.semiBold, fontSize: 8.5, color: _ink),
                  ),
                ],
              ),
              _t(step.detail, _body),
              _t(careSourcesInWords(step.sources), _small),
            ],
          ),
        );
    return [
      _together([
        _heading('Recommendations'),
        if (plan.steps.isEmpty)
          _t(
            'Keep your regular check-ups. A dentist can see what photos can\'t.',
            _body,
          )
        else
          entry(plan.steps.first),
      ]),
      for (final step in plan.steps.skip(1)) _together([entry(step)]),
      _together([
        pw.SizedBox(height: 3),
        _t('Questions for your dentist', _h3),
        pw.SizedBox(height: 2),
        list(plan.questions),
        pw.SizedBox(height: 6),
        _t('Every day', _h3),
        pw.SizedBox(height: 2),
        list(plan.dailyCare),
      ]),
    ];
  }

  // ── Limits ────────────────────────────────────────────────────────

  List<pw.Widget> _limits() {
    final model = r.analysis.model;
    return [
      _together([
        _heading('Limits of this report'),
        for (final line in [
          '$screeningNotice Only a dentist can diagnose a condition.',
          'A result with nothing marked doesn\'t mean your teeth are healthy. '
              'A photo can\'t show what\'s under the surface, and this check '
              'misses many small cavities.',
          'Stained grooves, old fillings and shadows can look like decay in a '
              'photo.',
          'Your answers and records are used to explain results and suggest '
              'next steps. They never reach the image model, and they don\'t '
              'change what it finds.',
          'Get emergency care for swelling near your eye or in your neck, or '
              'trouble breathing, swallowing, speaking or opening your mouth.',
        ])
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: _t(line, _body),
          ),
        if (model != null) ...[
          pw.SizedBox(height: 2),
          _t('Analysis version: $model', _small),
        ],
      ]),
    ];
  }

  // ── Tables ────────────────────────────────────────────────────────

  pw.Widget _table({
    required List<double> widths,
    required List<List<String>> rows,
    List<String>? head,
    bool firstColumnQuiet = false,
  }) {
    pw.Widget cell(String text, pw.TextStyle style) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          child: _t(text, style),
        );
    return pw.Table(
      columnWidths: {
        for (final (i, w) in widths.indexed) i: pw.FlexColumnWidth(w),
      },
      border: const pw.TableBorder(
        horizontalInside: pw.BorderSide(color: _rule, width: 0.5),
        bottom: pw.BorderSide(color: _rule, width: 0.5),
      ),
      children: [
        if (head != null)
          pw.TableRow(
            repeat: true,
            decoration: const pw.BoxDecoration(color: _tint),
            children: [for (final h in head) cell(h, _label)],
          ),
        for (final row in rows)
          pw.TableRow(
            children: [
              for (final (i, text) in row.indexed)
                cell(
                  text,
                  firstColumnQuiet && i == 0
                      ? _label
                      : pw.TextStyle(
                          font: f.regular,
                          fontSize: 9,
                          color: _navy,
                          lineSpacing: 1.5,
                        ),
                ),
            ],
          ),
      ],
    );
  }
}
