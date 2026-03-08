import 'dart:math' as math;

import '../../../core/models/capture_entry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Pattern Analysis — real correlation / trend / cluster extraction
//
// Goes beyond simple frequency counts to surface actual body-pattern
// intelligence: which themes predict energy levels, what's trending up or
// down, which themes cluster together, and what daily rhythms emerge.
// ─────────────────────────────────────────────────────────────────────────────

/// Enriched analysis derived from [CaptureEntry] AI metadata.
class PatternAnalysis {
  final int totalCaptures;
  final int analyzedCaptures;

  // ── Frequency data ──────────────────────────────────────────────────────
  final List<MapEntry<String, int>> topThemes;
  final List<MapEntry<String, int>> topTags;
  final List<MapEntry<String, int>> topSignals;
  final Map<String, int> energyBreakdown;
  final List<MomentSnapshot> recentMoments;

  // ── Correlation data ────────────────────────────────────────────────────

  /// Per-theme energy distribution: theme → { "high": n, "medium": n, "low": n }.
  final Map<String, Map<String, int>> themeEnergyMap;

  /// Trend direction −1.0 (fading) → +1.0 (emerging) per theme.
  /// Compares the newer half of captures against the older half.
  final Map<String, double> themeTrends;

  /// Capture count by normalised time-of-day slot.
  final Map<String, int> timeOfDayDistribution;

  /// Theme pairs that co-occur ≥ 2 times, sorted descending.
  final List<MapEntry<String, int>> coOccurrences;

  /// AI-discovered pattern hints aggregated across captures.
  final List<MapEntry<String, int>> aggregatedPatternHints;

  /// Location-context distribution.
  final Map<String, int> locationDistribution;

  /// Body-signal distribution.
  final Map<String, int> bodySignalDistribution;

  const PatternAnalysis({
    required this.totalCaptures,
    required this.analyzedCaptures,
    required this.topThemes,
    required this.topTags,
    required this.topSignals,
    required this.energyBreakdown,
    required this.recentMoments,
    required this.themeEnergyMap,
    required this.themeTrends,
    required this.timeOfDayDistribution,
    required this.coOccurrences,
    required this.aggregatedPatternHints,
    required this.locationDistribution,
    required this.bodySignalDistribution,
  });
}

/// A single capture moment for the "Recent Moments" list.
class MomentSnapshot {
  final DateTime timestamp;
  final String summary;
  final String energyLevel;
  final List<String> tags;
  final String? userMood;

  const MomentSnapshot({
    required this.timestamp,
    required this.summary,
    required this.energyLevel,
    required this.tags,
    this.userMood,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Builder
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a full [PatternAnalysis] from a list of captures.
PatternAnalysis buildPatternAnalysis(List<CaptureEntry> captures) {
  final withMeta = captures.where((c) => c.aiMetadata != null).toList();

  // ── Frequency counts ────────────────────────────────────────────────────
  final themeCount = <String, int>{};
  final tagCount = <String, int>{};
  final signalCount = <String, int>{};
  final energyCount = <String, int>{'high': 0, 'medium': 0, 'low': 0};

  // ── Correlation accumulators ────────────────────────────────────────────
  final themeEnergyMap = <String, Map<String, int>>{};
  final timeOfDayDist = <String, int>{};
  final pairCount = <String, int>{};
  final hintCount = <String, int>{};
  final locationDist = <String, int>{};
  final bodySignalDist = <String, int>{};

  for (final c in withMeta) {
    final m = c.aiMetadata!;
    final energy = m.energyLevel.toLowerCase();

    // — themes + theme-energy correlation —
    for (final t in m.themes) {
      themeCount[t] = (themeCount[t] ?? 0) + 1;
      themeEnergyMap.putIfAbsent(t, () => {'high': 0, 'medium': 0, 'low': 0});
      if (themeEnergyMap[t]!.containsKey(energy)) {
        themeEnergyMap[t]![energy] = themeEnergyMap[t]![energy]! + 1;
      }
    }

    for (final t in m.tags) {
      tagCount[t] = (tagCount[t] ?? 0) + 1;
    }
    for (final s in m.notableSignals) {
      signalCount[s] = (signalCount[s] ?? 0) + 1;
    }
    if (energyCount.containsKey(energy)) {
      energyCount[energy] = energyCount[energy]! + 1;
    }

    // — time-of-day —
    final tod = m.timeOfDay;
    if (tod != null && tod.isNotEmpty) {
      timeOfDayDist[tod] = (timeOfDayDist[tod] ?? 0) + 1;
    }

    // — co-occurrence: all 2-combinations of themes within a capture —
    final themes = m.themes.toList()..sort();
    for (var i = 0; i < themes.length; i++) {
      for (var j = i + 1; j < themes.length; j++) {
        final pair = '${themes[i]} + ${themes[j]}';
        pairCount[pair] = (pairCount[pair] ?? 0) + 1;
      }
    }

    // — AI pattern hints —
    for (final h in m.patternHints) {
      hintCount[h] = (hintCount[h] ?? 0) + 1;
    }

    // — location —
    final loc = m.locationContext;
    if (loc != null && loc.isNotEmpty) {
      locationDist[loc] = (locationDist[loc] ?? 0) + 1;
    }

    // — body signal —
    final bs = m.bodySignal;
    if (bs != null && bs.isNotEmpty) {
      bodySignalDist[bs] = (bodySignalDist[bs] ?? 0) + 1;
    }
  }

  // ── Theme trends (older-half vs newer-half frequency) ───────────────────
  final themeTrends = <String, double>{};
  if (withMeta.length >= 4) {
    final sorted = withMeta.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final mid = sorted.length ~/ 2;
    final olderHalf = sorted.sublist(0, mid);
    final newerHalf = sorted.sublist(mid);

    final olderThemes = <String, int>{};
    final newerThemes = <String, int>{};

    for (final c in olderHalf) {
      for (final t in c.aiMetadata!.themes) {
        olderThemes[t] = (olderThemes[t] ?? 0) + 1;
      }
    }
    for (final c in newerHalf) {
      for (final t in c.aiMetadata!.themes) {
        newerThemes[t] = (newerThemes[t] ?? 0) + 1;
      }
    }

    final olderSize = olderHalf.length.toDouble();
    final newerSize = newerHalf.length.toDouble();
    final allThemes = {...olderThemes.keys, ...newerThemes.keys};

    for (final t in allThemes) {
      final olderFreq = (olderThemes[t] ?? 0) / olderSize;
      final newerFreq = (newerThemes[t] ?? 0) / newerSize;
      final maxFreq = math.max(math.max(olderFreq, newerFreq), 0.01);
      themeTrends[t] = ((newerFreq - olderFreq) / maxFreq).clamp(-1.0, 1.0);
    }
  }

  // ── Sort helpers ────────────────────────────────────────────────────────
  List<MapEntry<String, int>> top(Map<String, int> map, {int n = 12}) =>
      (map.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
          .take(n)
          .toList();

  final recentMoments = withMeta
      .take(20)
      .map(
        (c) => MomentSnapshot(
          timestamp: c.timestamp,
          summary: c.aiMetadata!.summary,
          energyLevel: c.aiMetadata!.energyLevel,
          tags: c.aiMetadata!.tags.take(3).toList(),
          userMood: c.userMood,
        ),
      )
      .toList();

  return PatternAnalysis(
    totalCaptures: captures.length,
    analyzedCaptures: withMeta.length,
    topThemes: top(themeCount),
    topTags: top(tagCount),
    topSignals: top(signalCount, n: 8),
    energyBreakdown: energyCount,
    recentMoments: recentMoments,
    themeEnergyMap: themeEnergyMap,
    themeTrends: themeTrends,
    timeOfDayDistribution: timeOfDayDist,
    coOccurrences: top(pairCount, n: 8).where((e) => e.value >= 2).toList(),
    aggregatedPatternHints: top(hintCount, n: 6),
    locationDistribution: locationDist,
    bodySignalDistribution: bodySignalDist,
  );
}
