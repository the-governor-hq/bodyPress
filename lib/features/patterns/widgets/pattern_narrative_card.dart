import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A top-of-page narrative card that shows the AI-generated pattern story.
///
/// While loading: subtle shimmer placeholder.
/// On success: the narrative in a softly accented card.
/// On failure / null: gracefully hidden.
class PatternNarrativeCard extends StatefulWidget {
  /// The AI-generated narrative, null while loading or on failure.
  final String? narrative;

  /// True while the AI call is in flight.
  final bool isLoading;

  const PatternNarrativeCard({
    super.key,
    required this.narrative,
    required this.isLoading,
  });

  @override
  State<PatternNarrativeCard> createState() => _PatternNarrativeCardState();
}

class _PatternNarrativeCardState extends State<PatternNarrativeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerCtrl;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to show
    if (!widget.isLoading && widget.narrative == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final accent = theme.colorScheme.primary;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: widget.isLoading
          ? _buildShimmer(theme, dark)
          : _buildCard(theme, dark, accent),
    );
  }

  // ── Loading shimmer ────────────────────────────────────────────────────

  Widget _buildShimmer(ThemeData theme, bool dark) {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (context, child) {
        final t = _shimmerCtrl.value;
        final baseColor = dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04);
        final highlightColor = dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.08);
        final color = Color.lerp(
          baseColor,
          highlightColor,
          (1 + math.sin(t * 6.28)) / 2,
        )!;

        return Container(
          key: const ValueKey('shimmer'),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Composing your body story…',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Placeholder lines
              _shimmerLine(0.92, 10, color),
              const SizedBox(height: 6),
              _shimmerLine(0.80, 10, color),
              const SizedBox(height: 6),
              _shimmerLine(0.65, 10, color),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerLine(double widthFraction, double height, Color color) {
    return FractionallySizedBox(
      widthFactor: widthFraction,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  // ── Narrative card ─────────────────────────────────────────────────────

  Widget _buildCard(ThemeData theme, bool dark, Color accent) {
    return Container(
      key: const ValueKey('narrative'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: dark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: accent.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                'YOUR BODY STORY',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: accent.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Narrative text
          Text(
            widget.narrative!,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              height: 1.55,
              fontWeight: FontWeight.w400,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
