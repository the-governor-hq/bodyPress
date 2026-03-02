import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

/// Animated real-time ECG-style waveform widget driven by a BPM stream.
///
/// Drop this into any layout and feed it a [Stream<int>] of heart-rate
/// readings. The waveform scrolls continuously and generates a
/// synthetic PQRST complex at the correct cardiac frequency.
///
/// ```dart
/// LiveHrWaveform(
///   hrStream: bleService.hrStream.map((r) => r.bpm),
///   deviceName: 'Polar H10',
/// )
/// ```
class LiveHrWaveform extends StatefulWidget {
  /// Emits BPM values in real time.
  final Stream<int> hrStream;

  /// Optional device name shown in the header.
  final String? deviceName;

  /// Optional callback when user taps the disconnect button.
  final VoidCallback? onDisconnect;

  const LiveHrWaveform({
    super.key,
    required this.hrStream,
    this.deviceName,
    this.onDisconnect,
  });

  @override
  State<LiveHrWaveform> createState() => _LiveHrWaveformState();
}

class _LiveHrWaveformState extends State<LiveHrWaveform>
    with SingleTickerProviderStateMixin {
  // Ring buffer: 6 seconds at 60 fps
  static const int _bufferSize = 360;
  static const double _fps = 60.0;

  final _buffer = List<double>.filled(_bufferSize, 0.0);
  int _writeIndex = 0;

  int _currentBpm = 0;
  bool _connected = false;

  // Phase within the current cardiac cycle [0.0, 1.0)
  double _cyclePhase = 0.0;

  late final Ticker _ticker;
  Duration? _lastTick;
  StreamSubscription<int>? _hrSub;

  // The latest peak amplitude for the glow effect.
  double _peakGlow = 0.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    _hrSub = widget.hrStream.listen((bpm) {
      if (!mounted) return;
      setState(() {
        _currentBpm = bpm;
        _connected = bpm > 0;
      });
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _hrSub?.cancel();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (_lastTick == null) {
      _lastTick = elapsed;
      return;
    }
    final dtMs = (elapsed - _lastTick!).inMicroseconds / 1000.0;
    _lastTick = elapsed;

    final bpm = _currentBpm > 0 ? _currentBpm : 60;
    final cyclesPerMs = bpm / (60 * 1000.0);
    final samplesPerMs = _fps / 1000.0;

    // Advance phase by one sample step.
    _cyclePhase = (_cyclePhase + cyclesPerMs * dtMs) % 1.0;

    // Generate one new sample per tick.
    final amplitude = _pqrst(_cyclePhase);
    _buffer[_writeIndex % _bufferSize] = amplitude;
    _writeIndex++;

    // Drive the glow by peak amplitude.
    if (amplitude > _peakGlow) {
      _peakGlow = amplitude;
    } else {
      _peakGlow = (_peakGlow - 0.04 * dtMs * samplesPerMs).clamp(0.0, 1.0);
    }

    setState(() {});
  }

  /// Synthetic PQRST waveform function.
  /// [phase] is the normalised position within one cardiac cycle [0.0, 1.0).
  /// Returns an amplitude in [-0.15, 1.0].
  double _pqrst(double phase) {
    // P-wave (0.00–0.15)
    if (phase < 0.15) {
      return 0.12 * math.sin(phase / 0.15 * math.pi);
    }
    // PR segment (0.15–0.20) — baseline
    if (phase < 0.20) return 0.0;
    // Q-wave (0.20–0.22)
    if (phase < 0.22) {
      return -0.15 * math.sin((phase - 0.20) / 0.02 * math.pi);
    }
    // R-wave (0.22–0.26) — the big spike
    if (phase < 0.26) {
      return math.sin((phase - 0.22) / 0.04 * math.pi);
    }
    // S-wave (0.26–0.28)
    if (phase < 0.28) {
      return -0.15 * math.sin((phase - 0.26) / 0.02 * math.pi);
    }
    // ST segment (0.28–0.36)
    if (phase < 0.36) return 0.0;
    // T-wave (0.36–0.58)
    if (phase < 0.58) {
      return 0.28 * math.sin((phase - 0.36) / 0.22 * math.pi);
    }
    // TP segment — flat baseline
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF060B0F);
    const lineColor = Color(0xFF00E676); // ECG green
    final glowColor = lineColor.withValues(alpha: 0.35 + _peakGlow * 0.4);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: lineColor.withValues(alpha: 0.18 + _peakGlow * 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor,
            blurRadius: 18 + _peakGlow * 14,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
            child: Row(
              children: [
                // Blinking status dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _connected ? lineColor : Colors.red,
                    boxShadow: _connected
                        ? [
                            BoxShadow(
                              color: lineColor.withValues(alpha: 0.7),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.deviceName ?? 'BLE Heart Rate',
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    color: lineColor.withValues(alpha: 0.7),
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                // BPM badge
                Text(
                  _currentBpm > 0 ? '$_currentBpm BPM' : '-- BPM',
                  style: GoogleFonts.robotoMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: lineColor,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 12),
                // Disconnect button
                if (widget.onDisconnect != null)
                  GestureDetector(
                    onTap: widget.onDisconnect,
                    child: Icon(
                      Icons.bluetooth_disabled_rounded,
                      color: Colors.white.withValues(alpha: 0.3),
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),

          // ── Waveform canvas ─────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CustomPaint(
                  painter: _WaveformPainter(
                    buffer: _buffer,
                    writeIndex: _writeIndex,
                    lineColor: lineColor,
                    glowColor: glowColor.withValues(alpha: 0.9),
                    peakGlow: _peakGlow,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),

          // ── Footer: grid labels ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                7,
                (i) => Text(
                  i == 0
                      ? '6s'
                      : i == 6
                      ? '0s'
                      : '',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double> buffer;
  final int writeIndex;
  final Color lineColor;
  final Color glowColor;
  final double peakGlow;

  const _WaveformPainter({
    required this.buffer,
    required this.writeIndex,
    required this.lineColor,
    required this.glowColor,
    required this.peakGlow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = buffer.length;
    if (n == 0) return;

    // Draw faint grid lines.
    _drawGrid(canvas, size);

    // Draw the ECG trace (glow pass + line pass).
    _drawTrace(canvas, size, n);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 0.5;

    const hLines = 4;
    for (var i = 1; i < hLines; i++) {
      final y = size.height * i / hLines;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    const vLines = 6;
    for (var i = 1; i < vLines; i++) {
      final x = size.width * i / vLines;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _drawTrace(Canvas canvas, Size size, int n) {
    final midY = size.height * 0.5;
    final amplitude = size.height * 0.38;
    final dx = size.width / (n - 1);

    // Build path from oldest → newest sample.
    final path = Path();
    bool first = true;
    for (var i = 0; i < n; i++) {
      final bufIdx = (writeIndex + i) % n;
      final x = dx * i;
      final y = midY - buffer[bufIdx] * amplitude;
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    // Glow pass.
    canvas.drawPath(
      path,
      Paint()
        ..color = glowColor
        ..strokeWidth = 3.5 + peakGlow * 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Crisp line pass.
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      writeIndex != old.writeIndex || peakGlow != old.peakGlow;
}
