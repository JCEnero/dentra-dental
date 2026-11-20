import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import 'setup_sound_contract.dart';

SetupSound createSetupSound() => _WebPoofSound();

class _WebPoofSound implements SetupSound {
  web.AudioContext? _context;
  web.AudioBuffer? _buffer;
  Future<void>? _ready;
  bool _closed = false;
  int _generation = 0;
  web.AudioBufferSourceNode? _source;
  @override
  Future<void> prepare() => _ready ??= _prepare();
  Future<void> _prepare() async {
    try {
      final context = _context ??= web.AudioContext();
      final data = await rootBundle.load('assets/audio/rabi_poof.wav');
      final bytes = Uint8List.fromList(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
      final buffer = await context.decodeAudioData(bytes.buffer.toJS).toDart;
      if (!_closed) _buffer = buffer;
    } catch (_) {/* Browser audio availability does not affect setup. */}
  }

  @override
  void unlock() {
    if (_closed) return;
    // Resume inside the gesture, before any await (including on Safari).
    try {
      final context = _context ??= web.AudioContext();
      unawaited(context.resume().toDart.then<void>((_) {}, onError: (_) {}));
    } catch (_) {}
  }

  @override
  Future<void> play() async {
    if (_closed) return;
    final generation = _generation;
    await prepare();
    final context = _context;
    final buffer = _buffer;
    if (_closed ||
        generation != _generation ||
        context == null ||
        buffer == null ||
        context.state != 'running') {
      return;
    }
    try {
      final source = context.createBufferSource()..buffer = buffer;
      _source?.stop();
      _source = source;
      final gain = context.createGain()..gain.value = 0.45;
      source.connect(gain);
      gain.connect(context.destination);
      source.onended = ((web.Event _) {
        source.disconnect();
        gain.disconnect();
        if (identical(_source, source)) _source = null;
      }).toJS;
      source.start();
    } catch (_) {}
  }

  @override
  void stop() {
    ++_generation;
    try {
      _source?.stop();
    } catch (_) {}
    _source = null;
  }

  @override
  Future<void> dispose() async {
    stop();
    _closed = true;
    _buffer = null;
    try {
      await _context?.close().toDart;
    } catch (_) {}
  }
}
