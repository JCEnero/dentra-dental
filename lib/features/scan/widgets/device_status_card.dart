import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../providers/device_connection_provider.dart';
import '../services/dentra_device_service.dart';
import 'scan_motion.dart';

/// Shows the device's real connection state. The card lights up with the
/// brand gradient only while a connection is active or being made.
class DeviceStatusCard extends StatelessWidget {
  const DeviceStatusCard({
    super.key,
    required this.state,
    required this.onConnect,
    required this.onCancel,
  });

  final DeviceConnectionState state;
  final VoidCallback onConnect;
  final VoidCallback onCancel;

  bool get _active =>
      state.status == DeviceStatus.connecting ||
      state.status == DeviceStatus.connected ||
      state.status == DeviceStatus.reconnecting;

  @override
  Widget build(BuildContext context) {
    final copy = _DeviceCopy.of(state);
    final duration = ScanMotion.of(context, ScanMotion.slow);
    final onColor = _active ? AppColors.white : AppColors.navy;
    final subColor = _active
        ? AppColors.white.withValues(alpha: 0.82)
        : AppColors.secondaryText;

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'DENTRA device. ${copy.title}. ${copy.body}',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter.grouped(
          filter: AppGlass.blur,
          child: AnimatedContainer(
            duration: duration,
            curve: ScanMotion.curve,
            decoration: AppGlass.surface(
              borderRadius: BorderRadius.circular(20),
              tint: AppColors.lightLavender,
              borderColor: _active ? Colors.transparent : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _active ? 1 : 0,
                      duration: duration,
                      curve: ScanMotion.curve,
                      child: const DecoratedBox(
                        decoration:
                            BoxDecoration(gradient: AppColors.cardGradient),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                      children: [
                        ExcludeSemantics(
                          child: _DeviceEmblem(
                              status: state.status, onActive: _active),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ExcludeSemantics(
                            child: AnimatedSwitcher(
                              duration:
                                  ScanMotion.of(context, ScanMotion.medium),
                              transitionBuilder: ScanMotion.fadeRise,
                              layoutBuilder: (current, previous) => Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  ...previous,
                                  if (current != null) current
                                ],
                              ),
                              child: Column(
                                key: ValueKey(
                                    '${state.status}-${state.failure}-${state.isSlow}'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'DENTRA DEVICE',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: _active
                                          ? AppColors.white
                                              .withValues(alpha: 0.75)
                                          : AppColors.secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    copy.title,
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: onColor,
                                      height: 1.25,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    copy.body,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12.5,
                                      color: subColor,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (copy.action != null) ...[
                          const SizedBox(width: 10),
                          _CardAction(
                            label: copy.action!,
                            onActive: _active,
                            onTap: state.status == DeviceStatus.connecting ||
                                    state.status == DeviceStatus.reconnecting
                                ? onCancel
                                : onConnect,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceCopy {
  const _DeviceCopy(this.title, this.body, [this.action]);
  final String title;
  final String body;
  final String? action;

  static _DeviceCopy of(DeviceConnectionState s) {
    switch (s.status) {
      case DeviceStatus.unsupported:
        return const _DeviceCopy(
          'Not available yet',
          "Pairing isn't in this version. Use your phone camera for now.",
        );
      case DeviceStatus.disconnected:
        return const _DeviceCopy(
          'Not connected',
          'Turn on your device and keep it nearby.',
          'Connect',
        );
      case DeviceStatus.connecting:
        return _DeviceCopy(
          'Connecting to device…',
          s.isSlow
              ? 'This is taking longer than usual. Keep the device close.'
              : 'Keep the device nearby.',
          'Cancel',
        );
      case DeviceStatus.connected:
        return const _DeviceCopy('Connected', 'Ready to capture.');
      case DeviceStatus.reconnecting:
        return const _DeviceCopy(
          'Reconnecting…',
          'Your captured images are safe.',
          'Cancel',
        );
      case DeviceStatus.failed:
        return switch (s.failure) {
          DeviceFailure.notFound => const _DeviceCopy(
              'Device not found',
              "Make sure it's turned on and nearby.",
              'Try again',
            ),
          DeviceFailure.timeout => const _DeviceCopy(
              'Connection timed out',
              "The device didn't respond. Check that it's on.",
              'Try again',
            ),
          DeviceFailure.connectionLost => const _DeviceCopy(
              'Connection lost',
              'Your captured images are safe.',
              'Reconnect',
            ),
          _ => const _DeviceCopy(
              "Couldn't connect",
              'Something went wrong. Please try again.',
              'Try again',
            ),
        };
    }
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.onActive,
    required this.onTap,
  });

  final String label;
  final bool onActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label == 'Cancel' ? 'Cancel device connection' : '$label device',
      excludeSemantics: true,
      child: Material(
        color: onActive
            ? AppColors.white.withValues(alpha: 0.22)
            : AppColors.white,
        shape: StadiumBorder(
          side: BorderSide(
            color: onActive ? Colors.transparent : AppColors.lavender,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: onActive ? AppColors.white : AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glass orb holding a slim intraoral wand. Rings pulse only while a
/// connection attempt is actually running; a single ring marks success.
class _DeviceEmblem extends StatefulWidget {
  const _DeviceEmblem({required this.status, required this.onActive});

  final DeviceStatus status;
  final bool onActive;

  @override
  State<_DeviceEmblem> createState() => _DeviceEmblemState();
}

class _DeviceEmblemState extends State<_DeviceEmblem>
    with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _success = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool get _pending =>
      widget.status == DeviceStatus.connecting ||
      widget.status == DeviceStatus.reconnecting;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync(null);
  }

  @override
  void didUpdateWidget(_DeviceEmblem old) {
    super.didUpdateWidget(old);
    _sync(old.status);
  }

  void _sync(DeviceStatus? previous) {
    final reduced = ScanMotion.reduced(context);
    if (_pending && !reduced) {
      if (!_pulse.isAnimating) _pulse.repeat();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
    if (widget.status == DeviceStatus.connected &&
        previous != null &&
        previous != DeviceStatus.connected &&
        !reduced) {
      _success.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _success.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 60,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulse, _success]),
          builder: (context, _) => CustomPaint(
            painter: _EmblemPainter(
              status: widget.status,
              onActive: widget.onActive,
              pulse: _pending ? _pulse.value : null,
              success: _success.isAnimating ? _success.value : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  const _EmblemPainter({
    required this.status,
    required this.onActive,
    required this.pulse,
    required this.success,
  });

  final DeviceStatus status;
  final bool onActive;
  final double? pulse;
  final double? success;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 4;

    void ring(double t) {
      canvas.drawCircle(
        c,
        r * (1 + 0.32 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.white.withValues(alpha: 0.7 * (1 - t)),
      );
    }

    if (pulse != null) {
      ring(pulse!);
      ring((pulse! + 0.5) % 1.0);
    }
    if (success != null) ring(Curves.easeOut.transform(success!));

    // Orb
    canvas.drawCircle(
      c.translate(0, 2),
      r,
      Paint()
        ..color = AppColors.g2.withValues(alpha: onActive ? 0.25 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: onActive
              ? [
                  AppColors.white.withValues(alpha: 0.42),
                  AppColors.white.withValues(alpha: 0.16),
                ]
              : const [AppColors.white, AppColors.white],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = onActive
            ? AppColors.white.withValues(alpha: 0.5)
            : AppColors.lavender,
    );

    _paintWand(canvas, c, r);
  }

  void _paintWand(Canvas canvas, Offset c, double r) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-math.pi / 4);
    final len = r * 1.5;
    const half = 5.0;

    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-len / 2, -half, len * 0.62, half * 2),
        const Radius.circular(half),
      ))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(
            -len / 2 + len * 0.55, -half * 0.55, len * 0.32, half * 1.1),
        const Radius.circular(3),
      ))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(len / 2 - len * 0.2, -half * 0.8, len * 0.2, half * 1.6),
        const Radius.circular(4),
      ));

    canvas.drawPath(
      body.shift(const Offset(1.2, 2)),
      Paint()
        ..color = AppColors.navy.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    final bounds = body.getBounds();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.white,
            AppColors.offWhite,
            Color.lerp(AppColors.border, AppColors.secondaryText, 0.25)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(bounds),
    );
    canvas.drawPath(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = AppColors.navy.withValues(alpha: 0.14),
    );

    // Lens on the head.
    canvas.drawCircle(
      Offset(len / 2 - len * 0.1, 0),
      2.2,
      Paint()..color = AppColors.navy.withValues(alpha: 0.75),
    );

    // Status light reflects the real state.
    final light = switch (status) {
      DeviceStatus.connected => AppColors.g1,
      DeviceStatus.connecting ||
      DeviceStatus.reconnecting =>
        AppColors.g1.withValues(alpha: 0.45 + 0.55 * (1 - (pulse ?? 0))),
      DeviceStatus.failed => AppColors.coral,
      _ => AppColors.border,
    };
    canvas.drawCircle(
      Offset(-len * 0.12, 0),
      2.1,
      Paint()..color = light,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EmblemPainter old) =>
      old.status != status ||
      old.onActive != onActive ||
      old.pulse != pulse ||
      old.success != success;
}
