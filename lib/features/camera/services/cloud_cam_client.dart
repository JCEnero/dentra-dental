import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../data/camera_protocol.dart';
import 'dentra_cam_client.dart';
import 'mjpeg_frames.dart' show looksLikeJpeg;

/// A WebSocket, as much of one as [CloudCamClient] uses. Tests use a fake.
abstract interface class CamSocket {
  /// Text arrives as [String], binary as [Uint8List]. Ends when it closes.
  Stream<Object?> get messages;

  void send(String message);

  Future<void> close();
}

typedef CamSocketConnect = Future<CamSocket> Function(Uri uri);

/// Opens a real WebSocket (the browser's own on the web).
Future<CamSocket> connectCamSocket(Uri uri) async {
  final channel = WebSocketChannel.connect(uri);
  await channel.ready;
  return _ChannelSocket(channel);
}

class _ChannelSocket implements CamSocket {
  _ChannelSocket(this._channel);

  final WebSocketChannel _channel;

  @override
  Stream<Object?> get messages => _channel.stream;

  @override
  void send(String message) => _channel.sink.add(message);

  @override
  Future<void> close() => _channel.sink.close();
}

/// The relay's address on the DENTRA API, from its base URL.
Uri cloudCamSocketUri(String apiBaseUrl) {
  final base = Uri.parse(apiBaseUrl);
  return base.replace(
    scheme: base.scheme == 'https' ? 'wss' : 'ws',
    path: '${base.path.replaceFirst(RegExp(r'/+$'), '')}/api/cam/ws',
  );
}

/// Talks to a Dentra Cam through the DENTRA API, for the website: a web
/// page can't reach a camera on the home network (its pictures are plain
/// HTTP, and the page is HTTPS), so the camera keeps a link open to the API
/// and the API passes everything along.
///
/// One WebSocket carries it all. It signs in with the user's access token
/// and the camera's id, then asks for pictures while [frames] is listened
/// to; commands and photos travel on it too. The protocol is described in
/// backend/src/modules/cam/cam.hub.ts.
class CloudCamClient implements CamClient {
  CloudCamClient({
    required this.deviceId,
    required this.socketUri,
    required this.accessToken,
    CamSocketConnect? connect,
  }) : _connect = connect ?? connectCamSocket;

  final String deviceId;
  final Uri socketUri;

  /// The signed-in user's token, refreshed when needed. Null when signed out.
  final Future<String?> Function() accessToken;
  final CamSocketConnect _connect;

  static const _openTimeout = Duration(seconds: 20);
  static const _commandTimeout = Duration(seconds: 12);
  static const _photoTimeout = Duration(seconds: 50);

  // Over the internet the picture can pause longer, and a server that was
  // asleep takes a while to wake.
  @override
  Duration get stallAfter => const Duration(seconds: 8);

  @override
  Duration get giveUpAfter => const Duration(seconds: 45);

  _CloudSession? _session;
  Future<_CloudSession>? _opening;
  bool _closed = false;

  @override
  Future<CamStatus> status(
      {Duration timeout = const Duration(seconds: 3)}) async {
    final session = await _open();
    final result = await session.command(
      {'cmd': 'status'},
      _atLeast(timeout, _commandTimeout),
    );
    final status = result['status'];
    return status is Map ? CamStatus.fromJson(status) : const CamStatus();
  }

  @override
  Future<void> setLight({required bool on, required int level}) async {
    final session = await _open();
    await session.command(
      {'cmd': 'light', 'on': on, 'level': level.clamp(0, 100)},
      _commandTimeout,
    );
  }

  @override
  Future<void> setControl(String name, int value) async {
    final session = await _open();
    await session.command(
      {'cmd': 'control', 'var': name, 'val': value},
      _commandTimeout,
    );
  }

  @override
  Future<Uint8List> capture({
    required CamFrameSize size,
    required bool light,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final session = await _open();
    final bytes = await session.photo(
      {'cmd': 'capture', 'res': size.value, 'flash': light},
      _atLeast(timeout, _photoTimeout),
    );
    if (!looksLikeJpeg(bytes)) {
      throw const DentraCamException(CamFailure.badResponse);
    }
    return bytes;
  }

  @override
  Stream<Uint8List> frames() {
    late final StreamController<Uint8List> out;
    StreamSubscription<Uint8List>? pictures;
    _CloudSession? watching;
    var cancelled = false;

    void fail(Object error) {
      if (out.isClosed) return;
      out
        ..addError(_failure(error))
        ..close();
    }

    out = StreamController<Uint8List>(
      onListen: () async {
        try {
          final session = await _open();
          if (cancelled) return;
          if (!session.online) {
            throw const DentraCamException(CamFailure.unreachable);
          }
          pictures = session.pictures.listen(
            out.add,
            onError: fail,
            onDone: () =>
                fail(const DentraCamException(CamFailure.unreachable)),
          );
          watching = session..watch(true);
        } catch (e) {
          fail(e);
        }
      },
      onCancel: () {
        cancelled = true;
        pictures?.cancel();
        watching?.watch(false);
      },
    );
    return out.stream;
  }

  @override
  void close() {
    _closed = true;
    _session?.close();
    _session = null;
  }

  /// The open link, opening it first if needed.
  Future<_CloudSession> _open() async {
    if (_closed) throw const DentraCamException(CamFailure.unreachable);
    final current = _session;
    if (current != null && !current.isClosed) return current;
    return _opening ??= _start().whenComplete(() => _opening = null);
  }

  Future<_CloudSession> _start() async {
    final token = await accessToken();
    if (token == null) throw const DentraCamException(CamFailure.unreachable);
    final CamSocket socket;
    try {
      socket = await _connect(socketUri).timeout(_openTimeout);
    } catch (e) {
      throw _failure(e);
    }
    final session = _CloudSession(socket);
    socket
        .send(jsonEncode({'type': 'auth', 'token': token, 'device': deviceId}));
    try {
      await session.ready.timeout(_openTimeout);
    } catch (e) {
      session.close();
      throw _failure(e);
    }
    if (_closed) {
      session.close();
      throw const DentraCamException(CamFailure.unreachable);
    }
    return _session = session;
  }

  static Duration _atLeast(Duration a, Duration b) => a > b ? a : b;
}

/// One open link to the relay.
class _CloudSession {
  _CloudSession(this._socket) {
    _subscription = _socket.messages.listen(
      _onMessage,
      onError: (Object _) => _ended(),
      onDone: _ended,
    );
  }

  final CamSocket _socket;
  late final StreamSubscription<Object?> _subscription;
  final _ready = Completer<void>();
  final _pictures = StreamController<Uint8List>.broadcast();
  final _pending = <int, Completer<Object>>{};
  var _nextId = 1;
  var _watchers = 0;

  bool online = false;
  bool isClosed = false;

  Future<void> get ready => _ready.future;

  /// Live pictures while anyone [watch]es. An error means the camera left.
  Stream<Uint8List> get pictures => _pictures.stream;

  /// The relay streams while at least one watcher is counted.
  void watch(bool on) {
    final before = _watchers;
    _watchers = (_watchers + (on ? 1 : -1)).clamp(0, 1 << 20);
    if ((before == 0) != (_watchers == 0)) {
      _send({'cmd': 'stream', 'on': _watchers > 0});
    }
  }

  /// Sends a command and waits for its result. Throws [DentraCamException]
  /// when the camera says no, is away, or doesn't answer in time.
  Future<Map<String, Object?>> command(
    Map<String, Object> message,
    Duration timeout,
  ) async {
    final answer = await _ask(message, timeout);
    if (answer is Map<String, Object?>) return answer;
    throw const DentraCamException(CamFailure.badResponse);
  }

  /// Asks for a photo: its JPEG bytes, or a [DentraCamException].
  Future<Uint8List> photo(Map<String, Object> message, Duration timeout) async {
    final answer = await _ask(message, timeout);
    if (answer is Uint8List) return answer;
    throw const DentraCamException(CamFailure.badResponse);
  }

  Future<Object> _ask(Map<String, Object> message, Duration timeout) async {
    if (isClosed) throw const DentraCamException(CamFailure.unreachable);
    if (!online) throw const DentraCamException(CamFailure.unreachable);
    final id = _nextId++;
    final answer = Completer<Object>();
    _pending[id] = answer;
    _send({...message, 'id': id});
    try {
      return await answer.future.timeout(timeout);
    } on TimeoutException {
      throw const DentraCamException(CamFailure.timeout);
    } finally {
      _pending.remove(id);
    }
  }

  void _onMessage(Object? message) {
    if (message is String) return _onText(message);
    final bytes = switch (message) {
      Uint8List() => message,
      List<int>() => Uint8List.fromList(message),
      ByteBuffer() => message.asUint8List(),
      _ => null,
    };
    if (bytes == null || bytes.length < 2) return;
    switch (bytes[0]) {
      case _frame:
        if (_watchers > 0) _pictures.add(Uint8List.sublistView(bytes, 1));
      case _photo when bytes.length > 5:
        final id = ByteData.sublistView(bytes, 1, 5).getUint32(0);
        _pending[id]?.complete(Uint8List.sublistView(bytes, 5));
    }
  }

  void _onText(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return;
    }
    if (json is! Map<String, Object?>) return;
    switch (json['type']) {
      case 'ready':
        online = json['online'] == true;
        if (!_ready.isCompleted) _ready.complete();
      case 'online':
        online = json['online'] == true;
        if (!online) {
          _pictures.addError(const DentraCamException(CamFailure.unreachable));
          _failPending(const DentraCamException(CamFailure.unreachable));
        }
      case 'result':
        final id = json['id'];
        final answer = id is int ? _pending[id] : null;
        if (answer == null || answer.isCompleted) return;
        if (json['ok'] == true) {
          answer.complete(json);
        } else {
          answer.completeError(_errorFor(json['error']));
        }
    }
  }

  static DentraCamException _errorFor(Object? code) => switch (code) {
        'offline' => const DentraCamException(CamFailure.unreachable),
        'timeout' => const DentraCamException(CamFailure.timeout),
        // The camera answered, but couldn't: no light, a busy sensor...
        _ => const DentraCamException(CamFailure.badResponse),
      };

  void _send(Map<String, Object> message) {
    if (isClosed) return;
    try {
      _socket.send(jsonEncode(message));
    } catch (_) {
      _ended();
    }
  }

  void _failPending(DentraCamException error) {
    for (final answer in _pending.values) {
      if (!answer.isCompleted) answer.completeError(error);
    }
  }

  void _ended() {
    if (isClosed) return;
    isClosed = true;
    online = false;
    const gone = DentraCamException(CamFailure.unreachable);
    if (!_ready.isCompleted) _ready.completeError(gone);
    _failPending(gone);
    _pictures
      ..addError(gone)
      ..close();
    unawaited(_subscription.cancel());
  }

  void close() {
    if (isClosed) return;
    _ended();
    unawaited(_socket.close().catchError((Object _) {}));
  }

  static const _frame = 1;
  static const _photo = 2;
}

DentraCamException _failure(Object e) => switch (e) {
      DentraCamException() => e,
      TimeoutException() => const DentraCamException(CamFailure.timeout),
      _ => const DentraCamException(CamFailure.unreachable),
    };
