import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'saved_camera.dart';

/// Keeps the Dentra Cam's details on this phone. The camera belongs to the
/// phone, not the account, so nothing here is per user.
///
/// Storage failures never block anyone: reads fall back to defaults (no
/// camera, tips shown) and writes are best-effort.
class CameraStore {
  const CameraStore();

  static const _camera = 'dentra_cam.v1.camera';
  // v2: the upright default changed, so settings saved before it start over.
  static const _settings = 'dentra_cam.v2.view';
  static const _setupOffered = 'dentra_cam.v1.setup_offered';
  static const _tipsHidden = 'dentra_cam.v1.tips_hidden';

  Future<SavedCamera?> loadCamera() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_camera);
      return raw == null ? null : SavedCamera.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCamera(SavedCamera camera) =>
      _write((p) => p.setString(_camera, jsonEncode(camera.toJson())));

  Future<void> forgetCamera() => _write((p) => p.remove(_camera));

  Future<CameraViewSettings> loadSettings() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_settings);
      return CameraViewSettings.fromJson(raw == null ? null : jsonDecode(raw));
    } catch (_) {
      return const CameraViewSettings();
    }
  }

  Future<void> saveSettings(CameraViewSettings settings) =>
      _write((p) => p.setString(_settings, jsonEncode(settings.toJson())));

  /// Whether the setup guide has opened by itself once already.
  Future<bool> setupOffered() => _readBool(_setupOffered);
  Future<void> markSetupOffered() => _write((p) => p.setBool(_setupOffered, true));

  /// "Don't show again" on the capture tips.
  Future<bool> tipsHidden() => _readBool(_tipsHidden);
  Future<void> setTipsHidden(bool hidden) =>
      _write((p) => p.setBool(_tipsHidden, hidden));

  Future<bool> _readBool(String key) async {
    try {
      return (await SharedPreferences.getInstance()).getBool(key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _write(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // Best-effort.
    }
  }
}
