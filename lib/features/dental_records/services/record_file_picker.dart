import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// A file the user picked, not yet uploaded.
class PickedFile {
  const PickedFile({required this.bytes, this.name});

  final Uint8List bytes;
  final String? name;

  bool get isPdf =>
      bytes.length >= 5 && String.fromCharCodes(bytes.sublist(0, 5)) == '%PDF-';
}

/// Why a pick failed, in words the user can act on.
class PickFileException implements Exception {
  const PickFileException(this.message);
  final String message;

  @override
  String toString() => 'PickFileException($message)';
}

/// Picks photos and documents for dental records.
class RecordFilePicker {
  RecordFilePicker([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// The server's upload limit.
  static const maxBytes = 10 * 1024 * 1024;

  bool get supportsCamera {
    try {
      return _picker.supportsImageSource(ImageSource.camera);
    } catch (_) {
      return false;
    }
  }

  /// A photo from the library or camera. Null when cancelled.
  Future<PickedFile?> pickPhoto({bool camera = false}) async {
    final XFile? file;
    try {
      file = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        // Sharp enough to inspect, small enough to upload quickly.
        maxWidth: 2560,
        maxHeight: 2560,
        imageQuality: 90,
      );
    } catch (_) {
      throw const PickFileException(
          "Couldn't open your photos. Check DENTRA's photo permission.");
    }
    return file == null ? null : _read(file);
  }

  /// A PDF or photo from the device's files. Null when cancelled.
  Future<PickedFile?> pickDocument() async {
    final XFile? file;
    try {
      file = await openFile(acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Documents and photos',
          extensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
          mimeTypes: [
            'application/pdf',
            'image/jpeg',
            'image/png',
            'image/webp'
          ],
          // Listed one by one: 'public.image' would also allow iPhone HEIC
          // files, which the server rejects.
          uniformTypeIdentifiers: [
            'com.adobe.pdf',
            'public.jpeg',
            'public.png',
            'org.webmproject.webp',
          ],
        ),
      ]);
    } catch (_) {
      throw const PickFileException("Couldn't open your files.");
    }
    return file == null ? null : _read(file);
  }

  Future<PickedFile> _read(XFile file) async {
    final size = await file.length();
    if (size > maxBytes) {
      throw const PickFileException(
          'That file is over 10 MB. Choose a smaller one.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) throw const PickFileException('That file is empty.');
    return PickedFile(bytes: bytes, name: file.name);
  }
}

final recordFilePickerProvider =
    Provider<RecordFilePicker>((ref) => RecordFilePicker());
