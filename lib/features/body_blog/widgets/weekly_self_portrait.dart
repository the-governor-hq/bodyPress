import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/capture_entry.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  WEEKLY SELF PORTRAIT — a 7-day multi-dimensional self view
//
//  Renders the last 7 days as a flowing radar / petal chart where each
//  day's shape reflects the user's body-mind state. The visual effect:
//  an organic bloom that grows as data accumulates — like watching
//  yourself unfold across a week.
// ═════════════════════════════════════════════════════════════════════════════

class WeeklySelfPortrait extends StatefulWidget {
  const WeeklySelfPortrait({super.key, required this.captures});
  final List<CaptureEntry> captures;

  @override
  State<WeeklySelfPortrait> createState() => _WeeklySelfPortraitState();
}

class _WeeklySelfPortraitState extends State<WeeklySelfPortrait>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    // Build day summaries for the last 7 days
    final days = _buildWeekDays(widget.captures);
    if (days.every((d) => d == null)) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1A1A1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR WEEK',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
              color: dark ? Colors.white30 : Colors.black26,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'How your body moved through the last 7 days',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: dark ? Colors.white54 : Colors.black45,
            ),
          ),
          const SizedBox(height: 20),

          // Radar-style portrait
          SizedBox(
            height: 220,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => CustomPaint(
                size: Size.infinite,
                painter: _SelfPortraitPainter(
                  days: days,
                  progress: _anim.value,
                  dark: dark,
                  primaryColor: primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Day labels with mood emoji
          _DayLabelRow(days: days, dark: dark, primary: primary),

          const SizedBox(height: 16),

          // Insight summary
          _WeekInsight(days: days, dark: dark, primary: primary),
        ],
      ),
    );
  }
}

// ── Day data ─────────────────────────────────────────────────────────────────

class _DayData {
  final DateTime date;
  final double energy; // 0.0 – 1.0
  final double stress; // 0.0 – 1.0
  final double sleep; // 0.0 – 1.0
  final double activity; // 0.0 – 1.0
  final String? moodEmoji;
  final String? moodText;

  const _DayData({
    required this.date,
    required this.energy,
    required this.stress,
    required this.sleep,
    required this.activity,
    this.moodEmoji,
    this.moodText,
  });

  double get average => (energy + (1 - stress) + sleep + activity) / 4;
}

List<_DayData?> _buildWeekDays(List<CaptureEntry> captures) {
  final now = DateTime.now();
  final result = <_DayData?>[];

  for (int i = 6; i >= 0; i--) {
    final day = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: i));
    final dayCaptures = captures.where((c) {
      final d = c.timestamp;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList();

    if (dayCaptures.isEmpty) {
      result.add(null);
      continue;
    }

    // Aggregate metadata from this day's captures
    final withMeta = dayCaptures.where((c) => c.aiMetadata != null).toList();
    if (withMeta.isEmpty) {
      result.add(
        _DayData(
          date: day,
          energy: 0.5,
          stress: 0.3,
          sleep: 0.5,
          activity: 0.3,
          moodEmoji: dayCaptures.first.userMood,
        ),
      );
      continue;
    }

    double avgEnergy = 0;
    double avgStress = 0;
    double avgSleep = 0;
    double avgActivity = 0;
    String? lastMood;

    for (final c in withMeta) {
      final m = c.aiMetadata!;
      avgEnergy += _energyToNum(m.energyLevel);
      avgStress += (m.stressLevel ?? 5) / 10;
      avgSleep += (m.sleepQuality ?? 5) / 10;
      avgActivity += _activityToNum(m.activityCategory);
      lastMood ??= c.userMood;
    }

    final n = withMeta.length;
    result.add(
      _DayData(
        date: day,
        energy: (avgEnergy / n).clamp(0.0, 1.0),
        stress: (avgStress / n).clamp(0.0, 1.0),
        sleep: (avgSleep / n).clamp(0.0, 1.0),
        activity: (avgActivity / n).clamp(0.0, 1.0),
        moodEmoji: lastMood,
        moodText: withMeta.first.aiMetadata!.moodAssessment,
      ),
    );
  }

  return result;
}

double _energyToNum(String level) => switch (level.toLowerCase()) {
  'high' => 0.9,
  'medium' => 0.55,
  'low' => 0.25,
  _ => 0.5,
};

double _activityToNum(String? cat) => switch (cat?.toLowerCase()) {
  'active' => 0.9,
  'light-activity' => 0.65,
  'sedentary' => 0.25,
  'recovering' => 0.4,
  'sleeping' => 0.1,
  _ => 0.4,
};

// ── Radar painter ────────────────────────────────────────────────────────────

class _SelfPortraitPainter extends CustomPainter {
  final List<_DayData?> days;
  final double progress;
  final bool dark;
  final Color primaryColor;

  static const _dimensions = ['Energy', 'Calm', 'Sleep', 'Motion'];
  static const _dimColors = [
    Color(0xFFFF6D00), // Energy — orange
    Color(0xFF00BFA5), // Calm (inverse stress) — teal
    Color(0xFF7C4DFF), // Sleep — purple
    Color(0xFF2979FF), // Motion — blue
  ];

  _SelfPortraitPainter({
    required this.days,
    required this.progress,
    required this.dark,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) / 2 - 20;
    final axes = 4; // energy, calm, sleep, activity

    // Draw axis lines
    for (int i = 0; i < axes; i++) {
      final angle = (2 * math.pi / axes) * i - math.pi / 2;
      final end = Offset(
        center.dx + maxR * math.cos(angle),
        center.dy + maxR * math.sin(angle),
      );
      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.06)
          ..strokeWidth = 1,
      );
    }

    // Draw concentric guide rings
    for (int ring = 1; ring <= 3; ring++) {
      final r = maxR * ring / 3;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.04)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // Draw axis labels
    final labelStyle = TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.3),
    );
    for (int i = 0; i < axes; i++) {
      final angle = (2 * math.pi / axes) * i - math.pi / 2;
      final labelR = maxR + 14;
      final pos = Offset(
        center.dx + labelR * math.cos(angle),
        center.dy + labelR * math.sin(angle),
      );
      final tp = TextPainter(
        text: TextSpan(text: _dimensions[i].toUpperCase(), style: labelStyle),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2));
    }

    // Draw each day's polygon
    for (int di = 0; di < days.length; di++) {
      final day = days[di];
      if (day == null) continue;

      final values = [
        day.energy,
        1.0 - day.stress, // Calm = inverse stress
        day.sleep,
        day.activity,
      ];

      final path = Path();
      for (int i = 0; i < axes; i++) {
        final angle = (2 * math.pi / axes) * i - math.pi / 2;
        final r = maxR * values[i] * progress;
        final point = Offset(
          center.dx + r * math.cos(angle),
          center.dy + r * math.sin(angle),
        );
        if (i == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
      }
      path.close();

      // Day color based on position in week (oldest = faded, newest = bright)
      final dayAlpha = 0.06 + (di / 6) * 0.14; // 0.06 → 0.20
      final strokeAlpha = 0.15 + (di / 6) * 0.45; // 0.15 → 0.60
      final color = _dayColor(di);

      // Fill
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: dayAlpha * progress)
          ..style = PaintingStyle.fill,
      );

      // Stroke
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: strokeAlpha * progress)
          ..style = PaintingStyle.stroke
          ..strokeWidth = di == 6
              ? 2.0
              : 1.0 // Today = thicker
          ..strokeJoin = StrokeJoin.round,
      );

      // Vertex dots for today
      if (di == 6) {
        for (int i = 0; i < axes; i++) {
          final angle = (2 * math.pi / axes) * i - math.pi / 2;
          final r = maxR * values[i] * progress;
          final point = Offset(
            center.dx + r * math.cos(angle),
            center.dy + r * math.sin(angle),
          );
          // Glow
          canvas.drawCircle(
            point,
            5,
            Paint()
              ..color = _dimColors[i].withValues(alpha: 0.25 * progress)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
          // Dot
          canvas.drawCircle(
            point,
            3,
            Paint()..color = _dimColors[i].withValues(alpha: 0.8 * progress),
          );
        }
      }
    }
  }

  Color _dayColor(int index) {
    // Gradient from muted past → vivid present
    final t = index / 6;
    return Color.lerp(
      dark ? const Color(0xFF4A6572) : const Color(0xFFA8C0C8),
      primaryColor,
      t,
    )!;
  }

  @override
  bool shouldRepaint(_SelfPortraitPainter old) =>
      old.progress != progress || old.days != days;
}

// ── Day label row ────────────────────────────────────────────────────────────

class _DayLabelRow extends StatelessWidget {
  const _DayLabelRow({
    required this.days,
    required this.dark,
    required this.primary,
  });

  final List<_DayData?> days;
  final bool dark;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(7, (i) {
        final day = days[i];
        final isToday = i == 6;
        final date = DateTime.now().subtract(Duration(days: 6 - i));
        final dayLabel = DateFormat('E').format(date).substring(0, 2);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Day letter
            Text(
              dayLabel,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isToday
                    ? primary
                    : (dark ? Colors.white30 : Colors.black26),
              ),
            ),
            const SizedBox(height: 3),
            // Mood emoji or dot
            if (day?.moodEmoji != null)
              Text(day!.moodEmoji!, style: const TextStyle(fontSize: 14))
            else
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: day != null
                      ? primary.withValues(alpha: 0.3)
                      : (dark ? Colors.white12 : Colors.black12),
                ),
              ),
            const SizedBox(height: 2),
            // Score bar
            if (day != null)
              Container(
                width: 24,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: _scoreColor(
                    day.average,
                  ).withValues(alpha: isToday ? 0.7 : 0.35),
                ),
              )
            else
              const SizedBox(height: 3),
          ],
        );
      }),
    );
  }

  Color _scoreColor(double score) {
    if (score >= 0.7) return const Color(0xFF4CAF50);
    if (score >= 0.45) return const Color(0xFFFF9800);
    return const Color(0xFFFF5252);
  }
}

// ── Week insight ─────────────────────────────────────────────────────────────

class _WeekInsight extends StatelessWidget {
  const _WeekInsight({
    required this.days,
    required this.dark,
    required this.primary,
  });

  final List<_DayData?> days;
  final bool dark;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final valid = days.whereType<_DayData>().toList();
    if (valid.length < 2) return const SizedBox.shrink();

    final insight = _deriveWeekInsight(valid);
    if (insight == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: primary.withValues(alpha: dark ? 0.08 : 0.05),
        border: Border.all(
          color: primary.withValues(alpha: dark ? 0.15 : 0.10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(insight.$1, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insight.$2,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: dark ? Colors.white60 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, String)? _deriveWeekInsight(List<_DayData> valid) {
    final avgEnergy =
        valid.map((d) => d.energy).reduce((a, b) => a + b) / valid.length;
    final avgSleep =
        valid.map((d) => d.sleep).reduce((a, b) => a + b) / valid.length;
    final avgStress =
        valid.map((d) => d.stress).reduce((a, b) => a + b) / valid.length;

    // Trend: compare first half vs second half
    final mid = valid.length ~/ 2;
    final firstHalf = valid.sublist(0, mid);
    final secondHalf = valid.sublist(mid);

    final firstEnergy = firstHalf.isEmpty
        ? 0.5
        : firstHalf.map((d) => d.energy).reduce((a, b) => a + b) /
              firstHalf.length;
    final secondEnergy = secondHalf.isEmpty
        ? 0.5
        : secondHalf.map((d) => d.energy).reduce((a, b) => a + b) /
              secondHalf.length;

    if (secondEnergy > firstEnergy + 0.15) {
      return (
        '📈',
        'Your energy has been rising through the week. Whatever you\'re doing, your body is responding well — keep this momentum.',
      );
    }
    if (firstEnergy > secondEnergy + 0.15) {
      return (
        '🫧',
        'Energy has been tapering off. This is your body asking for renewal — extra sleep or a change of pace might help.',
      );
    }
    if (avgStress > 0.6) {
      return (
        '🌊',
        'Stress signals have been elevated this week. Your body is carrying more than usual — be gentle with yourself.',
      );
    }
    if (avgSleep >= 0.7 && avgEnergy >= 0.6) {
      return (
        '✨',
        'Strong sleep paired with solid energy — your weekly rhythm is in a great place. This is what alignment looks like.',
      );
    }
    if (avgSleep < 0.4) {
      return (
        '🌙',
        'Sleep quality has been below baseline this week. Prioritizing rest tonight could shift your entire trajectory.',
      );
    }

    return (
      '🔄',
      'Your body has maintained a steady rhythm this week. Consistency itself is a form of strength.',
    );
  }
}
