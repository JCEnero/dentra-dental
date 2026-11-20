import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'setup_sound_contract.dart';

SetupSound createSetupSound() => _PoofSound();

class _PoofSound implements SetupSound {
  final _player = AudioPlayer();
  Future<void>? _ready;
  bool _closed = false;
  int _generation = 0;
  @override
  Future<void> prepare() => _ready ??= _prepare();
  Future<void> _prepare() async {
    try {
      await _player.setAudioContext(AudioContext(
        android: const AudioContextAndroid(
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
      ));
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(0.45);
      await _player.setSource(AssetSource('audio/rabi_poof.wav'));
    } catch (_) {/* A sound failure never interrupts setup. */}
  }

  @override
  void unlock() {}
  @override
  Future<void> play() async {
    if (_closed) return;
    final generation = _generation;
    try {
      await prepare();
      if (_closed || generation != _generation) return;
      await _player.seek(Duration.zero);
      if (!_closed && generation == _generation) await _player.resume();
    } catch (_) {/* Respect silent/unavailable audio. */}
  }

  @override
  void stop() {
    ++_generation;
    if (!_closed) unawaited(_player.stop().catchError((_) {}));
  }

  @override
  Future<void> dispose() async {
    _closed = true;
    try {
      await _ready;
      await _player.dispose();
    } catch (_) {}
  }
}
