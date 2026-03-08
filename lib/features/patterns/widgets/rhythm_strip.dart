import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Horizontal-bar visualization of capture distribution across time-of-day.
///
/// Shows the user when their body data is being captured and where their
/// active hours cluster. Grounded in circadian-rhythm science: knowing
/// your body's daily rhythm is the first step to optimising it.
class RhythmStrip extends StatelessWidget {
  final Map<String, int> timeOfDayDistribution;
  final ThemeData theme;
  final bool dark;

  const RhythmStrip({
    super.key,
    required this.timeOfDayDistribution,
    required this.theme,
    required this.dark,
  });

  // Ordered slots mapping the AI's normalised timeOfDay values.
  static const _slots = [
    ('early-morning', 'Early AM', Icons.wb_twilight_rounded, Color(0xFF9575CD)),
    ('morning', 'Morning', Icons.wb_sunny_rounded, Color(0xFFFFB74D)),
    ('midday', 'Midday', Icons.light_mode_rounded, Color(0xFFFFD54F)),
    ('afternoon', 'Afternoon', Icons.wb_sunny_outlined, Color(0xFFFF8A65)),
    ('evening', 'Evening', Icons.nights_stay_outlined, Color(0xFF7986CB)),
    ('night', 'Night', Icons.dark_mode_rounded, Color(0xFF5C6BC0)),
    ('late-night', 'Late', Icons.bedtime_rounded, Color(0xFF7E57C2)),
  ];

  @override
  Widget build(BuildContext context) {
    final total = timeOfDayDistribution.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final maxCount = timeOfDayDistribution.values.fold(0, math.max);

    final surfaceColor =
        dark ? const Color(0xFF1A1A1E) : theme.colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: _slots.map((slot) {
          final (key, label, icon, color) = slot;
          final count = timeOfDayDistribution[key] ?? 0;
          final fraction = maxCount > 0 ? count / maxCount : 0.0;
          final pct = total > 0 ? (count / total * 100).round() : 0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                SizedBox(
                  width: 55,
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      children: [
                        Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: fraction.clamp(0.02, 1.0),
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 34,
                  child: Text(
                    count > 0 ? '$pct%' : '–',
                    textAlign: TextAlign.end,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: count > 0
                          ? color
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
