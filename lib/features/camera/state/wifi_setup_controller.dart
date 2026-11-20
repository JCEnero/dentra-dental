import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/camera_protocol.dart';
import '../data/saved_camera.dart';
import '../services/wifi_provisioning.dart';

enum WifiSetupStep { prepare, device, network, finish }

enum WifiSetupPhase {
  idle,
  preparing,
  joiningDevice,
  scanning,
  joiningHome,
  returningHome,
  verifying,
  ready
}

/// Each milestone is backed by a device response. A lost POST response is
/// reconciled with /setup/status before anything is submitted again.
class WifiSetupController extends ChangeNotifier {
  WifiSetupController({
    required ProvisioningTransport transport,
    required Future<void> Function(SavedCamera) onSaved,
    this.pollInterval = const Duration(seconds: 1),
    this.joinTimeout = const Duration(seconds: 55),
    this.verifyTimeout = const Duration(seconds: 45),
  })  : _transport = transport,
        _onSaved = onSaved;

  final ProvisioningTransport _transport;
  final Future<void> Function(SavedCamera) _onSaved;
  final Duration pollInterval, joinTimeout, verifyTimeout;
  WifiSetupStep step = WifiSetupStep.prepare;
  WifiSetupPhase phase = WifiSetupPhase.idle;
  List<WifiNetwork> networks = [];
  WifiNetwork? selected;
  String? error;
  String? _deviceId, _name, _ip, _token;
  SavedCamera? saved;
  bool requiresManualJoin = false;
  bool _disposed = false;
  int _generation = 0;
  bool get busy =>
      phase != WifiSetupPhase.idle && phase != WifiSetupPhase.ready;
  bool get deviceJoinedHome => _ip != null || saved != null;
  bool get isBrowser => _transport.usesBrowserWifi;
  bool get linksAccount => _transport.linksAccount;
  bool _current(int run) => !_disposed && run == _generation;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> next() async {
    if (busy || _disposed) return;
    final run = ++_generation;
    error = null;
    phase = WifiSetupPhase.preparing;
    _notify();
    try {
      await _transport.prepare();
      if (!_current(run)) return;
      step = WifiSetupStep.device;
    } on ProvisioningException catch (e) {
      if (!_current(run)) return;
      error = e.message;
    } catch (_) {
      if (!_current(run)) return;
      error =
          'Couldn’t start setup. Check your internet connection and try again.';
    }
    if (!_current(run)) return;
    phase = WifiSetupPhase.idle;
    _notify();
  }

  void select(WifiNetwork network) {
    if (busy) return;
    selected = network;
    error = null;
    _notify();
  }

  void clearSelection() {
    if (busy || _disposed) return;
    selected = null;
    error = null;
    _notify();
  }

  Future<void> connectDevice(String key) async {
    if (busy) return;
    if (!isBrowser && !RegExp(r'^[A-Za-z0-9]{16}$').hasMatch(key)) {
      error = 'Enter the 16-character setup key on your device label.';
      _notify();
      return;
    }
    final run = ++_generation;
    phase = WifiSetupPhase.joiningDevice;
    error = null;
    _notify();
    try {
      if (!requiresManualJoin) await _transport.joinHotspot(key);
      if (!_current(run)) return;
      // Joining approval is not proof that the device is reachable.
      Map<String, dynamic>? info;
      final deadline = DateTime.now().add(const Duration(seconds: 25));
      while (_current(run) && DateTime.now().isBefore(deadline)) {
        try {
          info = await _transport.get('/setup/info');
          break;
        } on ProvisioningException {
          rethrow;
        } catch (_) {
          await Future<void>.delayed(pollInterval);
        }
      }
      if (!_current(run)) return;
      if (info == null ||
          !{1, 2}.contains(info['protocol']) ||
          info['protected'] != true ||
          info['id'] is! String ||
          info['name'] is! String ||
          info['token'] is! String ||
          !RegExp(r'^[A-Fa-f0-9]{12}$').hasMatch(info['id'] as String) ||
          !RegExp(r'^[A-Fa-f0-9]{32}$').hasMatch(info['token'] as String)) {
        throw const FormatException('Incompatible device');
      }
      _deviceId = info['id'] as String;
      _name = info['name'] as String;
      _token = info['token'] as String;
      step = WifiSetupStep.network;
      // A previous screen may have closed after sending credentials. Recover
      // the device's transaction before offering to send another one.
      final status = await _transport.get('/setup/status');
      if (!_current(run)) return;
      if (status['id'] != _deviceId) throw const FormatException();
      if (status['state'] == 'connected' || status['state'] == 'connecting') {
        final ssid = status['ssid'];
        if (ssid is! String || ssid.isEmpty) throw const FormatException();
        selected = WifiNetwork(ssid: ssid, rssi: -60, secure: true);
        await _waitForHome(run, ssid);
        return;
      }
      phase = WifiSetupPhase.idle;
      await scan();
    } on ProvisioningException catch (e) {
      if (!_current(run)) return;
      error = e.message;
      phase = WifiSetupPhase.idle;
      _notify();
    } on MissingPluginException {
      if (!_current(run)) return;
      requiresManualJoin = true;
      error =
          'Join Dentra Cam in Wi-Fi settings using its setup key, then return and tap Check device connection.';
      phase = WifiSetupPhase.idle;
      _notify();
    } on PlatformException catch (e) {
      if (!_current(run)) return;
      if (e.code == 'unsupported') requiresManualJoin = true;
      error = switch (e.code) {
        'permission' =>
          'Allow nearby Wi-Fi access, then try again. On older Android phones, also turn on Location.',
        'cancelled' => 'Connection cancelled. Tap Connect to try again.',
        'unsupported' =>
          'Join your Dentra Cam in Wi-Fi settings using its setup key, then return and try again.',
        _ =>
          'Keep your device nearby and powered on. Check its setup key and try again.',
      };
      phase = WifiSetupPhase.idle;
      _notify();
    } catch (_) {
      if (!_current(run)) return;
      error = isBrowser
          ? 'Couldn’t reach your device. Join its Dentra Cam Wi-Fi in system settings, return to this tab, and allow Local network access. Use current Chrome or Edge on Android or a computer. Your device needs browser-setup firmware.'
          : 'Couldn’t reach your device. Keep it nearby, allow local network access, and try again. The device needs the latest setup firmware.';
      phase = WifiSetupPhase.idle;
      _notify();
    }
  }

  Future<void> scan() async {
    if (busy) return;
    final run = _generation;
    phase = WifiSetupPhase.scanning;
    error = null;
    _notify();
    try {
      final body = await _transport.get('/setup/networks');
      if (!_current(run)) return;
      final event = parseSetupEvent(jsonEncode({'type': 'networks', ...body}));
      if (event is! NetworksEvent) throw const FormatException();
      networks = WifiNetwork.strongestFirst(event.networks);
      if (networks.isEmpty) {
        error =
            'No networks found. Move closer to your router and look again. Use 2.4 GHz Wi-Fi.';
      }
    } catch (_) {
      if (!_current(run)) return;
      error =
          'Lost contact with your device. Reconnect to Dentra Wi-Fi, then look again.';
    } finally {
      if (_current(run)) {
        phase = WifiSetupPhase.idle;
        _notify();
      }
    }
  }

  Future<void> joinHome(String password) async {
    final network = selected;
    if (busy || network == null) return;
    final bytes = utf8.encode(password).length;
    if (network.secure && (bytes < 8 || bytes > 63)) {
      error = 'Enter a Wi-Fi password between 8 and 63 bytes.';
      _notify();
      return;
    }
    final run = ++_generation;
    error = null;
    phase = WifiSetupPhase.joiningHome;
    _notify();
    try {
      try {
        await _transport.post('/setup/join', {
          'ssid': network.ssid,
          'password': network.secure ? password : '',
          'token': _token!,
        });
      } on ProvisioningException {
        rethrow;
      } catch (_) {/* The AP can change channel as the station joins. Poll. */}
      if (!_current(run)) return;
      await _waitForHome(run, network.ssid);
    } on ProvisioningException catch (e) {
      if (!_current(run)) return;
      error = e.message;
      phase = WifiSetupPhase.idle;
      _notify();
    } catch (_) {
      if (!_current(run)) return;
      error = 'Setup was interrupted. Reconnect to your device and try again.';
      phase = WifiSetupPhase.idle;
      _notify();
    }
  }

  Future<void> _waitForHome(int run, String ssid) async {
    phase = WifiSetupPhase.joiningHome;
    _notify();
    final deadline = DateTime.now().add(joinTimeout);
    while (_current(run) && DateTime.now().isBefore(deadline)) {
      Map<String, dynamic>? status;
      try {
        status = await _transport.get('/setup/status');
      } catch (_) {}
      if (!_current(run)) return;
      if (status?['id'] == _deviceId && status?['ssid'] == ssid) {
        if (status?['state'] == 'failed') {
          error = switch (status?['error']) {
            'wrong_password' =>
              'That password didn’t work. Check it and try again.',
            'ssid_not_found' =>
              'Your device can’t find this network. Move it closer to your 2.4 GHz router.',
            _ =>
              'Your device couldn’t join. Check your router and password, then try again.',
          };
          phase = WifiSetupPhase.idle;
          _notify();
          return;
        }
        final ip = status?['ip'];
        if (status?['state'] == 'connected' && ip is String && isIpv4(ip)) {
          _ip = ip;
          await _finish(run);
          return;
        }
      }
      await Future<void>.delayed(pollInterval);
    }
    if (!_current(run)) return;
    if (linksAccount) {
      // The radio may have moved channels before the phone read its DHCP
      // reply. Release the temporary network and let the live relay prove it.
      await _finish(run);
      return;
    }
    error =
        'We lost the setup connection. Reconnect to your device to check its progress.';
    phase = WifiSetupPhase.idle;
    _notify();
  }

  Future<void> _finish(int run) async {
    phase = WifiSetupPhase.returningHome;
    step = WifiSetupStep.finish;
    _notify();
    try {
      await _transport.post('/setup/finish', {'token': _token!});
    } catch (_) {
      // Firmware also hands over after a bounded acknowledgement window.
    }
    if (!_current(run)) return;
    try {
      await _transport.leaveHotspot();
    } catch (_) {
      // Verification still gives the user a recoverable outcome if the OS
      // cannot release its temporary request immediately.
    }
    if (!_current(run)) return;
    await _verify(run);
  }

  /// Retry verification without sending credentials or resetting the device.
  Future<void> verify() async {
    if (busy || (_ip == null && !linksAccount)) return;
    final run = ++_generation;
    phase = WifiSetupPhase.verifying;
    error = null;
    _notify();
    try {
      await _transport.leaveHotspot();
      await _verify(run);
    } catch (_) {
      if (_current(run)) {
        phase = WifiSetupPhase.idle;
        error = 'Return to your home Wi-Fi and try again.';
        _notify();
      }
    }
  }

  Future<void> _verify(int run) async {
    if (!_current(run)) return;
    phase = WifiSetupPhase.verifying;
    error = null;
    _notify();
    final deadline = DateTime.now().add(verifyTimeout);
    var host = _ip ?? '';
    var discoverNext = false;
    while (_current(run) && DateTime.now().isBefore(deadline)) {
      try {
        if (discoverNext) {
          final discovered = await _transport.discover(_deviceId!);
          if (discovered != null && isIpv4(discovered)) host = discovered;
        }
        if (!_current(run)) return;
        final status = await _transport.cameraStatus(host);
        if (!_current(run)) return;
        if (status['id'] == _deviceId && status['camera_ok'] == true) {
          final verified = await _transport.finalizeCamera(
              host: host.isEmpty ? null : host,
              name: _name!,
              ssid: selected?.ssid);
          if (!_current(run)) return;
          await _onSaved(verified);
          if (!_current(run)) return;
          saved = verified;
          phase = WifiSetupPhase.ready;
          _notify();
          return;
        }
      } on ProvisioningException catch (e) {
        if (!_current(run)) return;
        phase = WifiSetupPhase.idle;
        error = e.message;
        _notify();
        return;
      } catch (_) {/* DHCP/mDNS and OS Wi-Fi handoff can take time. */}
      discoverNext = !discoverNext;
      await Future<void>.delayed(pollInterval);
    }
    if (!_current(run)) return;
    phase = WifiSetupPhase.idle;
    error = linksAccount
        ? 'Return to home Wi-Fi or mobile data, then tap Check connection. Keep your camera powered on. If it still cannot connect, close setup and retry with your device key.'
        : 'Your device joined Wi-Fi. Connect this phone to the same home network, then tap Check connection. You don’t need to enter the password again.';
    _notify();
  }

  /// On return, recover a successful join even if the phone missed its reply.
  Future<void> resume() async {
    if (busy || _disposed) return;
    if (step == WifiSetupStep.finish && saved == null) {
      await verify();
      return;
    }
    if (step != WifiSetupStep.network) return;
    final run = _generation;
    try {
      final status = await _transport.get('/setup/status');
      if (!_current(run) || busy || status['id'] != _deviceId) return;
      final ip = status['ip'];
      if (status['state'] == 'connected' && ip is String && isIpv4(ip)) {
        _ip = ip;
        await _finish(++_generation);
      }
    } catch (_) {/* Keep the user's selection and show retry controls. */}
  }

  Future<void> reconnect() async {
    if (busy) return;
    ++_generation;
    try {
      await _transport.leaveHotspot();
    } catch (_) {}
    if (_disposed) return;
    step = WifiSetupStep.device;
    phase = WifiSetupPhase.idle;
    error = null;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_transport.leaveHotspot().catchError((_) {}));
    _transport.close();
    super.dispose();
  }
}
