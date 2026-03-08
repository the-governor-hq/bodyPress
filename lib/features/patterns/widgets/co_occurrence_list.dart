import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Displays theme-pairs that frequently co-occur within the same capture.
///
/// When two themes regularly appear together (e.g. "stress + poor sleep")
/// it reveals a behavioural cluster the user can investigate or act on.
class CoOccurrenceList extends StatelessWidget {
  /// Sorted pairs: "themeA + themeB" → count (only ≥ 2 shown).
  final List<MapEntry<String, int>> coOccurrences;
  final ThemeData theme;
  final bool dark;

  const CoOccurrenceList({
    super.key,
    required this.coOccurrences,
    required this.theme,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    if (coOccurrences.isEmpty) return const SizedBox.shrink();

    final surfaceColor =
        dark ? const Color(0xFF1A1A1E) : theme.colorScheme.surface;
    final accent = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: coOccurrences.asMap().entries.map((entry) {
          final i = entry.key;
          final pair = entry.value;
          final isLast = i == coOccurrences.length - 1;
          final parts = pair.key.split(' + ');

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
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Link icon
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.link_rounded,
                      size: 14,
                      color: accent.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Theme pair chips
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chip(parts.first, accent),
                        Icon(
                          Icons.add_rounded,
                          size: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.3),
                        ),
                        _chip(
                          parts.length > 1 ? parts[1] : '?',
                          accent,
                        ),
                      ],
                    ),
                  ),
                  // Count badge
                  Text(
                    '×${pair.value}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent.withValues(alpha: 0.7),
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

  Widget _chip(String text, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: accent,
        ),
      ),
    );
  }
}
