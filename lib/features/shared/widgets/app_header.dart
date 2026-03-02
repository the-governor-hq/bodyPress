import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/theme_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  AppHeader — shared top-bar for all main screens
// ─────────────────────────────────────────────────────────────────────────────

/// Consistent top-bar widget used across all main screens.
///
/// Layout (left → right):
///   [title (+ optional subtitle)]  ‥  [primaryAction]  [theme-toggle]
///
/// • [title] — screen name in Playfair Display.
/// • [subtitle] — optional dim caption line (e.g. "12 of 34 analysed").
/// • [primaryAction] — optional inline widget before the theme icon
///   (e.g. a refresh button, a spinner, or a badge row).
class AppHeader extends ConsumerWidget {
  const AppHeader({
    required this.title,
    this.subtitle,
    this.primaryAction,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? primaryAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    final dimColor = dark ? Colors.white38 : Colors.black26;
    final titleColor = dark ? Colors.white : Colors.black87;
    final subColor = dark
        ? Colors.white.withValues(alpha: 0.38)
        : Colors.black.withValues(alpha: 0.42);

    void toggleTheme() {
      final next = switch (themeMode) {
        ThemeMode.system => ThemeMode.dark,
        ThemeMode.dark => ThemeMode.light,
        ThemeMode.light => ThemeMode.system,
      };
      ref.read(themeModeProvider.notifier).setThemeMode(next);
    }

    final themeLabel = switch (themeMode) {
      ThemeMode.dark => 'Dark mode',
      ThemeMode.light => 'Light mode',
      ThemeMode.system => 'System theme',
    };

    final themeIcon = switch (themeMode) {
      ThemeMode.dark => Icons.dark_mode_outlined,
      ThemeMode.light => Icons.light_mode_outlined,
      ThemeMode.system => Icons.brightness_auto_outlined,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Title + subtitle ──────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: subColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Inline primary action (e.g. refresh) ─────────────────────
          if (primaryAction != null) primaryAction!,

          // ── Theme toggle ──────────────────────────────────────────────
          IconButton(
            onPressed: toggleTheme,
            tooltip: themeLabel,
            icon: Icon(themeIcon, color: dimColor, size: 22),
          ),
        ],
      ),
    );
  }
}
