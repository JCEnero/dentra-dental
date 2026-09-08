import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/mock_data.dart';
import '../../../shared/widgets/primary_button.dart';

// ── Scan state machine ─────────────────────────────────────────

enum ScanState {
  idle,
  preparing,
  deviceCheck,
  regionSelection,
  positioning,
  countdown,
  qualityCheck,
  qualityFailed,
  regionComplete,
  scanSummary,
  analyzing,
  complete,
}

// ── Dental guide painter ───────────────────────────────────────

class _DentalGuidePainter extends CustomPainter {
  final bool isPosterior;
  const _DentalGuidePainter({required this.isPosterior});

  @override
  void paint(Canvas canvas, Size size) {
    final archPaint = Paint()
      ..color = const Color(0xFFB4AAFF).withValues(alpha: 0.45)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bracketPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final crosshairPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;

    // Arch
    if (isPosterior) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, h / 2),
          width: w * 0.62,
          height: h * 0.46,
        ),
        archPaint,
      );
    } else {
      final archPath = Path()
        ..moveTo(w * 0.25, h * 0.75)
        ..cubicTo(w * 0.25, h * 0.43, w * 0.36, h * 0.21, w / 2, h * 0.2)
        ..cubicTo(w * 0.64, h * 0.21, w * 0.75, h * 0.43, w * 0.75, h * 0.75);
      canvas.drawPath(archPath, archPaint);
    }

    // Corner brackets
    const bl = 18.0; // bracket length
    final corners = [
      [const Offset(16, 16), const Offset(16 + bl, 16), const Offset(16, 16 + bl)],
      [Offset(w - 16, 16), Offset(w - 16 - bl, 16), Offset(w - 16, 16 + bl)],
      [Offset(16, h - 16), Offset(16 + bl, h - 16), Offset(16, h - 16 - bl)],
      [Offset(w - 16, h - 16), Offset(w - 16 - bl, h - 16), Offset(w - 16, h - 16 - bl)],
    ];
    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], bracketPaint);
      canvas.drawLine(corner[0], corner[2], bracketPaint);
    }

    // Crosshair
    final cx = w / 2;
    final cy = h / 2;
    canvas.drawLine(Offset(cx - 6, cy), Offset(cx + 6, cy), crosshairPaint);
    canvas.drawLine(Offset(cx, cy - 6), Offset(cx, cy + 6), crosshairPaint);
  }

  @override
  bool shouldRepaint(_DentalGuidePainter old) => old.isPosterior != isPosterior;
}

// ── Main Scan Screen ───────────────────────────────────────────

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with TickerProviderStateMixin {
  ScanState _state = ScanState.idle;
  String _selectedRegion = 'ur';
  List<String> _capturedRegions = [];
  bool _checkedItems = false;
  int _countdown = 3;
  bool _positionOk = false;
  double _analysisProgress = 0.0;
  bool _showExitSheet = false;

  Timer? _timer;
  late AnimationController _scanLineController;

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scanLineController.dispose();
    super.dispose();
  }

  void _setState(ScanState next) {
    _timer?.cancel();
    setState(() => _state = next);
    _onEnterState(next);
  }

  void _onEnterState(ScanState s) {
    switch (s) {
      case ScanState.deviceCheck:
        _timer = Timer(const Duration(milliseconds: 2600), () {
          if (mounted) setState(() => _checkedItems = true);
        });
        break;
      case ScanState.positioning:
        setState(() => _positionOk = false);
        _timer = Timer(const Duration(milliseconds: 2000), () {
          if (mounted) setState(() => _positionOk = true);
        });
        break;
      case ScanState.countdown:
        setState(() => _countdown = 3);
        var c = 3;
        _timer = Timer.periodic(const Duration(milliseconds: 700), (t) {
          c--;
          if (mounted) setState(() => _countdown = c);
          if (c <= 0) {
            t.cancel();
            _setState(ScanState.qualityCheck);
          }
        });
        break;
      case ScanState.analyzing:
        setState(() => _analysisProgress = 0.0);
        _timer = Timer.periodic(const Duration(milliseconds: 140), (t) {
          if (mounted) {
            setState(() => _analysisProgress += 5);
          }
          if (_analysisProgress >= 100) {
            t.cancel();
            _setState(ScanState.complete);
          }
        });
        break;
      default:
        break;
    }
  }

  void _handleQualityPass() {
    final next = [..._capturedRegions, _selectedRegion];
    setState(() => _capturedRegions = next);
    if (next.length >= MockData.scanRegions.length) {
      _setState(ScanState.scanSummary);
    } else {
      _setState(ScanState.regionComplete);
    }
  }

  void _handleContinueScan() {
    final next = MockData.scanRegions.firstWhere(
      (r) => !_capturedRegions.contains(r['id']),
      orElse: () => MockData.scanRegions.first,
    );
    setState(() => _selectedRegion = next['id']!);
    _setState(ScanState.positioning);
  }

  void _handleReset() {
    setState(() {
      _capturedRegions = [];
      _selectedRegion = 'ur';
      _analysisProgress = 0;
      _checkedItems = false;
    });
    _setState(ScanState.idle);
  }

  Map<String, String> get _currentRegion =>
      MockData.scanRegions.firstWhere((r) => r['id'] == _selectedRegion);

  @override
  Widget build(BuildContext context) {
    Widget screen;
    switch (_state) {
      case ScanState.idle:
        screen = _buildIdle();
        break;
      case ScanState.preparing:
        screen = _buildPreparing();
        break;
      case ScanState.deviceCheck:
        screen = _buildDeviceCheck();
        break;
      case ScanState.regionSelection:
        screen = _buildRegionSelection();
        break;
      case ScanState.positioning:
      case ScanState.countdown:
        screen = _buildPositioning();
        break;
      case ScanState.qualityCheck:
      case ScanState.qualityFailed:
        screen = _buildQualityCheck();
        break;
      case ScanState.regionComplete:
        screen = _buildRegionComplete();
        break;
      case ScanState.scanSummary:
        screen = _buildScanSummary();
        break;
      case ScanState.analyzing:
        screen = _buildAnalyzing();
        break;
      case ScanState.complete:
        screen = _buildComplete();
        break;
    }
    return SizedBox.expand(child: screen);
  }

  // ── IDLE ────────────────────────────────────────────────────

  Widget _buildIdle() {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.pageBackground),
      child: Column(
        children: [
          // Hero header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            padding: const EdgeInsets.fromLTRB(24, 52, 24, 32),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DENTRA',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Dental Scan',
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture guided images\nwith your DENTRA device.',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.6),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 8,
                    children: ['5 regions', 'Guided positioning', 'AI-assisted']
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              t,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Device status card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardDeep,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.20),
                          blurRadius: 0,
                          spreadRadius: -1,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DENTRA NIR DEVICE',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 8, height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Ready',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Row(
                          children: [
                            _MiniStat(
                              icon: Icons.battery_5_bar_rounded,
                              label: '86%',
                            ),
                            SizedBox(width: 16),
                            _MiniStat(
                              icon: Icons.wifi_rounded,
                              label: 'Strong',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Disclaimer
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.lightLavender,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14,
                            color: AppColors.primary.withValues(alpha: 0.8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'DENTRA provides AI-assisted screening information and does not replace professional dental evaluation.',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: AppColors.primary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  PrimaryButton(
                    label: 'Start Scan',
                    onTap: () => _setState(ScanState.preparing),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PREPARING ───────────────────────────────────────────────

  Widget _buildPreparing() {
    final steps = [
      {'n': '01', 'label': 'Connect device', 'sub': 'Ensure DENTRA is powered on and nearby'},
      {'n': '02', 'label': 'Position the camera', 'sub': 'Follow the on-screen dental guide'},
      {'n': '03', 'label': 'Capture each region', 'sub': 'Scan up to 5 areas of the mouth'},
    ];
    return _GradientScaffold(
      title: "Let's prepare your scan",
      subtitle: 'Three quick steps to get started',
      onBack: () => _setState(ScanState.idle),
      body: Column(
        children: [
          ...steps.map((step) => Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.lightLavender,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        step['n']!,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['label']!,
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              step['sub']!,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          Text(
            'Make sure you are in a well-lit area and follow the positioning guide during capture.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: AppColors.secondaryText,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Begin',
            onTap: () => _setState(ScanState.deviceCheck),
          ),
        ],
      ),
    );
  }

  // ── DEVICE CHECK ─────────────────────────────────────────────

  Widget _buildDeviceCheck() {
    final checks = [
      'Device connection',
      'NIR illumination',
      'Camera module',
      'Battery level',
      'Signal strength',
    ];
    return _GradientScaffold(
      title: 'Device check',
      subtitle: 'Making sure everything is ready',
      body: Column(
        children: [
          ...List.generate(checks.length, (i) {
            return _AnimatedCheckItem(
              label: checks[i],
              done: _checkedItems,
              delayMs: i * 420,
            );
          }),
          if (_checkedItems) ...[
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                color: AppColors.lightLavender,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.lavender,
                    ),
                    child: const Icon(Icons.check_rounded,
                        size: 14, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device ready',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      Text(
                        'All systems nominal',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Continue',
              onTap: () => _setState(ScanState.regionSelection),
            ),
          ],
        ],
      ),
    );
  }

  // ── REGION SELECTION ─────────────────────────────────────────

  Widget _buildRegionSelection() {
    return _GradientScaffold(
      title: 'Choose a region',
      subtitle: 'Follow the guided positions to capture the mouth from multiple angles',
      body: Column(
        children: [
          ...MockData.scanRegions.map((r) {
            final id         = r['id']!;
            final isCaptured = _capturedRegions.contains(id);
            final isSelected = _selectedRegion == id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _RegionTile(
                label: r['label']!,
                desc: isCaptured ? 'Captured' : r['desc']!,
                isCaptured: isCaptured,
                isSelected: isSelected,
                onTap: isCaptured ? null : () => setState(() => _selectedRegion = id),
              ),
            );
          }),
          const SizedBox(height: 8),
          PrimaryButton(
            label: 'Position Camera →',
            onTap: () => _setState(ScanState.positioning),
          ),
        ],
      ),
    );
  }

  // ── POSITIONING / COUNTDOWN ──────────────────────────────────

  Widget _buildPositioning() {
    final isPosterior = _selectedRegion == 'po';
    final isCountdown = _state == ScanState.countdown;

    return Stack(
      children: [
        // Dark camera background
        Container(color: const Color(0xFF0D0B1E)),

        // NIR glow
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF645ADC).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Dental guide
        Center(
          child: SizedBox(
            width: 280,
            height: 180,
            child: CustomPaint(
              painter: _DentalGuidePainter(isPosterior: isPosterior),
            ),
          ),
        ),

        // Countdown overlay
        if (isCountdown && _countdown > 0)
          Center(
            child: Text(
              '$_countdown',
              style: GoogleFonts.outfit(
                fontSize: 80,
                fontWeight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.9),
                letterSpacing: -4,
              ),
            ),
          ),

        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  _DarkPill(
                    child: GestureDetector(
                      onTap: () {
                        if (_capturedRegions.isNotEmpty) {
                          setState(() => _showExitSheet = true);
                        } else {
                          _setState(ScanState.regionSelection);
                        }
                      },
                      child: Row(
                        children: [
                          const Icon(Icons.chevron_left_rounded,
                              color: Colors.white, size: 18),
                          Text('Back',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _DarkPill(
                    child: Text(
                      '${_currentRegion['label']} · ${_capturedRegions.length + 1}/${MockData.scanRegions.length}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 70),
                ],
              ),
            ),
          ),
        ),

        // Bottom controls
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xF50D0B1E),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: Column(
              children: [
                // Position feedback
                if (_positionOk) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 7, height: 7,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardSolid,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Good position',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cardSolid,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hold steady',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Align teeth inside the guide',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _positionInstruction(_selectedRegion),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                // Capture button
                Column(
                  children: [
                    GestureDetector(
                      onTap: isCountdown
                          ? null
                          : () => _setState(ScanState.countdown),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCountdown
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.white,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.06),
                              blurRadius: 0,
                              spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Container(
                            width: 46,
                            height: 46,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppColors.primaryGradient,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Capture',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Exit sheet
        if (_showExitSheet) _buildExitSheet(),
      ],
    );
  }

  Widget _buildExitSheet() {
    return GestureDetector(
      onTap: () => setState(() => _showExitSheet = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.6),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave this scan?',
                    style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your captured images from this session may not be saved.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Continue Scanning',
                    onTap: () {
                      setState(() => _showExitSheet = false);
                      _setState(ScanState.regionSelection);
                    },
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: 'Leave Scan',
                    variant: ButtonVariant.secondary,
                    onTap: _handleReset,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── QUALITY CHECK ────────────────────────────────────────────

  Widget _buildQualityCheck() {
    final passed = _state == ScanState.qualityCheck;
    final metrics = ['Sharpness', 'Position', 'Lighting', 'Coverage'];

    return _GradientScaffold(
      title: 'Image quality',
      subtitle: passed
          ? 'Checking whether this image is suitable for screening'
          : "Let's capture that again",
      body: Column(
        children: [
          // Mock captured preview
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1630),
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  Center(
                    child: SizedBox(
                      width: 220, height: 130,
                      child: CustomPaint(
                        painter: _DentalGuidePainter(
                            isPosterior: _selectedRegion == 'po'),
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${_currentRegion['label']} · Captured',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (passed) ...[
            ...List.generate(metrics.length, (i) => _QualityMetricRow(
                  label: metrics[i],
                  progressFraction: 0.85 + i * 0.04,
                )),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: AppColors.lightLavender,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Image looks good — Ready for analysis',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Analyze Image',
              onTap: _handleQualityPass,
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Retake',
              variant: ButtonVariant.secondary,
              onTap: () => _setState(ScanState.positioning),
            ),
          ] else ...[
            Container(
              decoration: BoxDecoration(
                color: AppColors.lightLavender,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The teeth are partially outside the guide',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Try repositioning the camera closer to the target area.',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Try Again',
              onTap: () => _setState(ScanState.positioning),
            ),
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Use Anyway',
              variant: ButtonVariant.secondary,
              onTap: _handleQualityPass,
            ),
          ],
        ],
      ),
    );
  }

  // ── REGION COMPLETE ──────────────────────────────────────────

  Widget _buildRegionComplete() {
    final remaining = MockData.scanRegions.length - _capturedRegions.length;

    return _GradientScaffold(
      title: 'Region captured',
      subtitle: '$remaining region${remaining != 1 ? 's' : ''} remaining',
      body: Column(
        children: [
          ...MockData.scanRegions.map((r) {
            final done = _capturedRegions.contains(r['id']);
            return _RegionProgressRow(label: r['label']!, done: done);
          }),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Continue Scan',
            onTap: _handleContinueScan,
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'Finish Scan',
            variant: ButtonVariant.secondary,
            onTap: () => _setState(ScanState.scanSummary),
          ),
        ],
      ),
    );
  }

  // ── SCAN SUMMARY ─────────────────────────────────────────────

  Widget _buildScanSummary() {
    final allDone = _capturedRegions.length == MockData.scanRegions.length;
    return _GradientScaffold(
      title: 'Scan complete',
      subtitle: '${_capturedRegions.length} image${_capturedRegions.length != 1 ? 's' : ''} ready for analysis',
      body: Column(
        children: [
          ...MockData.scanRegions.map((r) {
            final done = _capturedRegions.contains(r['id']);
            return _ScanSummaryRow(
              label: r['label']!,
              done: done,
            );
          }),
          const SizedBox(height: 24),
          PrimaryButton(
            label: 'Analyze Scan',
            onTap: () => _setState(ScanState.analyzing),
          ),
          if (!allDone) ...[
            const SizedBox(height: 10),
            PrimaryButton(
              label: 'Review & Capture More',
              variant: ButtonVariant.secondary,
              onTap: _handleContinueScan,
            ),
          ],
        ],
      ),
    );
  }

  // ── ANALYZING ────────────────────────────────────────────────

  Widget _buildAnalyzing() {
    final stages = [
      {'label': 'Preparing images',             'threshold': 20.0},
      {'label': 'Detecting teeth',              'threshold': 45.0},
      {'label': 'Localizing teeth',             'threshold': 65.0},
      {'label': 'Identifying visual findings',  'threshold': 85.0},
      {'label': 'Preparing results',            'threshold': 100.0},
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 52, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Analyzing your scan',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_capturedRegions.length} image${_capturedRegions.length != 1 ? 's' : ''} · AI-assisted analysis',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 32),

              // Mock scan preview with animated line
              AnimatedBuilder(
                animation: _scanLineController,
                builder: (_, __) {
                  return Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Stack(
                      children: [
                        Center(
                          child: SizedBox(
                            width: 220,
                            height: 120,
                            child: CustomPaint(
                              painter: _DentalGuidePainter(
                                  isPosterior: _capturedRegions.isNotEmpty &&
                                      _capturedRegions.first == 'po'),
                            ),
                          ),
                        ),
                        // Scanning line
                        Positioned(
                          top: (_analysisProgress / 100) * 108,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  const Color(0xFFB4AAFF).withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),

              ...stages.map((s) {
                final threshold = s['threshold'] as double;
                final done = _analysisProgress >= threshold;
                final active = !done &&
                    _analysisProgress >= threshold - 25;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                        child: Center(
                          child: done
                              ? Icon(Icons.check_rounded,
                                  size: 10,
                                  color: Colors.white.withValues(alpha: 0.9))
                              : active
                                  ? Container(
                                      width: 6, height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.6),
                                      ),
                                    )
                                  : Container(
                                      width: 5, height: 5,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white.withValues(alpha: 0.2),
                                      ),
                                    ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        s['label'] as String,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight:
                              done ? FontWeight.w600 : FontWeight.w400,
                          color: done
                              ? Colors.white.withValues(alpha: 0.9)
                              : active
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      if (active) ...[
                        const SizedBox(width: 4),
                        Text('…',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.4),
                            )),
                      ],
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ── COMPLETE ─────────────────────────────────────────────────

  Widget _buildComplete() {
    return _GradientScaffold(
      title: 'Screening ready',
      subtitle: 'September 7, 2026',
      body: Column(
        children: [
          // Summary card
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardSolid,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.2),
                  blurRadius: 0,
                  spreadRadius: -1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SCAN SUMMARY',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _SummaryMetric(
                      value: '${_capturedRegions.length}',
                      label: 'Images\ncaptured',
                    ),
                    const SizedBox(width: 28),
                    const _SummaryMetric(
                      value: '18',
                      label: 'Teeth\ndetected',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Disclaimer
          Container(
            decoration: BoxDecoration(
              color: AppColors.lightLavender,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14,
                    color: AppColors.primary.withValues(alpha: 0.8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI-assisted screening — not a diagnosis. Consult a licensed dentist for professional evaluation.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: AppColors.primary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          PrimaryButton(label: 'View Results', onTap: _handleReset),
          const SizedBox(height: 10),
          PrimaryButton(
            label: 'New Scan',
            variant: ButtonVariant.secondary,
            onTap: _handleReset,
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────

  String _positionInstruction(String id) {
    const m = {
      'ul': 'Position the camera toward the upper-left teeth',
      'ur': 'Position the camera toward the upper-right teeth',
      'll': 'Tilt slightly downward toward the lower-left teeth',
      'lr': 'Tilt slightly downward toward the lower-right teeth',
      'po': 'Move toward the back teeth and keep the device steady',
    };
    return m[id] ?? '';
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────

/// Gradient header scaffold reused across most scan steps.
class _GradientScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onBack;
  final Widget body;

  const _GradientScaffold({
    required this.title,
    required this.subtitle,
    this.onBack,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.pageBackground),
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            padding: const EdgeInsets.fromLTRB(24, 52, 24, 28),
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (onBack != null)
                    GestureDetector(
                      onTap: onBack,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            const Icon(Icons.chevron_left_rounded,
                                color: Colors.white60, size: 18),
                            Text(
                              'Back',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white60,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedCheckItem extends StatefulWidget {
  final String label;
  final bool done;
  final int delayMs;

  const _AnimatedCheckItem({
    required this.label,
    required this.done,
    required this.delayMs,
  });

  @override
  State<_AnimatedCheckItem> createState() => _AnimatedCheckItemState();
}

class _AnimatedCheckItemState extends State<_AnimatedCheckItem> {
  bool _visible = false;

  @override
  void didUpdateWidget(_AnimatedCheckItem old) {
    super.didUpdateWidget(old);
    if (widget.done && !_visible) {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, 0.25),
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navy,
                ),
              ),
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.done
                      ? AppColors.lightLavender
                      : AppColors.border,
                ),
                child: widget.done
                    ? const Icon(Icons.check_rounded,
                        size: 11, color: AppColors.primary)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegionTile extends StatelessWidget {
  final String label;
  final String desc;
  final bool isCaptured;
  final bool isSelected;
  final VoidCallback? onTap;

  const _RegionTile({
    required this.label,
    required this.desc,
    required this.isCaptured,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isCaptured
              ? AppColors.lightLavender
              : isSelected
                  ? AppColors.cardSolid
                  : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCaptured
                ? AppColors.lavender
                : isSelected
                    ? Colors.transparent
                    : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.2),
                    blurRadius: 0,
                    spreadRadius: -1,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isCaptured
                          ? AppColors.primary
                          : isSelected
                              ? AppColors.white
                              : AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isCaptured
                          ? AppColors.primary
                          : isSelected
                              ? Colors.white.withValues(alpha: 0.6)
                              : AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (isCaptured)
              const Icon(Icons.check_rounded, size: 16, color: AppColors.primary)
            else if (isSelected)
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              )
            else
              Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.border,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RegionProgressRow extends StatelessWidget {
  final String label;
  final bool done;
  const _RegionProgressRow({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.lightLavender : AppColors.border,
            ),
            child: done
                ? const Icon(Icons.check_rounded,
                    size: 11, color: AppColors.primary)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                color: done ? AppColors.navy : AppColors.secondaryText,
              ),
            ),
          ),
          Text(
            done ? 'Captured' : 'Pending',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: done ? AppColors.primary : AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanSummaryRow extends StatelessWidget {
  final String label;
  final bool done;
  const _ScanSummaryRow({required this.label, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 28,
            decoration: BoxDecoration(
              color: done ? const Color(0xFF1A1630) : AppColors.border,
              borderRadius: BorderRadius.circular(6),
            ),
            child: done
                ? Center(
                    child: Container(
                      width: 20, height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF786EDC).withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.navy,
              ),
            ),
          ),
          Text(
            done ? 'Ready' : 'Skipped',
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: done ? AppColors.primary : AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _QualityMetricRow extends StatelessWidget {
  final String label;
  final double progressFraction;
  const _QualityMetricRow({required this.label, required this.progressFraction});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.navy,
            ),
          ),
          Row(
            children: [
              Container(
                width: 80, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lavender,
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progressFraction,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: AppColors.horizontalGradient,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Good',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  final String value;
  final String label;
  const _SummaryMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppColors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.45),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.45)),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}

class _DarkPill extends StatelessWidget {
  final Widget child;
  const _DarkPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
