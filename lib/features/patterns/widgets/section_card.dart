import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Themed section card with an expandable ⓘ info panel for transparency.
///
/// Every section on the Patterns page wraps in this so users can tap ⓘ
/// to see exactly how the data is sourced, computed, and what it means.
/// Includes a staggered entrance animation (fade + slide).
class SectionCard extends StatefulWidget {
  /// Section heading shown in UPPERCASE next to the ⓘ icon.
  final String title;

  /// Plain-language explanation shown when ⓘ is tapped.
  final String explanation;

  /// Optional data-source note (e.g. "AI metadata · stressLevel 1–10").
  final String? dataSource;

  /// The actual section content.
  final Widget child;

  /// Stagger index — higher = later entrance (80 ms per step).
  final int animationIndex;

  const SectionCard({
    super.key,
    required this.title,
    required this.explanation,
    this.dataSource,
    required this.child,
    this.animationIndex = 0,
  });

  @override
  State<SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<SectionCard>
    with SingleTickerProviderStateMixin {
  bool _showInfo = false;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideIn;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
        );
    Future.delayed(Duration(milliseconds: 80 * widget.animationIndex), () {
      if (mounted) _entranceCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeIn,
      child: SlideTransition(
        position: _slideIn,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row with ⓘ ──────────────────────────────────
              Row(
                children: [
                  Text(
                    widget.title.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => setState(() => _showInfo = !_showInfo),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _showInfo
                            ? theme.colorScheme.primary.withValues(alpha: 0.12)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: _showInfo
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.3,
                              ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Expandable info panel ──────────────────────────────
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: dark ? 0.08 : 0.05,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.explanation,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.5,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                      if (widget.dataSource != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.storage_rounded,
                              size: 11,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.35,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.dataSource!,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontStyle: FontStyle.italic,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                crossFadeState: _showInfo
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),

              const SizedBox(height: 8),

              // ── Content ────────────────────────────────────────────
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}
