import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:image/image.dart' as img;
import 'package:printing/printing.dart';

import '../../../core/utils/dentra_dates.dart';
import '../../profile/data/models/user_profile.dart';
import '../data/care_plan.dart';
import '../data/patient_context.dart';
import '../data/scan_report.dart';
import 'report_pdf.dart';

/// Longest side of a photo in the PDF: sharp in print, small enough to send.
const int _photoSide = 1000;

/// Makes the screening report and hands it to the browser or the system's share
/// sheet. It's built on this device from data the signed-in user's own requests
/// returned, and nothing is uploaded.
Future<void> downloadScreeningReport({
  required ScreeningReport report,
  required PatientContext patient,
  required ScanTrend trend,
  required ImageProvider? Function(String photoId) imageOf,
  UserProfile? person,
  String? sessionId,
}) async {
  final bytes = await buildReportPdf(
    ReportPdfData(
      report: report,
      patient: patient,
      plan: CarePlan.of(report, patient, trend),
      trend: trend,
      person: person,
      sessionId: sessionId,
      generatedAt: DateTime.now(),
      fonts: await _loadFonts(),
      logo: await _loadLogo(),
      photos: await _loadPhotos(report, imageOf),
    ),
  );
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'DENTRA-screening-${DentraDates.isoDate(patient.at)}.pdf',
  );
}

Future<ReportFonts> _loadFonts() async => ReportFonts(
      regular: await rootBundle.load('assets/fonts/Outfit-Regular.ttf'),
      medium: await rootBundle.load('assets/fonts/Outfit-Medium.ttf'),
      semiBold: await rootBundle.load('assets/fonts/Outfit-SemiBold.ttf'),
      bold: await rootBundle.load('assets/fonts/Outfit-Bold.ttf'),
    );

Future<Uint8List?> _loadLogo() async {
  try {
    final data = await rootBundle.load('assets/images/dentra_mark.png');
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Photos with a sign in them, already scaled down. One that can't be loaded is
/// left out, and the report says so.
Future<Map<String, ReportPhoto>> _loadPhotos(
  ScreeningReport report,
  ImageProvider? Function(String photoId) imageOf,
) async {
  final photos = <String, ReportPhoto>{};
  for (final id in report.photosWithSigns) {
    final provider = imageOf(id);
    if (provider == null) continue;
    try {
      photos[id] = await loadReportPhoto(provider);
    } catch (_) {
      continue;
    }
    // Lets the button's spinner keep moving between photos.
    await Future<void>.delayed(Duration.zero);
  }
  return photos;
}

/// Reads [provider], which may be a photo in memory or a signed link, and turns
/// it into a small JPEG.
Future<ReportPhoto> loadReportPhoto(ImageProvider provider) async {
  final image = await _resolve(
    ResizeImage(
      provider,
      width: _photoSide,
      policy: ResizeImagePolicy.fit,
      height: _photoSide,
      allowUpscaling: false,
    ),
  );
  try {
    final raw = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final jpeg = img.encodeJpg(
      img.Image.fromBytes(
        width: image.width,
        height: image.height,
        bytes: raw!.buffer,
        numChannels: 4,
      ),
      quality: 80,
    );
    return ReportPhoto(jpeg: jpeg, width: image.width, height: image.height);
  } finally {
    image.dispose();
  }
}

Future<ui.Image> _resolve(ImageProvider provider) {
  final done = Completer<ui.Image>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.complete(info.image.clone());
      info.dispose();
    },
    onError: (error, stack) {
      stream.removeListener(listener);
      if (!done.isCompleted) done.completeError(error, stack);
    },
  );
  stream.addListener(listener);
  return done.future.timeout(const Duration(seconds: 30));
}
