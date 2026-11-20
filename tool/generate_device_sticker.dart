import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr/qr.dart';
import 'package:image/image.dart' as img;
import 'package:dentra_mobile/features/camera/data/device_sticker.dart';

/// Factory-only: read protected input from disk, never print the key/payload.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 2) {
    throw ArgumentError('Pass device.json and output directory');
  }
  final manifest = jsonDecode(File(arguments[0]).readAsStringSync()) as Map;
  final sticker = DeviceSticker.parse(
      'DENTRA-DEVICE-1:${manifest['hardware_id']}:${manifest['qr_key']}');
  final directory = Directory(arguments[1])..createSync(recursive: true);
  final matrix = QrImage(QrCode.fromData(
      data: sticker.payload, errorCorrectLevel: QrErrorCorrectLevel.M));
  final count = matrix.moduleCount + 8;
  final paths = StringBuffer();
  for (var y = 0; y < matrix.moduleCount; ++y) {
    for (var x = 0; x < matrix.moduleCount; ++x) {
      if (matrix.isDark(y, x)) paths.write('M${x + 4} ${y + 4}h1v1h-1z');
    }
  }
  final svg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="54mm" height="34mm" viewBox="0 0 540 340">'
      '<rect width="540" height="340" rx="20" fill="white"/>'
      '<g transform="translate(12 12) scale(${316 / count})" shape-rendering="crispEdges">'
      '<path d="$paths" fill="black"/></g>'
      '<g font-family="sans-serif" fill="#1A2E35"><text x="336" y="95" font-size="30" font-weight="bold">Dentra</text>'
      '<text x="336" y="140" font-size="18">DEVICE SETUP</text>'
      '<text x="336" y="185" font-size="19">${sticker.hardwareId.substring(8)}</text>'
      '<text x="336" y="215" font-size="15">Scan in Dentra</text>'
      '<text x="336" y="244" font-size="12">BACKUP KEY</text>'
      '${[
    for (var i = 0; i < 4; i++)
      '<text x="336" y="${263 + i * 19}" font-family="monospace" font-size="15">${sticker.key.substring(i * 8, i * 8 + 8)}</text>'
  ].join()}'
      '</g></svg>';
  File('${directory.path}/device-sticker.svg').writeAsStringSync(svg);
  final pdf = pw.Document();
  pdf.addPage(pw.Page(
      pageFormat: const PdfPageFormat(
          54 * PdfPageFormat.mm, 34 * PdfPageFormat.mm,
          marginAll: 0),
      build: (_) => pw.SvgImage(svg: svg)));
  File('${directory.path}/device-sticker.pdf')
      .writeAsBytesSync(await pdf.save());
  // A lossless preview of the same code is useful for label-printer QA.
  const scale = 10;
  final image = img.Image(width: count * scale, height: count * scale);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));
  for (var y = 0; y < matrix.moduleCount; ++y) {
    for (var x = 0; x < matrix.moduleCount; ++x) {
      if (!matrix.isDark(y, x)) continue;
      img.fillRect(image,
          x1: (x + 4) * scale,
          y1: (y + 4) * scale,
          x2: (x + 5) * scale - 1,
          y2: (y + 5) * scale - 1,
          color: img.ColorRgb8(0, 0, 0));
    }
  }
  File('${directory.path}/sticker-code.png')
      .writeAsBytesSync(img.encodePng(image));
  // Raw RGBA lets tests exercise the shipped browser ZXing decoder in Node.
  File('${directory.path}/sticker-code.rgba').writeAsBytesSync(
      Uint8List.fromList(image.getBytes(order: img.ChannelOrder.rgba)));
  File('${directory.path}/sticker-code-size.txt')
      .writeAsStringSync('${image.width} ${image.height}\n');
}
