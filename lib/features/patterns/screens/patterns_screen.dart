import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/models/capture_entry.dart';
import '../../../core/services/service_providers.dart';
import '../../body_blog/widgets/weekly_self_portrait.dart';
import '../../shared/widgets/app_header.dart';
import '../models/pattern_analysis.dart';
import '../services/pattern_narrative_service.dart';
import '../widgets/co_occurrence_list.dart';
import '../widgets/pattern_hints_card.dart';
import '../widgets/pattern_narrative_card.dart';
import '../widgets/rhythm_strip.dart';
import '../widgets/section_card.dart';
import '../widgets/theme_energy_insights.dart';

// ── Data providers ──────────────────────────────────────────────────────────

final _allCapturesProvider = FutureProvider.autoDispose<List<CaptureEntry>>(
  (ref) => ref.read(captureServiceProvider).getCaptures(),
);

// ── Interval selector ────────────────────────────────────────────────────────

enum _PatternInterval {
  week('7 days', 7),
  month('30 days', 30),
  quarter('90 days', 90),
  all('All', 0);

  const _PatternInterval(this.label, this.days);
  final String label;
  final int days;
}

List<CaptureEntry> _filterByInterval(
  List<CaptureEntry> captures,
  _PatternInterval interval,
) {
  if (interval == _PatternInterval.all) return captures;
  final cutoff = DateTime.now().subtract(Duration(days: interval.days));
  return captures.where((c) => c.timestamp.isAfter(cutoff)).toList();
}

// ── Aggregated patterns ─────────────────────────────────────────────────────
// Model + builder live in pattern_analysis.dart

// ── Screen ──────────────────────────────────────────────────────────────────

/// Patterns tab — surfaces AI-derived trends from accumulated captures.
///
/// Each capture is analysed in the background by [CaptureMetadataService].
/// This screen aggregates the resulting metadata into themes, energy trends,
/// and notable signals growing over time.
class PatternsScreen extends ConsumerStatefulWidget {
  const PatternsScreen({super.key});

  @override
  ConsumerState<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends ConsumerState<PatternsScreen> {
  // ── Interval filter ─────────────────────────────────────────────────────
  _PatternInterval _interval = _PatternInterval.all;

  // ── Analysis progress ───────────────────────────────────────────────────
  int _analyzingDone = 0;
  int _analyzingTotal = 0; // 0 = idle (not started), >0 = in progress or done
  bool _justFinished = false;

  bool get _isAnalyzing =>
      _analyzingTotal > 0 && _analyzingDone < _analyzingTotal;

  // ── Narrative ───────────────────────────────────────────────────────────
  String? _narrative;
  bool _narrativeLoading = false;
  /// Track which analysis hash we last requested narrative for.
  int _lastNarrativeHash = 0;

  @override
  void initState() {
    super.initState();
    // Catch up on any captures that failed to process or pre-date this feature.
    Future.microtask(() {
      if (!mounted) return;
      final metaSvc = ref.read(captureMetadataServiceProvider);
      metaSvc.processAllPendingMetadata(
        onProgress: (done, total) {
          if (!mounted || total == 0) return;
          setState(() {
            _analyzingDone = done;
            _analyzingTotal = total;
          });
          // When the last item finishes, refresh the captures list
          // and show a brief “all done” confirmation.
          if (done >= total) {
            ref.invalidate(_allCapturesProvider);
            setState(() => _justFinished = true);
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) setState(() => _justFinished = false);
            });
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final capturesAsync = ref.watch(_allCapturesProvider);

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0D0D0F) : const Color(0xFFF6F6F8),
      body: SafeArea(
        child: capturesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Text(
              'Could not load captures: $e',
              style: GoogleFonts.inter(fontSize: 14),
            ),
          ),
          data: (captures) {
            if (captures.isEmpty) {
              return _EmptyState(theme: theme);
            }
            final filtered = _filterByInterval(captures, _interval);
            final summary = buildPatternAnalysis(filtered);

            // Trigger narrative generation when data changes
            _maybeGenerateNarrative(summary);

            return _PatternBody(
              summary: summary,
              filtered: filtered,
              totalCaptures: captures.length,
              theme: theme,
              dark: dark,
              isAnalyzing: _isAnalyzing,
              analyzingDone: _analyzingDone,
              analyzingTotal: _analyzingTotal,
              justFinished: _justFinished,
              selectedInterval: _interval,
              onIntervalChanged: (v) {
                setState(() {
                  _interval = v;
                  // Reset narrative when interval changes
                  _narrative = null;
                  _lastNarrativeHash = 0;
                });
              },
              narrative: _narrative,
              narrativeLoading: _narrativeLoading,
            );
          },
        ),
      ),
    );
  }

  /// Fire-and-forget narrative generation. Only re-fires when analysis changes.
  void _maybeGenerateNarrative(PatternAnalysis analysis) {
    final hash = Object.hash(
      analysis.analyzedCaptures,
      analysis.topThemes.length,
      _interval,
    );
    if (hash == _lastNarrativeHash) return;
    _lastNarrativeHash = hash;

    if (analysis.analyzedCaptures < 2) return;

    setState(() => _narrativeLoading = true);
    final svc = PatternNarrativeService(ref.read(aiServiceProvider));
    svc.generate(analysis).then((result) {
      if (!mounted) return;
      setState(() {
        _narrative = result;
        _narrativeLoading = false;
      });
    });
  }
}

// ── Body ────────────────────────────────────────────────────────────────────

class _PatternBody extends StatelessWidget {
  final PatternAnalysis summary;
  final List<CaptureEntry> filtered;
  final int totalCaptures;
  final ThemeData theme;
  final bool dark;
  final bool isAnalyzing;
  final int analyzingDone;
  final int analyzingTotal;
  final bool justFinished;
  final _PatternInterval selectedInterval;
  final ValueChanged<_PatternInterval> onIntervalChanged;
  final String? narrative;
  final bool narrativeLoading;

  const _PatternBody({
    required this.summary,
    required this.filtered,
    required this.totalCaptures,
    required this.theme,
    required this.dark,
    required this.isAnalyzing,
    required this.analyzingDone,
    required this.analyzingTotal,
    required this.justFinished,
    required this.selectedInterval,
    required this.onIntervalChanged,
    required this.narrative,
    required this.narrativeLoading,
  });

  @override
  Widget build(BuildContext context) {
    final showBanner = isAnalyzing || justFinished;

    final intervalSuffix = selectedInterval == _PatternInterval.all
        ? ''
        : ' (${selectedInterval.label})';

    return Column(
      children: [
        AppHeader(
          title: 'Patterns',
          subtitle:
              '${summary.analyzedCaptures} of $totalCaptures analysed$intervalSuffix',
        ),

        // ── Interval picker ──────────────────────────────────────────
        _IntervalPicker(
          selected: selectedInterval,
          onChanged: onIntervalChanged,
          theme: theme,
          dark: dark,
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              final container = ProviderScope.containerOf(context);
              container.invalidate(_allCapturesProvider);
            },
            color: theme.colorScheme.primary,
            child: CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(child: SizedBox(height: 12)),

                if (showBanner)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: _AnalysisBanner(
                        done: analyzingDone,
                        total: analyzingTotal,
                        justFinished: justFinished,
                        theme: theme,
                      ),
                    ),
                  ),

                // ── 0. Body Story (AI narrative) ────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: PatternNarrativeCard(
                      narrative: narrative,
                      isLoading: narrativeLoading,
                    ),
                  ),
                ),

                // ── 1. Weekly Self-Portrait ──────────────────────────
                SliverToBoxAdapter(
                  child: SectionCard(
                    title: 'Weekly Self-Portrait',
                    explanation:
                        'A 4-axis radar of the last 7 days. Each axis '
                        'represents a dimension of your body state:\n'
                        '• Energy — AI-assessed from health signals '
                        '(high → 0.9, medium → 0.55, low → 0.25)\n'
                        '• Calm — inverse of stress level (1–10 scale)\n'
                        '• Sleep — sleep quality score (1–10 scale)\n'
                        '• Motion — activity category '
                        '(active → 0.9, sedentary → 0.25)\n\n'
                        'Older days fade; today is vivid. '
                        'The composite bar = average of all four.',
                    dataSource:
                        'AI metadata · energyLevel · stressLevel · '
                        'sleepQuality · activityCategory',
                    animationIndex: 0,
                    child: WeeklySelfPortrait(captures: filtered),
                  ),
                ),

                if (summary.analyzedCaptures > 0) ...[
                  // ── 2. Energy Distribution ─────────────────────────
                  SliverToBoxAdapter(
                    child: SectionCard(
                      title: 'Energy Distribution',
                      explanation:
                          'How many of your captures were tagged as '
                          'high, medium, or low energy by the AI. '
                          'Energy is derived from your step count, '
                          'heart rate, sleep quality, and activity '
                          'patterns at the time of capture.',
                      dataSource: 'AI metadata · energyLevel',
                      animationIndex: 1,
                      child: _EnergyBar(
                        breakdown: summary.energyBreakdown,
                        total: summary.analyzedCaptures,
                        theme: theme,
                        dark: dark,
                      ),
                    ),
                  ),

                  // ── 3. Theme–Energy Links (NEW) ────────────────────
                  if (summary.themeEnergyMap.isNotEmpty)
                    SliverToBoxAdapter(
                      child: SectionCard(
                        title: 'Theme–Energy Links',
                        explanation:
                            'Correlations between recurring themes and '
                            'your energy level. If a theme appears ≥ 3 '
                            'times and ≥ 60 % are at the same energy '
                            'level, it surfaces here. These are '
                            'actionable: lean into high-energy themes, '
                            'investigate low-energy ones.',
                        dataSource: 'Cross-reference: themes × energyLevel',
                        animationIndex: 2,
                        child: ThemeEnergyInsights(
                          themeEnergyMap: summary.themeEnergyMap,
                          theme: theme,
                          dark: dark,
                        ),
                      ),
                    ),
                ],

                // ── 4. Top Themes (with trends) ──────────────────────
                if (summary.topThemes.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SectionCard(
                      title: 'Top Themes',
                      explanation:
                          'Recurring themes identified by the AI across '
                          'your captures. The count badge shows '
                          'frequency. Trend arrows (↑ emerging, '
                          '↓ fading) compare the newer half of your '
                          'data against the older half. The coloured '
                          'dot shows the dominant energy level when '
                          'this theme appears.',
                      dataSource: 'AI metadata · themes[]',
                      animationIndex: 3,
                      child: _FrequencyChips(
                        entries: summary.topThemes,
                        color: theme.colorScheme.primary,
                        theme: theme,
                        dark: dark,
                        trends: summary.themeTrends,
                        themeEnergyMap: summary.themeEnergyMap,
                      ),
                    ),
                  ),

                // ── 5. Keywords (with trends) ────────────────────────
                if (summary.topTags.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SectionCard(
                      title: 'Keywords',
                      explanation:
                          'Concise keyword tags extracted from each '
                          'capture for search and grouping. Higher '
                          'counts mean a keyword is a recurring part '
                          'of your body story.',
                      dataSource: 'AI metadata · tags[]',
                      animationIndex: 4,
                      child: _FrequencyChips(
                        entries: summary.topTags,
                        color: Colors.teal,
                        theme: theme,
                        dark: dark,
                      ),
                    ),
                  ),

                // ── 6. Co-Occurring Themes (NEW) ─────────────────────
                if (summary.coOccurrences.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SectionCard(
                      title: 'Co-Occurring Themes',
                      explanation:
                          'Theme pairs that appear together in the '
                          'same capture at least twice. Clusters '
                          'reveal behavioural links — e.g. "stress + '
                          'poor sleep" suggests one drives the other.',
                      dataSource: 'Pairwise co-occurrence within each capture',
                      animationIndex: 5,
                      child: CoOccurrenceList(
                        coOccurrences: summary.coOccurrences,
                        theme: theme,
                        dark: dark,
                      ),
                    ),
                  ),

                // ── 7. Your Rhythms (NEW) ────────────────────────────
                if (summary.timeOfDayDistribution.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SectionCard(
                      title: 'Your Rhythms',
                      explanation:
                          'Distribution of your captures across the '
                          'day. Circadian science shows that body '
                          'metrics like heart rate, cortisol, and '
                          'energy follow a daily cycle. Seeing when '
                          'you are most captured helps identify your '
                          'peak and recovery windows.',
                      dataSource: 'AI metadata · timeOfDay',
                      animationIndex: 6,
                      child: RhythmStrip(
                        timeOfDayDistribution: summary.timeOfDayDistribution,
                        theme: theme,
                        dark: dark,
                      ),
                    ),
                  ),

                // ── 8. AI Pattern Insights (NEW) ─────────────────────
                if (summary.aggregatedPatternHints.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SectionCard(
                      title: 'AI Pattern Insights',
                      explanation:
                          'Correlations the AI discovered during '
                          'analysis — e.g. "consistent-morning-routine" '
                          'or "weather-affects-mood". These are '
                          'hypothesis-level observations that gain '
                          'confidence as more captures confirm them.',
                      dataSource: 'AI metadata · patternHints[]',
                      animationIndex: 7,
                      child: PatternHintsCard(
                        hints: summary.aggregatedPatternHints,
                        theme: theme,
                        dark: dark,
                      ),
                    ),
                  ),

                // ── 9. Recurring Signals ─────────────────────────────
                if (summary.topSignals.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SectionCard(
                      title: 'Recurring Signals',
                      explanation:
                          'Notable data signals the AI flagged — like '
                          '"elevated heart rate" or "high UV". These '
                          'are individual observations. When one '
                          'recurs many times, it deserves attention.',
                      dataSource: 'AI metadata · notableSignals[]',
                      animationIndex: 8,
                      child: _SignalList(
                        signals: summary.topSignals,
                        theme: theme,
                        dark: dark,
                      ),
                    ),
                  ),

                // ── 10. Recent Moments ───────────────────────────────
                if (summary.recentMoments.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionCard(
                      title: 'Recent Moments',
                      explanation:
                          'Your latest capture summaries — the raw '
                          'building blocks of all the patterns above. '
                          'Each moment shows the AI summary, energy '
                          'level, mood, and tags at that instant.',
                      dataSource: 'AI metadata · summary',
                      animationIndex: 9,
                      child: const SizedBox.shrink(),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                        child: _MomentCard(
                          moment: summary.recentMoments[i],
                          theme: theme,
                          dark: dark,
                        ),
                      ),
                      childCount: summary.recentMoments.length,
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _AnalysisBanner extends StatelessWidget {
  final int done;
  final int total;
  final bool justFinished;
  final ThemeData theme;

  const _AnalysisBanner({
    required this.done,
    required this.total,
    required this.justFinished,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? done / total : 0.0;
    final remaining = total - done;

    if (justFinished) {
      // Done state — brief success confirmation
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: Color(0xFF4CAF50),
            ),
            const SizedBox(width: 10),
            Text(
              'Analysis complete — patterns updated',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
      );
    }

    // In-progress state
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  done == 0
                      ? 'Preparing to analyse $total capture${total == 1 ? '' : 's'}…'
                      : 'Analysing captures — $remaining left',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$done / $total',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: theme.colorScheme.primary.withValues(
                alpha: 0.12,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Results appear below as each capture is processed.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: theme.colorScheme.primary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Interval picker widget ───────────────────────────────────────────────────

class _IntervalPicker extends StatelessWidget {
  final _PatternInterval selected;
  final ValueChanged<_PatternInterval> onChanged;
  final ThemeData theme;
  final bool dark;

  const _IntervalPicker({
    required this.selected,
    required this.onChanged,
    required this.theme,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: _PatternInterval.values.map((interval) {
          final isSelected = interval == selected;
          final accent = theme.colorScheme.primary;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(interval),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? accent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? accent.withValues(alpha: 0.35)
                        : theme.colorScheme.outline.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  interval.label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? accent
                        : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _EnergyBar extends StatelessWidget {
  final Map<String, int> breakdown;
  final int total;
  final ThemeData theme;
  final bool dark;

  const _EnergyBar({
    required this.breakdown,
    required this.total,
    required this.theme,
    required this.dark,
  });

  Color _color(String level) => switch (level) {
    'high' => const Color(0xFF4CAF50),
    'medium' => const Color(0xFFFF9800),
    'low' => const Color(0xFF2196F3),
    _ => Colors.grey,
  };

  IconData _icon(String level) => switch (level) {
    'high' => Icons.bolt_rounded,
    'medium' => Icons.water_drop_outlined,
    'low' => Icons.nights_stay_rounded,
    _ => Icons.circle,
  };

  @override
  Widget build(BuildContext context) {
    final surfaceColor = dark
        ? const Color(0xFF1A1A1E)
        : theme.colorScheme.surface;

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
        children: [
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    for (final level in ['high', 'medium', 'low'])
                      if ((breakdown[level] ?? 0) > 0)
                        Flexible(
                          flex: breakdown[level]!,
                          child: Container(color: _color(level)),
                        ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (final level in ['high', 'medium', 'low'])
                _EnergyLegendItem(
                  label: level[0].toUpperCase() + level.substring(1),
                  count: breakdown[level] ?? 0,
                  color: _color(level),
                  icon: _icon(level),
                  theme: theme,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnergyLegendItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  final ThemeData theme;

  const _EnergyLegendItem({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}

class _FrequencyChips extends StatelessWidget {
  final List<MapEntry<String, int>> entries;
  final Color color;
  final ThemeData theme;
  final bool dark;

  /// Optional trend data per entry key: −1..+1 (fading → emerging).
  final Map<String, double>? trends;

  /// Optional theme-to-energy map for showing dominant-energy dot.
  final Map<String, Map<String, int>>? themeEnergyMap;

  const _FrequencyChips({
    required this.entries,
    required this.color,
    required this.theme,
    required this.dark,
    this.trends,
    this.themeEnergyMap,
  });

  /// Dominant energy colour for a given theme.
  Color? _energyDot(String key) {
    final counts = themeEnergyMap?[key];
    if (counts == null) return null;
    final h = counts['high'] ?? 0;
    final m = counts['medium'] ?? 0;
    final l = counts['low'] ?? 0;
    final total = h + m + l;
    if (total < 2) return null;
    if (h >= m && h >= l) return const Color(0xFF4CAF50);
    if (l >= m && l >= h) return const Color(0xFF2196F3);
    return const Color(0xFFFF9800);
  }

  @override
  Widget build(BuildContext context) {
    final maxCount = entries.isEmpty ? 1 : entries.first.value;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries.map((e) {
        final intensity = (e.value / maxCount).clamp(0.15, 1.0);
        final trend = trends?[e.key];
        final dotColor = _energyDot(e.key);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: intensity * 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: intensity * 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dominant-energy dot
              if (dotColor != null) ...[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                e.key,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color.withValues(alpha: dark ? 0.9 : 0.85),
                ),
              ),
              // Trend arrow
              if (trend != null && trend.abs() > 0.15) ...[
                const SizedBox(width: 3),
                Icon(
                  trend > 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  size: 13,
                  color: trend > 0
                      ? const Color(0xFF4CAF50).withValues(alpha: 0.8)
                      : const Color(0xFFE57373).withValues(alpha: 0.8),
                ),
              ],
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: intensity * 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  e.value.toString(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SignalList extends StatelessWidget {
  final List<MapEntry<String, int>> signals;
  final ThemeData theme;
  final bool dark;

  const _SignalList({
    required this.signals,
    required this.theme,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final surfaceColor = dark
        ? const Color(0xFF1A1A1E)
        : theme.colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: signals.asMap().entries.map((entry) {
          final i = entry.key;
          final signal = entry.value;
          final isLast = i == signals.length - 1;
          return Container(
            decoration: isLast
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.colorScheme.outline.withValues(
                          alpha: 0.06,
                        ),
                      ),
                    ),
                  ),
            child: ListTile(
              dense: true,
              leading: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 15,
                  color: Colors.orange.shade400,
                ),
              ),
              title: Text(
                signal.key,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              trailing: Text(
                '×${signal.value}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.orange.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MomentCard extends StatelessWidget {
  final MomentSnapshot moment;
  final ThemeData theme;
  final bool dark;

  const _MomentCard({
    required this.moment,
    required this.theme,
    required this.dark,
  });

  Color _energyColor(String level) => switch (level.toLowerCase()) {
    'high' => const Color(0xFF4CAF50),
    'medium' => const Color(0xFFFF9800),
    'low' => const Color(0xFF2196F3),
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final ec = _energyColor(moment.energyLevel);
    final surfaceColor = dark
        ? const Color(0xFF1A1A1E)
        : theme.colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4, right: 10),
            decoration: BoxDecoration(
              color: ec,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: ec.withValues(alpha: 0.4),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      DateFormat('MMM d, h:mm a').format(moment.timestamp),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                    ),
                    if (moment.userMood != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        moment.userMood!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: ec.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        moment.energyLevel,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: ec,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  moment.summary,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                if (moment.tags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    children: moment.tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.06,
                              ),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '#$t',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final ThemeData theme;
  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insights_rounded,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              'No captures yet',
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Take your first capture and patterns will start building here automatically.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
