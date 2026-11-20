import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_backdrop.dart';
import '../../../shared/widgets/glass_card.dart';
import '../data/device_sticker.dart';

class StickerScanResult {
  const StickerScanResult.scanned(DeviceSticker value)
      : sticker = value,
        manual = false;
  const StickerScanResult.manual()
      : sticker = null,
        manual = true;
  final DeviceSticker? sticker;
  final bool manual;
}

final deviceStickerScannerProvider = Provider<
        Future<StickerScanResult?> Function(BuildContext)>(
    (ref) => (context) => Navigator.of(context).push<StickerScanResult>(
        MaterialPageRoute(builder: (_) => const DeviceStickerScanScreen())));

/// Captures frames locally. Only a parsed device identity and key leave this
/// route; no camera image or sticker payload is uploaded or logged.
class DeviceStickerScanScreen extends StatefulWidget {
  const DeviceStickerScanScreen({super.key});
  @override
  State<DeviceStickerScanScreen> createState() =>
      _DeviceStickerScanScreenState();
}

class _DeviceStickerScanScreenState extends State<DeviceStickerScanScreen> {
  late final MobileScannerController _camera;
  late final AppLifecycleListener _lifecycle;
  bool _finishing = false;
  bool _starting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      MobileScannerPlatform.instance.setBarcodeLibraryScriptUrl(
          Uri.base.resolve('/vendor/zxing-0.21.3.min.js').toString());
    }
    _camera = MobileScannerController(
        autoStart: false,
        facing: CameraFacing.back,
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: false);
    _lifecycle = AppLifecycleListener(
      onInactive: () {
        // Permission prompts can inactivate the app before initialization.
        if (_camera.value.hasCameraPermission) {
          unawaited(_camera.stop().catchError((_) {}));
        }
      },
      onResume: () {
        if (!_finishing && _camera.value.hasCameraPermission) {
          unawaited(_start());
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_start());
    });
  }

  String _message(MobileScannerErrorCode code) => switch (code) {
        MobileScannerErrorCode.permissionDenied =>
          'Allow camera access in your browser or app settings, then try again.',
        MobileScannerErrorCode.unsupported =>
          'This device doesn’t have an available camera. You can enter the setup key manually.',
        _ =>
          'Couldn’t open the camera. Close other camera apps and try again, or enter the setup key manually.',
      };

  Future<void> _start() async {
    if (_starting || _finishing || !mounted || _camera.value.isRunning) return;
    _starting = true;
    setState(() => _error = null);
    try {
      await _camera.start();
    } on MobileScannerException catch (error) {
      if (mounted) setState(() => _error = _message(error.errorCode));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t open the camera. You can retry or enter the setup key manually.');
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> _detected(BarcodeCapture capture) async {
    if (_finishing || !mounted) return;
    DeviceSticker? sticker;
    for (final barcode in capture.barcodes) {
      final text = barcode.rawValue;
      if (text == null) continue;
      try {
        sticker = DeviceSticker.parse(text);
        break;
      } on FormatException catch (error) {
        setState(() => _error = error.message);
      }
    }
    if (sticker == null) return;
    _finishing = true;
    try {
      await _camera.stop();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(StickerScanResult.scanned(sticker));
  }

  Future<void> _manual() async {
    if (_finishing) return;
    _finishing = true;
    try {
      await _camera.stop();
    } catch (_) {}
    if (mounted) Navigator.of(context).pop(const StickerScanResult.manual());
  }

  @override
  void dispose() {
    _finishing = true;
    _lifecycle.dispose();
    unawaited(_camera.dispose().catchError((_) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.lightLavender,
        appBar: AppBar(
            title: const Text('Scan device sticker'),
            backgroundColor: AppColors.lightLavender),
        body: AppBackdrop(
            child: SafeArea(
                child: Center(
                    child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            const Text(
                'Point this phone’s camera at the setup sticker on your Dentra Cam.',
                style: TextStyle(
                    fontSize: 18, height: 1.4, color: AppColors.navy)),
            const SizedBox(height: 20),
            ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: AspectRatio(
                    aspectRatio: 1,
                    child: MobileScanner(
                        controller: _camera,
                        onDetect: (capture) => unawaited(_detected(capture)),
                        errorBuilder: (context, error) => ColoredBox(
                            color: AppColors.navy,
                            child: Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(_message(error.errorCode),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            height: 1.5)))))))),
            const SizedBox(height: 16),
            if (_error case final error?)
              GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Semantics(
                      liveRegion: true,
                      child: Text(error, style: const TextStyle(height: 1.5)))),
            const SizedBox(height: 12),
            const Text(
                'Keep the sticker flat, well lit, and fully inside the camera view. Camera images stay on your phone.',
                style: TextStyle(color: AppColors.secondaryText, height: 1.5)),
            const SizedBox(height: 16),
            TextButton.icon(
                onPressed: () => unawaited(_start()),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry camera')),
            TextButton(
                onPressed: () => unawaited(_manual()),
                child: const Text('Enter key manually')),
          ]),
        )))),
      );
}
