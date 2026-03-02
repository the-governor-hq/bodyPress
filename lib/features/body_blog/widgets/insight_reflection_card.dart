import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/models/body_blog_entry.dart';

// ═════════════════════════════════════════════════════════════════════════════
//  INSIGHT REFLECTION CARD — a mirror for the self
//
//  Surfaces a single, meaningful personal insight derived from the day's
//  body data. The ethereal gradient + typography makes it feel like a
//  personal mantra — something you'd screenshot and save.
// ═════════════════════════════════════════════════════════════════════════════

class InsightReflectionCard extends StatefulWidget {
  const InsightReflectionCard({super.key, required this.entry});

  final BodyBlogEntry entry;

  @override
  State<InsightReflectionCard> createState() => _InsightReflectionCardState();
}

class _InsightReflectionCardState extends State<InsightReflectionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final insight = _deriveInsight(widget.entry);

    if (insight == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        final gradientShift = _shimmer.value;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment(-1.0 + gradientShift * 0.5, -1.0),
              end: Alignment(1.0 - gradientShift * 0.5, 1.0),
              colors: dark
                  ? [
                      insight.accentColor.withValues(alpha: 0.12),
                      primary.withValues(alpha: 0.06),
                      insight.accentColor.withValues(alpha: 0.08),
                    ]
                  : [
                      insight.accentColor.withValues(alpha: 0.08),
                      primary.withValues(alpha: 0.04),
                      insight.accentColor.withValues(alpha: 0.06),
                    ],
            ),
            border: Border.all(
              color: insight.accentColor.withValues(alpha: dark ? 0.18 : 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category label
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: insight.accentColor.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: Text(
                        insight.icon,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    insight.category.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.6,
                      color: insight.accentColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Main reflection text — the "mantra"
              Text(
                insight.reflection,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                  color: dark
                      ? Colors.white.withValues(alpha: 0.87)
                      : Colors.black.withValues(alpha: 0.80),
                ),
              ),

              const SizedBox(height: 14),

              // Supporting data point
              Text(
                insight.evidence,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: dark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Insight data ─────────────────────────────────────────────────────────────

class _Insight {
  final String icon;
  final String category;
  final String reflection;
  final String evidence;
  final Color accentColor;

  const _Insight({
    required this.icon,
    required this.category,
    required this.reflection,
    required this.evidence,
    required this.accentColor,
  });
}

/// Derives the single most meaningful insight from today's data.
/// This is deterministic (not AI) — purely data-driven personal truth.
_Insight? _deriveInsight(BodyBlogEntry entry) {
  final s = entry.snapshot;
  final insights = <_Insight>[];

  // ── Sleep insights ─────────────────────────────────────────────────────
  if (s.sleepHours > 0) {
    if (s.sleepHours >= 7.5 && s.sleepHours <= 9) {
      insights.add(
        const _Insight(
          icon: '🌙',
          category: 'Rest & Recovery',
          reflection:
              'Your body found its rhythm last night. Quality rest is the foundation everything else builds on.',
          evidence: 'Sleep duration in the optimal 7.5–9 hour window.',
          accentColor: Color(0xFF7C4DFF),
        ),
      );
    } else if (s.sleepHours < 6) {
      insights.add(
        _Insight(
          icon: '🌑',
          category: 'Sleep Deficit',
          reflection:
              'Your body is asking for more rest. Even 20 minutes of quiet stillness can help replenish what sleep couldn\'t.',
          evidence:
              '${s.sleepHours.toStringAsFixed(1)}h sleep — below the 7h threshold.',
          accentColor: const Color(0xFF5C6BC0),
        ),
      );
    } else if (s.sleepHours > 9.5) {
      insights.add(
        _Insight(
          icon: '🛏️',
          category: 'Deep Rest',
          reflection:
              'Extended sleep often signals your body is healing or processing. Trust what it needs today.',
          evidence:
              '${s.sleepHours.toStringAsFixed(1)}h sleep — your body chose deep recovery.',
          accentColor: const Color(0xFF9575CD),
        ),
      );
    }
  }

  // ── Heart rate insights ────────────────────────────────────────────────
  if (s.restingHeartRate > 0) {
    if (s.restingHeartRate <= 55) {
      insights.add(
        const _Insight(
          icon: '💎',
          category: 'Cardiac Strength',
          reflection:
              'A calm heart at rest speaks to deep cardiovascular fitness. Your body carries you with quiet efficiency.',
          evidence: 'Resting heart rate ≤55 bpm — athlete-level zone.',
          accentColor: Color(0xFFE91E63),
        ),
      );
    } else if (s.restingHeartRate >= 75) {
      insights.add(
        _Insight(
          icon: '🫀',
          category: 'Heart Rhythm',
          reflection:
              'Your heart is working a bit harder at rest today. Breathwork or a slow walk might help it settle.',
          evidence:
              'Resting HR ${s.restingHeartRate} bpm — elevated above typical baseline.',
          accentColor: const Color(0xFFFF5252),
        ),
      );
    }
  }

  // ── Movement insights ──────────────────────────────────────────────────
  if (s.steps > 0) {
    if (s.steps >= 10000) {
      insights.add(
        _Insight(
          icon: '🌿',
          category: 'Movement',
          reflection:
              'You moved with purpose today. Every step is a conversation between your body and the ground beneath it.',
          evidence: '${s.steps} steps — surpassed the 10,000 daily benchmark.',
          accentColor: const Color(0xFF66BB6A),
        ),
      );
    } else if (s.steps < 3000 && s.steps > 0) {
      insights.add(
        _Insight(
          icon: '🪷',
          category: 'Stillness',
          reflection:
              'A quieter day for movement. Sometimes stillness is exactly what\'s needed — listen to that.',
          evidence: '${s.steps} steps — a gentle, low-movement rhythm today.',
          accentColor: const Color(0xFF26A69A),
        ),
      );
    }
  }

  // ── Environment insights ───────────────────────────────────────────────
  if (s.aqiUs != null && s.aqiUs! > 0) {
    if (s.aqiUs! <= 50) {
      insights.add(
        const _Insight(
          icon: '🍃',
          category: 'Air Quality',
          reflection:
              'The air around you is clean and nourishing. A perfect day to breathe deeply and let oxygen do its work.',
          evidence: 'AQI ≤50 — excellent air quality for outdoor activity.',
          accentColor: Color(0xFF4CAF50),
        ),
      );
    } else if (s.aqiUs! > 100) {
      insights.add(
        _Insight(
          icon: '🌫️',
          category: 'Environment',
          reflection:
              'The air quality is challenged today. Your body\'s filtration system is working harder — hydrate and favor indoor air.',
          evidence: 'AQI ${s.aqiUs} — moderate to unhealthy levels detected.',
          accentColor: const Color(0xFFFF9800),
        ),
      );
    }
  }

  // ── Composite insights (mind-body connection) ──────────────────────────
  if (s.sleepHours >= 7 && s.steps >= 8000 && s.avgHeartRate > 0) {
    insights.add(
      const _Insight(
        icon: '✨',
        category: 'Mind-Body Alignment',
        reflection:
            'Sleep, movement, and heart — all three pillars are working in concert today. This is what balance feels like from the inside.',
        evidence: 'Strong sleep + active day + healthy heart rhythm.',
        accentColor: Color(0xFFFFD740),
      ),
    );
  }

  if (s.sleepHours > 0 && s.sleepHours < 6 && s.steps >= 8000) {
    insights.add(
      const _Insight(
        icon: '⚡',
        category: 'Resilience',
        reflection:
            'Your body pushed through on limited sleep. That takes real grit — but remember to return the favor with rest tonight.',
        evidence: 'Low sleep paired with high activity — resilience mode.',
        accentColor: Color(0xFFFF6E40),
      ),
    );
  }

  // ── HRV insight ────────────────────────────────────────────────────────
  if (s.hrv != null && s.hrv! > 0) {
    if (s.hrv! >= 50) {
      insights.add(
        _Insight(
          icon: '🧘',
          category: 'Nervous System',
          reflection:
              'Your heart rate variability shows strong parasympathetic tone — your nervous system is flexible and ready to adapt.',
          evidence:
              'HRV ${s.hrv!.toStringAsFixed(0)} ms — robust autonomic balance.',
          accentColor: const Color(0xFF00BCD4),
        ),
      );
    } else if (s.hrv! < 25) {
      insights.add(
        _Insight(
          icon: '🫧',
          category: 'Recovery Signal',
          reflection:
              'Your autonomic nervous system is under load right now. Gentle movement and deep breathing can help recalibrate.',
          evidence:
              'HRV ${s.hrv!.toStringAsFixed(0)} ms — below optimal range.',
          accentColor: const Color(0xFF80DEEA),
        ),
      );
    }
  }

  if (insights.isEmpty) return null;

  // Pick the most "meaningful" insight:
  // Composite > specific signals. Use mood as tiebreaker.
  // For simplicity, prefer composite (mind-body) when available, else first.
  final composite = insights.where(
    (i) => i.category == 'Mind-Body Alignment' || i.category == 'Resilience',
  );
  if (composite.isNotEmpty) return composite.first;

  return insights.first;
}
