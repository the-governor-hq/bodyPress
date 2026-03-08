import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Surfaces AI-discovered pattern hints aggregated across captures.
///
/// Each hint is a correlation the AI noticed during analysis — e.g.
/// "consistent-morning-routine", "weather-affects-mood". Shown as
/// semantic chips with contextual icons.
class PatternHintsCard extends StatelessWidget {
  final List<MapEntry<String, int>> hints;
  final ThemeData theme;
  final bool dark;

  const PatternHintsCard({
    super.key,
    required this.hints,
    required this.theme,
    required this.dark,
  });

  IconData _iconFor(String hint) {
    final h = hint.toLowerCase();
    if (h.contains('morning') || h.contains('routine')) {
      return Icons.wb_sunny_rounded;
    }
    if (h.contains('weather') || h.contains('temperature')) {
      return Icons.cloud_rounded;
    }
    if (h.contains('workout') ||
        h.contains('exercise') ||
        h.contains('active')) {
      return Icons.fitness_center_rounded;
    }
    if (h.contains('sleep')) return Icons.bedtime_rounded;
    if (h.contains('stress')) return Icons.psychology_rounded;
    if (h.contains('weekend') || h.contains('weekday')) {
      return Icons.calendar_today_rounded;
    }
    if (h.contains('social')) return Icons.people_rounded;
    if (h.contains('heart') || h.contains('hrv')) {
      return Icons.monitor_heart_rounded;
    }
    return Icons.auto_awesome_rounded;
  }

  String _humanize(String hint) {
    return hint
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .replaceFirstMapped(RegExp(r'^(\w)'), (m) => m.group(1)!.toUpperCase());
  }

  @override
  Widget build(BuildContext context) {
    if (hints.isEmpty) return const SizedBox.shrink();

    final accent = theme.colorScheme.tertiary;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: hints.map((h) {
        final icon = _iconFor(h.key);
        final label = _humanize(h.key);

        return Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: dark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: accent,
                  ),
                ),
              ),
              if (h.value > 1) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '×${h.value}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
