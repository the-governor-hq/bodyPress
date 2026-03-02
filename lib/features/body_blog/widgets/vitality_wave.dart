import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/body_blog_entry.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  VITALITY WAVE — flowing sinusoidal wave reflecting current body state
//
//  A continuously animated wave that maps the user's vitality (composite
//  of sleep + movement + heart) into amplitude and frequency.
//  High vitality → tall, energetic waves.  Low → soft, slow ripples.
//  The effect is meditative and deeply personal — like seeing your
//  life force rendered in light.
// ═════════════════════════════════════════════════════════════════════════════

class VitalityWave extends StatefulWidget {
  const VitalityWave({super.key, required this.snapshot, required this.mood});
  final BodySnapshot snapshot;
  final String mood;

  @override
  State<VitalityWave> createState() => _VitalityWaveState();
}

class _VitalityWaveState extends State<VitalityWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final s = widget.snapshot;

    // Determine vitality level (0.0 – 1.0)
    final vitality = _computeVitality(s);
    final waveColors = _moodColors(widget.mood, primary);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: dark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            'VITALITY',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: dark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _vitalityLabel(vitality),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: waveColors.$1.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _WavePainter(
                  phase: _ctrl.value * 2 * math.pi,
                  vitality: vitality,
                  color1: waveColors.$1,
                  color2: waveColors.$2,
                  dark: dark,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Vitality metric chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _VitalityBreakdown(snapshot: s, dark: dark),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  double _computeVitality(BodySnapshot s) {
    double score = 0;
    int factors = 0;

    if (s.sleepHours > 0) {
      score += (s.sleepHours / 9).clamp(0.0, 1.0);
      factors++;
    }
    if (s.steps > 0) {
      score += (s.steps / 12000).clamp(0.0, 1.0);
      factors++;
    }
    if (s.avgHeartRate > 0) {
      // Good resting zone (50–70) scores higher
      final hrNorm = 1.0 - ((s.avgHeartRate - 60).abs() / 50).clamp(0.0, 1.0);
      score += hrNorm;
      factors++;
    }
    if (s.caloriesBurned > 0) {
      score += (s.caloriesBurned / 2500).clamp(0.0, 1.0);
      factors++;
    }

    return factors > 0 ? (score / factors).clamp(0.15, 1.0) : 0.5;
  }

  String _vitalityLabel(double v) {
    if (v >= 0.8) return 'Surging with energy';
    if (v >= 0.6) return 'Fluid and alive';
    if (v >= 0.4) return 'Calm current';
    if (v >= 0.25) return 'Gentle ripple';
    return 'Deep stillness';
  }

  (Color, Color) _moodColors(String mood, Color primary) {
    switch (mood.toLowerCase()) {
      case 'energised':
      case 'energized':
      case 'excited':
        return (const Color(0xFFFF6D00), const Color(0xFFFFAB40));
      case 'calm':
      case 'peaceful':
      case 'relaxed':
        return (const Color(0xFF00BFA5), const Color(0xFF64FFDA));
      case 'tired':
      case 'exhausted':
      case 'fatigued':
        return (const Color(0xFF5C6BC0), const Color(0xFF9FA8DA));
      case 'restless':
      case 'anxious':
      case 'stressed':
        return (const Color(0xFFFF5252), const Color(0xFFFF8A80));
      case 'focused':
      case 'productive':
        return (const Color(0xFF2979FF), const Color(0xFF82B1FF));
      default:
        return (primary, primary.withValues(alpha: 0.5));
    }
  }
}

// ── Wave painter ─────────────────────────────────────────────────────────────

class _WavePainter extends CustomPainter {
  final double phase;
  final double vitality;
  final Color color1;
  final Color color2;
  final bool dark;

  _WavePainter({
    required this.phase,
    required this.vitality,
    required this.color1,
    required this.color2,
    required this.dark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;

    // Wave 1 — primary
    _drawWave(
      canvas,
      size,
      amplitude: h * 0.25 * vitality,
      frequency: 1.5 + vitality * 0.8,
      phaseOffset: phase,
      color: color1.withValues(alpha: 0.4),
      glowColor: color1.withValues(alpha: 0.12),
      strokeWidth: 2.5,
    );

    // Wave 2 — secondary, slightly offset
    _drawWave(
      canvas,
      size,
      amplitude: h * 0.18 * vitality,
      frequency: 2.0 + vitality * 0.5,
      phaseOffset: phase + math.pi * 0.6,
      color: color2.withValues(alpha: 0.3),
      glowColor: color2.withValues(alpha: 0.08),
      strokeWidth: 2.0,
    );

    // Wave 3 — subtle undertow
    _drawWave(
      canvas,
      size,
      amplitude: h * 0.1 * vitality,
      frequency: 3.0,
      phaseOffset: phase * 0.7 + math.pi,
      color: color1.withValues(alpha: 0.15),
      glowColor: null,
      strokeWidth: 1.2,
    );
  }

  void _drawWave(
    Canvas canvas,
    Size size, {
    required double amplitude,
    required double frequency,
    required double phaseOffset,
    required Color color,
    Color? glowColor,
    required double strokeWidth,
  }) {
    final path = Path();
    final midY = size.height / 2;

    path.moveTo(0, midY);
    for (double x = 0; x <= size.width; x += 1.5) {
      final y =
          midY +
          amplitude *
              math.sin(
                (x / size.width) * frequency * 2 * math.pi + phaseOffset,
              );
      path.lineTo(x, y);
    }

    // Glow
    if (glowColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth + 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // Line
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.phase != phase || old.vitality != vitality;
}

// ── Vitality breakdown chips ─────────────────────────────────────────────────

class _VitalityBreakdown extends StatelessWidget {
  const _VitalityBreakdown({required this.snapshot, required this.dark});
  final BodySnapshot snapshot;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final items = <_VitalMetric>[];

    if (snapshot.sleepHours > 0) {
      items.add(
        _VitalMetric('😴', _sleepQuality(snapshot.sleepHours), 'Sleep'),
      );
    }
    if (snapshot.steps > 0) {
      items.add(_VitalMetric('🚶', _activityLevel(snapshot.steps), 'Activity'));
    }
    if (snapshot.avgHeartRate > 0) {
      items.add(_VitalMetric('❤️', _heartZone(snapshot.avgHeartRate), 'Heart'));
    }
    if (snapshot.temperatureC != null) {
      items.add(
        _VitalMetric(
          '🌡️',
          '${snapshot.temperatureC!.toStringAsFixed(0)}°',
          'Outside',
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items.map((m) => _VitalChip(metric: m, dark: dark)).toList(),
    );
  }

  String _sleepQuality(double hours) {
    if (hours >= 7.5) return 'Great';
    if (hours >= 6) return 'OK';
    return 'Low';
  }

  String _activityLevel(int steps) {
    if (steps >= 10000) return 'High';
    if (steps >= 5000) return 'Good';
    return 'Light';
  }

  String _heartZone(int bpm) {
    if (bpm <= 60) return 'Rest';
    if (bpm <= 80) return 'Calm';
    if (bpm <= 100) return 'Active';
    return 'Elevated';
  }
}

class _VitalMetric {
  final String icon;
  final String label;
  final String category;
  const _VitalMetric(this.icon, this.label, this.category);
}

class _VitalChip extends StatelessWidget {
  const _VitalChip({required this.metric, required this.dark});
  final _VitalMetric metric;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(metric.icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 3),
        Text(
          metric.label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: dark ? Colors.white70 : Colors.black54,
          ),
        ),
        Text(
          metric.category,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            color: dark ? Colors.white30 : Colors.black26,
          ),
        ),
      ],
    );
  }
}
