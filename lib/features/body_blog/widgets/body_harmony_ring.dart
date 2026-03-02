import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/body_blog_entry.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  BODY HARMONY RING — radial visualization of the day's body signals
//
//  Each vital becomes a luminous arc around a central harmony score.
//  When the user sees it they should feel: "this is *my* body, today."
// ═════════════════════════════════════════════════════════════════════════════

class BodyHarmonyRing extends StatefulWidget {
  const BodyHarmonyRing({super.key, required this.snapshot});
  final BodySnapshot snapshot;

  @override
  State<BodyHarmonyRing> createState() => _BodyHarmonyRingState();
}

class _BodyHarmonyRingState extends State<BodyHarmonyRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    // Build ring data from available metrics
    final rings = <_RingData>[];

    if (s.sleepHours > 0) {
      rings.add(
        _RingData(
          label: 'Sleep',
          value: (s.sleepHours / 10).clamp(0.0, 1.0),
          color: const Color(0xFF7C4DFF),
          icon: '😴',
        ),
      );
    }
    if (s.steps > 0) {
      rings.add(
        _RingData(
          label: 'Steps',
          value: (s.steps / 12000).clamp(0.0, 1.0),
          color: const Color(0xFF00E5FF),
          icon: '🚶',
        ),
      );
    }
    if (s.avgHeartRate > 0) {
      rings.add(
        _RingData(
          label: 'Heart',
          value: _heartScore(s.avgHeartRate, s.restingHeartRate),
          color: const Color(0xFFFF5252),
          icon: '❤️',
        ),
      );
    }
    if (s.caloriesBurned > 0) {
      rings.add(
        _RingData(
          label: 'Energy',
          value: (s.caloriesBurned / 2500).clamp(0.0, 1.0),
          color: const Color(0xFFFFAB40),
          icon: '🔥',
        ),
      );
    }
    if (s.workouts > 0) {
      rings.add(
        _RingData(
          label: 'Active',
          value: (s.workouts / 3).clamp(0.0, 1.0),
          color: const Color(0xFF69F0AE),
          icon: '💪',
        ),
      );
    }

    if (rings.isEmpty) return const SizedBox.shrink();

    // Compute harmony score (0–100) from available signals
    final harmony = _computeHarmony(s);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: dark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.black.withValues(alpha: 0.02),
          ),
          child: Column(
            children: [
              // Section label
              Text(
                'BODY HARMONY',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.8,
                  color: dark ? Colors.white24 : Colors.black26,
                ),
              ),
              const SizedBox(height: 20),

              // The ring itself
              SizedBox(
                width: 200,
                height: 200,
                child: CustomPaint(
                  painter: _HarmonyRingPainter(
                    rings: rings,
                    progress: _anim.value,
                    dark: dark,
                    primaryColor: primary,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Harmony score
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: harmony.toDouble()),
                          duration: const Duration(milliseconds: 2200),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => Text(
                            '${v.round()}',
                            style: GoogleFonts.inter(
                              fontSize: 38,
                              fontWeight: FontWeight.w200,
                              letterSpacing: -1,
                              color: dark
                                  ? Colors.white.withValues(alpha: 0.87)
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          _harmonyLabel(harmony),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                            color: primary.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Legend
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: rings
                      .map((r) => _RingLegend(ring: r, dark: dark))
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Heart health score — closer to resting rate = healthier at rest
  double _heartScore(int avg, int resting) {
    if (resting > 0) {
      // Good resting HR: 40–60 → score ~0.8–1.0
      return (1.0 - ((resting - 50).abs() / 40)).clamp(0.3, 1.0);
    }
    // Fallback: assume 60–100 range, lower is better
    return (1.0 - ((avg - 60) / 60)).clamp(0.2, 1.0);
  }

  int _computeHarmony(BodySnapshot s) {
    double score = 0;
    int factors = 0;

    if (s.sleepHours > 0) {
      // 7–9 hours is ideal
      final sleepScore = 1.0 - ((s.sleepHours - 8).abs() / 4).clamp(0.0, 1.0);
      score += sleepScore;
      factors++;
    }
    if (s.steps > 0) {
      score += (s.steps / 10000).clamp(0.0, 1.0);
      factors++;
    }
    if (s.avgHeartRate > 0) {
      score += _heartScore(s.avgHeartRate, s.restingHeartRate);
      factors++;
    }
    if (s.caloriesBurned > 0) {
      score += (s.caloriesBurned / 2200).clamp(0.0, 1.0);
      factors++;
    }

    if (factors == 0) return 50;
    return ((score / factors) * 100).round().clamp(0, 100);
  }

  String _harmonyLabel(int score) {
    if (score >= 85) return 'Radiant';
    if (score >= 70) return 'Balanced';
    if (score >= 55) return 'Steady';
    if (score >= 40) return 'Rebuilding';
    return 'Rest & recover';
  }
}

// ── Ring data ────────────────────────────────────────────────────────────────

class _RingData {
  final String label;
  final double value; // 0.0 – 1.0
  final Color color;
  final String icon;

  const _RingData({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

// ── Custom painter ───────────────────────────────────────────────────────────

class _HarmonyRingPainter extends CustomPainter {
  final List<_RingData> rings;
  final double progress;
  final bool dark;
  final Color primaryColor;

  _HarmonyRingPainter({
    required this.rings,
    required this.progress,
    required this.dark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final ringWidth = 8.0;
    final ringGap = 6.0;
    final startAngle = -math.pi / 2; // 12 o'clock

    for (int i = 0; i < rings.length; i++) {
      final ring = rings[i];
      final radius = maxRadius - (i * (ringWidth + ringGap)) - 8;
      if (radius < 20) break;

      // Background track
      final trackPaint = Paint()
        ..color = ring.color.withValues(alpha: dark ? 0.08 : 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawCircle(center, radius, trackPaint);

      // Foreground arc with glow
      final sweepAngle = 2 * math.pi * ring.value * progress;

      // Glow layer
      final glowPaint = Paint()
        ..color = ring.color.withValues(alpha: 0.25 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        glowPaint,
      );

      // Main arc
      final arcPaint = Paint()
        ..color = ring.color.withValues(alpha: 0.85 * progress)
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        arcPaint,
      );

      // Bright tip at the end of the arc
      if (progress > 0.1 && ring.value > 0.05) {
        final tipAngle = startAngle + sweepAngle;
        final tipOffset = Offset(
          center.dx + radius * math.cos(tipAngle),
          center.dy + radius * math.sin(tipAngle),
        );
        final tipPaint = Paint()
          ..color = ring.color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(tipOffset, 4, tipPaint);
      }
    }
  }

  @override
  bool shouldRepaint(_HarmonyRingPainter old) =>
      old.progress != progress || old.rings != rings;
}

// ── Legend item ───────────────────────────────────────────────────────────────

class _RingLegend extends StatelessWidget {
  const _RingLegend({required this.ring, required this.dark});
  final _RingData ring;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: ring.color.withValues(alpha: 0.85),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: ring.color.withValues(alpha: 0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${ring.icon} ${ring.label}',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: dark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${(ring.value * 100).round()}%',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: ring.color.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
