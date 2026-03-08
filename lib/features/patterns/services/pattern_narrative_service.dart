import 'package:flutter/foundation.dart';

import '../../../core/services/ai_service.dart';
import '../models/pattern_analysis.dart';

/// Feeds the full [PatternAnalysis] into the AI and returns a short
/// narrative that reads like the body talking to its human — keeping
/// the BodyPress journal spirit alive on the Patterns page.
class PatternNarrativeService {
  final AiService _ai;

  PatternNarrativeService(this._ai);

  /// Generate a 3–5 sentence narrative summarising the user's patterns.
  ///
  /// Returns `null` on any failure (no AI configured, network, etc.).
  Future<String?> generate(PatternAnalysis analysis) async {
    if (analysis.analyzedCaptures == 0) return null;

    final prompt = _buildPrompt(analysis);
    try {
      final result = await _ai.ask(
        prompt,
        systemPrompt: _systemPrompt,
        temperature: 0.75,
        maxTokens: 300,
      );
      // Strip surrounding quotes if the model wraps it
      return result.trim().replaceAll(RegExp(r"""^["']+|["']+$"""), '');
    } catch (e) {
      debugPrint('[PatternNarrative] AI error: $e');
      return null;
    }
  }

  // ── Prompts ─────────────────────────────────────────────────────────────

  static const _systemPrompt = '''
You are writing a short body-pattern narrative for BodyPress — a personal body journal app.
Speak as the body itself, addressing the user in second person ("you").
Be warm, wise, and grounded in the data provided. No fluff.
3–5 sentences maximum. No headings, no bullet points, no markdown.
Highlight the most meaningful pattern or correlation you see.
End with one forward-looking observation or gentle nudge.''';

  String _buildPrompt(PatternAnalysis a) {
    final buf = StringBuffer();
    buf.writeln('Here is the user\'s aggregated body-pattern data:');
    buf.writeln();

    // Captures
    buf.writeln(
      '• ${a.analyzedCaptures} of ${a.totalCaptures} captures analysed.',
    );

    // Energy
    buf.writeln(
      '• Energy breakdown: '
      'high ${a.energyBreakdown['high'] ?? 0}, '
      'medium ${a.energyBreakdown['medium'] ?? 0}, '
      'low ${a.energyBreakdown['low'] ?? 0}.',
    );

    // Top themes + trends
    if (a.topThemes.isNotEmpty) {
      final themed = a.topThemes
          .take(6)
          .map((e) {
            final trend = a.themeTrends[e.key];
            final arrow = trend != null && trend.abs() > 0.15
                ? (trend > 0 ? ' ↑' : ' ↓')
                : '';
            return '${e.key} ×${e.value}$arrow';
          })
          .join(', ');
      buf.writeln('• Top themes: $themed.');
    }

    // Theme–energy links
    if (a.themeEnergyMap.isNotEmpty) {
      final links = <String>[];
      for (final entry in a.themeEnergyMap.entries) {
        final counts = entry.value;
        final total =
            (counts['high'] ?? 0) +
            (counts['medium'] ?? 0) +
            (counts['low'] ?? 0);
        if (total < 3) continue;
        final highPct = ((counts['high'] ?? 0) / total * 100).round();
        final lowPct = ((counts['low'] ?? 0) / total * 100).round();
        if (highPct >= 60) {
          links.add('"${entry.key}" → high energy $highPct%');
        } else if (lowPct >= 60) {
          links.add('"${entry.key}" → low energy $lowPct%');
        }
      }
      if (links.isNotEmpty) {
        buf.writeln('• Theme–energy correlations: ${links.join('; ')}.');
      }
    }

    // Co-occurrences
    if (a.coOccurrences.isNotEmpty) {
      final pairs = a.coOccurrences
          .take(4)
          .map((e) => '${e.key} ×${e.value}')
          .join(', ');
      buf.writeln('• Co-occurring themes: $pairs.');
    }

    // Rhythms
    if (a.timeOfDayDistribution.isNotEmpty) {
      final sorted = a.timeOfDayDistribution.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final peak = sorted.first;
      buf.writeln(
        '• Peak capture window: ${peak.key} (${peak.value} captures).',
      );
    }

    // Body signals
    if (a.bodySignalDistribution.isNotEmpty) {
      final sorted = a.bodySignalDistribution.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.take(3).map((e) => '${e.key} ×${e.value}').join(', ');
      buf.writeln('• Body signals: $top.');
    }

    // AI pattern hints
    if (a.aggregatedPatternHints.isNotEmpty) {
      final hints = a.aggregatedPatternHints
          .take(4)
          .map((e) => e.key)
          .join(', ');
      buf.writeln('• AI-observed patterns: $hints.');
    }

    // Recurring signals
    if (a.topSignals.isNotEmpty) {
      final sigs = a.topSignals
          .take(4)
          .map((e) => '${e.key} ×${e.value}')
          .join(', ');
      buf.writeln('• Recurring signals: $sigs.');
    }

    buf.writeln();
    buf.writeln(
      'Write a short narrative (3–5 sentences) that synthesises these '
      'patterns. Speak as the body. Be specific — reference the actual '
      'themes and data. Plain text only.',
    );

    return buf.toString();
  }
}
