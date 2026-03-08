import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shows the strongest correlations between themes and energy levels.
///
/// For each theme that appears ≥ 3 times, checks whether high or low
/// energy dominates (≥ 60 %). The top 5 strongest links are displayed
/// as actionable insight rows — e.g. "outdoor activity → high energy 80 %".
class ThemeEnergyInsights extends StatelessWidget {
  /// Per-theme energy distribution: theme → { "high": n, "medium": n, "low": n }.
  final Map<String, Map<String, int>> themeEnergyMap;
  final ThemeData theme;
  final bool dark;

  const ThemeEnergyInsights({
    super.key,
    required this.themeEnergyMap,
    required this.theme,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final insights = _deriveInsights();
    if (insights.isEmpty) return const SizedBox.shrink();

    final surfaceColor =
        dark ? const Color(0xFF1A1A1E) : theme.colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: insights.asMap().entries.map((entry) {
          final i = entry.key;
          final insight = entry.value;
          final isLast = i == insights.length - 1;

          return Container(
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outline
                            .withValues(alpha: 0.06),
                      ),
                    ),
                  ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Energy indicator dot
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: insight.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      insight.icon,
                      size: 16,
                      color: insight.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Textual insight
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insight.theme,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          insight.description,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Percentage badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: insight.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${insight.percentage}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: insight.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Derivation ──────────────────────────────────────────────────────────

  List<_Insight> _deriveInsights() {
    final insights = <_Insight>[];

    for (final entry in themeEnergyMap.entries) {
      final name = entry.key;
      final counts = entry.value;
      final total =
          (counts['high'] ?? 0) + (counts['medium'] ?? 0) + (counts['low'] ?? 0);
      if (total < 3) continue; // need enough data

      final highPct = ((counts['high'] ?? 0) / total * 100).round();
      final lowPct = ((counts['low'] ?? 0) / total * 100).round();

      if (highPct >= 60) {
        insights.add(_Insight(
          theme: name,
          description: 'Linked to high energy $highPct % of the time',
          percentage: highPct,
          color: const Color(0xFF4CAF50),
          icon: Icons.bolt_rounded,
          strength: highPct / 100.0,
        ));
      } else if (lowPct >= 60) {
        insights.add(_Insight(
          theme: name,
          description: 'Linked to low energy $lowPct % of the time',
          percentage: lowPct,
          color: const Color(0xFF2196F3),
          icon: Icons.nights_stay_rounded,
          strength: lowPct / 100.0,
        ));
      }
    }

    insights.sort((a, b) => b.strength.compareTo(a.strength));
    return insights.take(5).toList();
  }
}

class _Insight {
  final String theme;
  final String description;
  final int percentage;
  final Color color;
  final IconData icon;
  final double strength;

  const _Insight({
    required this.theme,
    required this.description,
    required this.percentage,
    required this.color,
    required this.icon,
    required this.strength,
  });
}
