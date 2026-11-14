import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_glass.dart';
import '../../../core/constants/map_style.dart';
import '../../../core/services/maps_loader.dart';
import '../../clinic_finder/data/models/clinic_model.dart';
import '../../clinic_finder/providers/clinic_provider.dart';
import 'clinic_ui.dart';

/// Brand-styled Google Map for the clinic list: pins with each clinic's
/// initials, matching the list cards, the search radius, and the user's position.
///
/// Runs on google_maps_flutter, so Android and iOS use the native Maps
/// SDK and web uses the Maps JavaScript API. Pins are drawn on a canvas
/// once and cached, so they look the same everywhere.
///
/// Anything laid over the map uses a plain translucent fill, never a
/// backdrop blur: blur over a platform view is costly on Android and
/// reads stale pixels on web.
class ClinicMap extends StatefulWidget {
  const ClinicMap({
    super.key,
    required this.clinics,
    required this.center,
    required this.radiusKm,
    required this.showUser,
    this.selectedId,
    this.onClinicTap,
    this.onMapTap,
    this.overlay,
  });

  /// Clinics to pin.
  final List<ClinicModel> clinics;

  /// Where distances are measured from (the user, or the default area).
  final UserLocation center;
  final double radiusKm;

  /// True once the device location is known, so the "you" dot is real.
  final bool showUser;

  /// Clinic whose pin is drawn highlighted.
  final String? selectedId;
  final ValueChanged<ClinicModel>? onClinicTap;

  /// Tap on the map itself, away from any pin.
  final VoidCallback? onMapTap;

  /// Control pinned to the bottom-right corner, e.g. a locate button.
  final Widget? overlay;

  @override
  State<ClinicMap> createState() => _ClinicMapState();
}

class _ClinicMapState extends State<ClinicMap> {
  // On web the Maps JavaScript API has to be loaded before the map builds.
  late final Future<void> _mapsReady = ensureMapsLoaded();

  GoogleMapController? _controller;

  /// Rendered pins keyed by [_pinKey], plus `user` for the location dot.
  final Map<String, BitmapDescriptor> _icons = {};
  double? _iconPixelRatio;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ratio = MediaQuery.devicePixelRatioOf(context);
    if (ratio != _iconPixelRatio) {
      _iconPixelRatio = ratio;
      _icons.clear();
      _renderIcons();
    }
  }

  @override
  void didUpdateWidget(covariant ClinicMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-sorting keeps the same clinics, so it shouldn't move the camera.
    final idsChanged = !setEquals(
      {for (final c in oldWidget.clinics) c.id},
      {for (final c in widget.clinics) c.id},
    );
    if (idsChanged ||
        oldWidget.center != widget.center ||
        oldWidget.radiusKm != widget.radiusKm) {
      _renderIcons();
      _fitCamera();
    }

    final selected = _selectedClinic;
    if (selected != null && selected.id != oldWidget.selectedId) {
      _animate(CameraUpdate.newLatLng(_latLng(selected)));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  ClinicModel? get _selectedClinic {
    for (final c in widget.clinics) {
      if (c.id == widget.selectedId) return c;
    }
    return null;
  }

  static String _pinKey(String initials, bool selected) =>
      '$initials|$selected';

  static LatLng _latLng(ClinicModel c) => LatLng(c.latitude, c.longitude);

  LatLng get _centerLatLng =>
      LatLng(widget.center.latitude, widget.center.longitude);

  /// Zoom that roughly fits the search radius in a phone-width map.
  double get _radiusZoom =>
      (15 - math.log(widget.radiusKm) / math.ln2).clamp(10.0, 16.0);

  /// Draws any pins that aren't cached yet, then repaints.
  Future<void> _renderIcons() async {
    final ratio = _iconPixelRatio;
    if (ratio == null) return;

    final pending = <String, Future<BitmapDescriptor>>{
      if (!_icons.containsKey('user')) 'user': _renderUserDot(ratio),
      for (final initials in {
        for (final c in widget.clinics) clinicInitials(c.name),
      })
        for (final selected in const [false, true])
          if (!_icons.containsKey(_pinKey(initials, selected)))
            _pinKey(initials, selected): _renderPin(initials, selected, ratio),
    };
    if (pending.isEmpty) return;

    final rendered = await Future.wait(pending.values);
    if (!mounted || ratio != _iconPixelRatio) return;
    setState(() => _icons.addAll(Map.fromIterables(pending.keys, rendered)));
  }

  /// Frames every clinic plus the center; falls back to the radius
  /// when there are no clinics to show.
  void _fitCamera() {
    final points = [_centerLatLng, ...widget.clinics.map(_latLng)];
    if (points.length == 1) {
      _animate(CameraUpdate.newLatLngZoom(_centerLatLng, _radiusZoom));
      return;
    }

    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final p in points.skip(1)) {
      south = math.min(south, p.latitude);
      north = math.max(north, p.latitude);
      west = math.min(west, p.longitude);
      east = math.max(east, p.longitude);
    }
    _animate(CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(south, west),
        northeast: LatLng(north, east),
      ),
      44,
    ));
  }

  Future<void> _animate(CameraUpdate update) async {
    try {
      await _controller?.animateCamera(update);
    } catch (_) {
      // The map can reject bounds before it has a size; the next
      // update reframes it.
    }
  }

  Set<Marker> _markers() {
    final markers = <Marker>{};
    for (final clinic in widget.clinics) {
      final selected = clinic.id == widget.selectedId;
      final icon = _icons[_pinKey(clinicInitials(clinic.name), selected)];
      // Skip until the branded pin is drawn, so default pins never flash.
      if (icon == null) continue;
      markers.add(Marker(
        markerId: MarkerId(clinic.id),
        position: _latLng(clinic),
        icon: icon,
        anchor: _pinAnchor(selected),
        zIndexInt: selected ? 2 : 1,
        // The list card is the info view, so skip the native info window
        // and camera jump, which differ between platforms.
        consumeTapEvents: true,
        onTap: () => widget.onClinicTap?.call(clinic),
      ));
    }

    final userIcon = _icons['user'];
    if (widget.showUser && userIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('user_location'),
        position: _centerLatLng,
        icon: userIcon,
        anchor: const Offset(0.5, 0.5),
        consumeTapEvents: true,
      ));
    }
    return markers;
  }

  Set<Circle> _circles() => {
        Circle(
          circleId: const CircleId('search_radius'),
          center: _centerLatLng,
          radius: widget.radiusKm * 1000,
          fillColor: AppColors.g2.withValues(alpha: 0.06),
          strokeColor: AppColors.g2.withValues(alpha: 0.35),
          strokeWidth: 1,
        ),
      };

  @override
  Widget build(BuildContext context) {
    final count = widget.clinics.length;
    return Semantics(
      label: 'Map of $count nearby ${count == 1 ? 'clinic' : 'clinics'}. '
          'The same clinics are listed below.',
      child: DecoratedBox(
        decoration: const BoxDecoration(color: AppColors.lightLavender),
        position: DecorationPosition.background,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<void>(
              future: _mapsReady,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const _MapUnavailable();
                if (snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                // Google can reject the key after the map is built; swap
                // its grey error box for the app's own placeholder.
                return ValueListenableBuilder<bool>(
                  valueListenable: mapsAuthFailed,
                  builder: (context, failed, map) =>
                      failed ? const _MapUnavailable() : map!,
                  child: _buildMap(),
                );
              },
            ),
            if (widget.overlay != null)
              Positioned(right: 10, bottom: 10, child: widget.overlay!),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() => GoogleMap(
        initialCameraPosition: CameraPosition(
          target: _centerLatLng,
          zoom: _radiusZoom,
        ),
        style: mapStyle,
        markers: _markers(),
        circles: _circles(),
        onMapCreated: (controller) {
          _controller = controller;
          _fitCamera();
        },
        onTap: (_) => widget.onMapTap?.call(),
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        // The web map's own camera controls clash with the UI.
        webCameraControlEnabled: false,
      );
}

/// Shown in place of the map when the Maps SDK can't load (no key, offline).
class _MapUnavailable extends StatelessWidget {
  const _MapUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined,
              size: 18, color: AppColors.secondaryText),
          const SizedBox(width: 8),
          Text(
            'Map unavailable',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pin drawing ───────────────────────────────────────────────────

/// Room around each pin for its soft shadow, in logical pixels.
const double _kPinShadow = 4;

/// Distance from the pin head's center to its tip, in head radii.
const double _kPinTip = 1.55;

/// Head size (diameter) of a pin, in logical pixels.
double _pinHead(bool selected) => selected ? 38.0 : 32.0;

/// Where the pin's tip sits in its image, as a marker anchor, so the
/// tip (not the middle of the icon) points at the clinic.
Offset _pinAnchor(bool selected) {
  final r = _pinHead(selected) / 2;
  final height = r + r * _kPinTip + _kPinShadow * 2;
  return Offset(0.5, (_kPinShadow + r + r * _kPinTip) / height);
}

/// Teardrop around a round head of radius [r] at [center], tapering to
/// a point [tip] below it.
Path _teardrop(Offset center, double r, double tip) {
  // The sides meet the head where they're tangent to it.
  final cosB = r / tip;
  final sinB = math.sqrt(1 - cosB * cosB);
  final point = center + Offset(0, tip);
  return Path.combine(
    PathOperation.union,
    Path()..addOval(Rect.fromCircle(center: center, radius: r)),
    Path()
      ..moveTo(center.dx - r * sinB, center.dy + r * cosB)
      ..lineTo(point.dx, point.dy)
      ..lineTo(center.dx + r * sinB, center.dy + r * cosB)
      ..close(),
  );
}

/// Map marker with the clinic's initials in its head, matching its list
/// tile: soft mint, or the teal card gradient when selected. Sized in
/// logical pixels and drawn at [pixelRatio].
Future<BitmapDescriptor> _renderPin(
  String label,
  bool selected,
  double pixelRatio,
) {
  final r = _pinHead(selected) / 2;
  final size = Size(
    r * 2 + _kPinShadow * 2,
    r + r * _kPinTip + _kPinShadow * 2,
  );
  return _paintIcon(size, pixelRatio, (canvas, _) {
    final head = Offset(size.width / 2, _kPinShadow + r);
    final outer = _teardrop(head, r, r * _kPinTip);
    // Inset by the rim width, keeping the same tip angle.
    const rim = 2.0;
    final inner = _teardrop(head, r - rim, (r - rim) * _kPinTip);

    canvas
      ..drawPath(
        outer.shift(const Offset(0, 1.5)),
        Paint()
          ..color = AppColors.navy.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      )
      // White rim keeps the pin readable on any part of the map.
      ..drawPath(outer, Paint()..color = AppColors.white)
      ..drawPath(
        inner,
        Paint()
          ..shader = (selected
                  ? AppColors.cardGradient
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.white,
                        AppColors.mintGreen.withValues(alpha: 0.75),
                      ],
                    ))
              .createShader(inner.getBounds()),
      );

    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: GoogleFonts.outfit(
          fontSize: selected ? 14 : 12,
          fontWeight: FontWeight.w800,
          color: selected ? AppColors.white : AppColors.g2,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, head - Offset(text.width / 2, text.height / 2));
    text.dispose();
  });
}

/// "You are here" dot: navy center, white rim and a soft mint halo.
Future<BitmapDescriptor> _renderUserDot(double pixelRatio) {
  return _paintIcon(const Size.square(32), pixelRatio, (canvas, c) {
    canvas
      ..drawCircle(c, 15, Paint()..color = AppColors.g1.withValues(alpha: 0.28))
      ..drawCircle(c, 8.5, Paint()..color = AppColors.white)
      ..drawCircle(c, 6, Paint()..color = AppColors.navy)
      ..drawCircle(
        c,
        8.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppGlass.divider,
      );
  });
}

/// Paints an icon of [size] logical pixels and wraps it as a marker
/// bitmap that keeps that logical size on every platform.
Future<BitmapDescriptor> _paintIcon(
  Size size,
  double pixelRatio,
  void Function(Canvas canvas, Offset center) paint,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  paint(canvas, size.center(Offset.zero));

  final image = await recorder.endRecording().toImage(
        (size.width * pixelRatio).ceil(),
        (size.height * pixelRatio).ceil(),
      );
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  return BitmapDescriptor.bytes(
    png!.buffer.asUint8List(),
    width: size.width,
    height: size.height,
  );
}
