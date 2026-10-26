import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/dentra_device_service.dart';

enum DeviceStatus {
  unsupported,
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class DeviceConnectionState {
  const DeviceConnectionState({
    required this.status,
    this.failure,
    this.isSlow = false,
  });

  final DeviceStatus status;
  final DeviceFailure? failure;

  /// Connecting has taken longer than usual (still within the timeout).
  final bool isSlow;

  bool get isConnected => status == DeviceStatus.connected;
}

/// Mirrors the device service's real connection state. Every attempt ends
/// in connected or failed: [connectTimeout] bounds a driver that never
/// answers.
class DeviceConnectionNotifier extends Notifier<DeviceConnectionState> {
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration slowAfter = Duration(seconds: 8);

  StreamSubscription<DeviceLinkEvent>? _events;
  Timer? _slowTimer;
  int _attempt = 0;

  DentraDeviceService get _service => ref.read(dentraDeviceServiceProvider);

  @override
  DeviceConnectionState build() {
    final service = ref.watch(dentraDeviceServiceProvider);
    _events?.cancel();
    _events = service.events.listen(_onLinkEvent);
    ref.onDispose(() {
      _events?.cancel();
      _slowTimer?.cancel();
    });
    return DeviceConnectionState(
      status: service.isSupported
          ? DeviceStatus.disconnected
          : DeviceStatus.unsupported,
    );
  }

  Future<void> connect() async {
    if (!_service.isSupported) return;
    if (state.status == DeviceStatus.connecting ||
        state.status == DeviceStatus.connected) {
      return;
    }
    final attempt = ++_attempt;
    state = const DeviceConnectionState(status: DeviceStatus.connecting);
    _slowTimer?.cancel();
    _slowTimer = Timer(slowAfter, () {
      if (attempt == _attempt && state.status == DeviceStatus.connecting) {
        state = const DeviceConnectionState(
          status: DeviceStatus.connecting,
          isSlow: true,
        );
      }
    });

    DeviceFailure? failure;
    try {
      await _service.connect().timeout(connectTimeout);
    } on TimeoutException {
      failure = DeviceFailure.timeout;
      unawaited(_service.disconnect().catchError((_) {}));
    } on DeviceException catch (e) {
      failure = e.failure;
    } catch (_) {
      failure = DeviceFailure.unknown;
    } finally {
      _slowTimer?.cancel();
    }

    if (attempt != _attempt) return; // cancelled meanwhile
    state = failure == null
        ? const DeviceConnectionState(status: DeviceStatus.connected)
        : DeviceConnectionState(status: DeviceStatus.failed, failure: failure);
  }

  /// Abandons a pending attempt, or disconnects.
  Future<void> disconnect() async {
    _attempt++;
    _slowTimer?.cancel();
    if (!_service.isSupported) return;
    state = const DeviceConnectionState(status: DeviceStatus.disconnected);
    try {
      await _service.disconnect();
    } catch (_) {
      // Already gone; nothing else to do.
    }
  }

  void _onLinkEvent(DeviceLinkEvent event) {
    // Only an established (or re-establishing) link can change this way.
    final linked = state.status == DeviceStatus.connected ||
        state.status == DeviceStatus.reconnecting;
    if (!linked) return;
    state = switch (event) {
      DeviceLinkEvent.connected =>
        const DeviceConnectionState(status: DeviceStatus.connected),
      DeviceLinkEvent.reconnecting =>
        const DeviceConnectionState(status: DeviceStatus.reconnecting),
      DeviceLinkEvent.disconnected => const DeviceConnectionState(
          status: DeviceStatus.failed,
          failure: DeviceFailure.connectionLost,
        ),
    };
  }
}

final deviceConnectionProvider =
    NotifierProvider<DeviceConnectionNotifier, DeviceConnectionState>(
  DeviceConnectionNotifier.new,
);
