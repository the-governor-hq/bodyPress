import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/ai_models.dart';
import '../models/capture_ai_metadata.dart';
import '../models/capture_entry.dart';
// NutritionLog type used implicitly via CaptureEntry.nutritionData
import 'ai_service.dart';
import 'ble_heart_rate_service.dart';
import 'local_db_service.dart';

/// Background service that generates [CaptureAiMetadata] for every new capture.
///
/// After each capture is saved, `processCapture` is called fire-and-forget
/// style. The AI examines the capture data and returns structured metadata
/// (themes, energy level, notable signals, …) that is streamed into the
/// Patterns screen as it accumulates.
///
/// Processing is idempotent: captures that already have metadata are skipped.
class CaptureMetadataService {
  final AiService _ai;
  final LocalDbService _db;

  /// Guard that prevents concurrent `processAllPendingMetadata` runs
  /// (e.g. when the user navigates to Patterns while a catch-up is already running).
  bool _isProcessingAll = false;

  CaptureMetadataService({required AiService ai, required LocalDbService db})
    : _ai = ai,
      _db = db;

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Generate and persist AI metadata for a single capture.
  ///
  /// If the capture already has metadata or cannot be found, this is a no-op.
  /// On transient failures (network, timeout) retries once after 10 s.
  /// Permanent 4xx errors (bad key, malformed request) are not retried.
  /// All errors are caught and logged — metadata failures never surface to users.
  Future<void> processCapture(String captureId) async {
    const maxAttempts = 2;
    const retryDelay = Duration(seconds: 10);

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final capture = await _db.loadCapture(captureId);
        if (capture == null || capture.aiMetadata != null) return;

        final metadata = await _generateMetadata(capture);
        if (metadata == null) return;

        await _db.updateCaptureAiMetadata(captureId, metadata.encode());
        debugPrint('[CaptureMetadata] ✓ ${captureId.substring(0, 20)}…');
        return;
      } on AiServiceException catch (e) {
        debugPrint(
          '[CaptureMetadata] ✗ AI error for $captureId (attempt $attempt/$maxAttempts): $e',
        );
        // Permanent client errors (wrong key, 400 bad request) must not be retried.
        final isPermanent =
            e.statusCode != null && e.statusCode! >= 400 && e.statusCode! < 500;
        if (isPermanent || attempt >= maxAttempts) return;
        await Future<void>.delayed(retryDelay);
      } catch (e) {
        debugPrint(
          '[CaptureMetadata] ✗ error for $captureId (attempt $attempt/$maxAttempts): $e',
        );
        if (attempt >= maxAttempts) return;
        await Future<void>.delayed(retryDelay);
      }
    }
  }

  /// Process all captures that have no AI metadata yet.
  ///
  /// [onProgress] is called after each capture attempt with
  /// `(done, total)` counts — use it to drive a progress UI.
  ///
  /// Concurrent calls are short-circuited: if a run is already in progress
  /// (e.g. started from the Patterns screen while startup catch-up is running)
  /// the duplicate call returns 0 immediately without spawning a second loop.
  ///
  /// Useful on app start to catch up on any captures that failed or were
  /// created before this feature existed. Returns the number processed.
  Future<int> processAllPendingMetadata({
    void Function(int done, int total)? onProgress,
  }) async {
    if (_isProcessingAll) {
      debugPrint(
        '[CaptureMetadata] processAllPendingMetadata already running — skipping duplicate call.',
      );
      return 0;
    }
    _isProcessingAll = true;
    try {
      final allCaptures = await _db.loadCaptures();
      final pending = allCaptures.where((c) => c.aiMetadata == null).toList();

      debugPrint(
        '[CaptureMetadata] Processing ${pending.length} pending captures…',
      );

      // Report the initial total immediately so the UI can show the denominator.
      onProgress?.call(0, pending.length);

      int processed = 0;
      for (final capture in pending) {
        try {
          final metadata = await _generateMetadata(capture);
          if (metadata != null) {
            await _db.updateCaptureAiMetadata(capture.id, metadata.encode());
            processed++;
          }
        } catch (e) {
          debugPrint('[CaptureMetadata] ✗ error for ${capture.id}: $e');
        }
        // Always tick progress, even on failure, so the bar keeps moving.
        onProgress?.call(processed, pending.length);
      }

      debugPrint(
        '[CaptureMetadata] Done — $processed/${pending.length} processed.',
      );
      return processed;
    } finally {
      _isProcessingAll = false;
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Call the AI and parse the response into a [CaptureAiMetadata].
  Future<CaptureAiMetadata?> _generateMetadata(CaptureEntry capture) async {
    final prompt = _buildPrompt(capture);

    final raw = await _ai.ask(
      prompt,
      systemPrompt:
          'You are a holistic body-data analyst specializing in longitudinal wellness patterns. '
          'You receive biometric and contextual snapshots and return structured JSON optimized for multi-day correlation analysis. '
          'Focus on identifying CORRELABLE patterns: how time-of-day, day-type, location, weather, and activities relate to wellness outcomes. '
          'Always respond with ONLY the JSON object, no markdown fences, no commentary.',
      temperature: 0.3,
      maxTokens: 600,
    );

    return _parseResponse(raw);
  }

  /// Compute temporal context for better AI understanding.
  Map<String, String> _getTemporalContext(DateTime ts) {
    final hour = ts.hour;
    final weekday = ts.weekday; // 1=Monday, 7=Sunday

    // Time of day classification
    String timeOfDay;
    if (hour >= 5 && hour < 7) {
      timeOfDay = 'early-morning';
    } else if (hour >= 7 && hour < 12) {
      timeOfDay = 'morning';
    } else if (hour >= 12 && hour < 14) {
      timeOfDay = 'midday';
    } else if (hour >= 14 && hour < 17) {
      timeOfDay = 'afternoon';
    } else if (hour >= 17 && hour < 21) {
      timeOfDay = 'evening';
    } else if (hour >= 21 || hour < 1) {
      timeOfDay = 'night';
    } else {
      timeOfDay = 'late-night';
    }

    // Day type
    final dayType = (weekday >= 6) ? 'weekend' : 'weekday';

    // Day name
    const dayNames = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayName = dayNames[weekday];

    // Season (Northern hemisphere approximation)
    final month = ts.month;
    String season;
    if (month >= 3 && month <= 5) {
      season = 'spring';
    } else if (month >= 6 && month <= 8) {
      season = 'summer';
    } else if (month >= 9 && month <= 11) {
      season = 'autumn';
    } else {
      season = 'winter';
    }

    return {
      'timeOfDay': timeOfDay,
      'dayType': dayType,
      'dayName': dayName,
      'season': season,
      'hour': hour.toString().padLeft(2, '0'),
    };
  }

  /// Build the text prompt sent to the AI.
  String _buildPrompt(CaptureEntry c) {
    final buf = StringBuffer();
    final temporal = _getTemporalContext(c.timestamp);

    buf.writeln(
      'Analyse this body/context capture and return structured JSON metadata optimized for MULTI-DAY PATTERN CORRELATION.',
    );
    buf.writeln();
    buf.writeln(
      'Your goal: Generate metadata that enables discovering patterns like:',
    );
    buf.writeln('  - "Mornings after poor sleep correlate with low energy"');
    buf.writeln('  - "Outdoor activity on weekends boosts mood"');
    buf.writeln('  - "High stress on Mondays correlates with work location"');
    buf.writeln('  - "Weather impacts energy levels"');
    buf.writeln(
      '  - "Late-night sugar intake correlates with morning HRV dip"',
    );
    buf.writeln(
      '  - "High-calorie snacks before bed predict sluggishness next morning"',
    );
    buf.writeln();

    // ── Temporal Context ──────────────────────────────────────────────────
    buf.writeln('═══ TEMPORAL CONTEXT ═══');
    buf.writeln('• Timestamp   : ${c.timestamp.toIso8601String()}');
    buf.writeln(
      '• Time of day : ${temporal['timeOfDay']} (${temporal['hour']}:00)',
    );
    buf.writeln(
      '• Day         : ${temporal['dayName']} (${temporal['dayType']})',
    );
    buf.writeln('• Season      : ${temporal['season']}');
    buf.writeln();

    // ── User Input ────────────────────────────────────────────────────────
    if (c.userMood != null || (c.userNote != null && c.userNote!.isNotEmpty)) {
      buf.writeln('═══ USER INPUT ═══');
      if (c.userMood != null) buf.writeln('• Mood emoji : ${c.userMood}');
      if (c.userNote != null && c.userNote!.isNotEmpty) {
        buf.writeln('• Note : ${c.userNote}');
      }
      buf.writeln();
    }

    // ── Health Data ───────────────────────────────────────────────────────
    final h = c.healthData;
    if (h != null) {
      buf.writeln('═══ HEALTH METRICS ═══');
      if (h.steps != null) {
        final stepsContext = h.steps! > 8000
            ? '(above average)'
            : h.steps! > 4000
            ? '(moderate)'
            : '(low activity)';
        buf.writeln('• Steps      : ${h.steps} $stepsContext');
      }
      if (h.heartRate != null) {
        final hrContext = h.heartRate! > 100
            ? '(elevated)'
            : h.heartRate! > 70
            ? '(normal)'
            : '(resting)';
        buf.writeln('• Heart rate : ${h.heartRate} bpm $hrContext');
      }
      if (h.sleepHours != null) {
        final sleepContext = h.sleepHours! >= 7
            ? '(good)'
            : h.sleepHours! >= 5
            ? '(insufficient)'
            : '(poor)';
        buf.writeln(
          '• Sleep      : ${h.sleepHours!.toStringAsFixed(1)} hours $sleepContext',
        );
      }
      if (h.calories != null) {
        buf.writeln('• Calories   : ${h.calories!.toStringAsFixed(0)} kcal');
      }
      if (h.workouts != null && h.workouts! > 0) {
        buf.writeln('• Workouts   : ${h.workouts} session(s)');
      }
      if (h.distance != null && h.distance! > 0) {
        final km = (h.distance! / 1000).toStringAsFixed(1);
        buf.writeln('• Distance   : $km km');
      }
      buf.writeln();
    }
    // ── BLE HR Session ────────────────────────────────────────────────────
    final session = c.bleHrSession;
    if (session != null && session.samples.isNotEmpty) {
      buf.writeln('═══ LIVE BLE HEART RATE SESSION ═══');
      buf.writeln(
        'This is a continuous recording from a BLE chest strap / HR monitor,',
      );
      buf.writeln('captured in real time while the user held the shutter.');
      buf.writeln();

      final dur = session.duration;
      final mins = dur.inMinutes;
      final secs = dur.inSeconds % 60;
      buf.writeln('• Device       : ${session.deviceName ?? "BLE HR device"}');
      buf.writeln(
        '• Duration     : ${mins}m ${secs}s (${session.samples.length} readings)',
      );
      buf.writeln(
        '• BPM range    : min ${session.minBpm} / avg ${session.avgBpm} / max ${session.maxBpm}',
      );
      buf.writeln('• BPM trend    : ${session.bpmTrend}');

      final hrv = session.hrv;
      if (hrv != null) {
        buf.writeln();
        buf.writeln('HRV (from ${session.rrMs.length} RR intervals):');
        if (hrv.rmssd != null) {
          buf.writeln(
            '  RMSSD : ${hrv.rmssd!.toStringAsFixed(1)} ms  → ${hrv.stressHint}',
          );
        }
        if (hrv.sdnn != null) {
          buf.writeln('  SDNN  : ${hrv.sdnn!.toStringAsFixed(1)} ms');
        }
        if (hrv.meanRr != null) {
          buf.writeln(
            '  Mean RR: ${hrv.meanRr!.toStringAsFixed(0)} ms  (= ~${(60000 / hrv.meanRr!).toStringAsFixed(0)} bpm avg from RR)',
          );
        }
      } else {
        buf.writeln('  HRV: device did not report RR intervals');
      }
      buf.writeln();

      // Micro-narrative: build a sentence describing the arc.
      _writeBleNarrative(buf, session);
      buf.writeln();
    }
    // ── Environment Data ──────────────────────────────────────────────────
    final e = c.environmentData;
    if (e != null) {
      buf.writeln('═══ ENVIRONMENT ═══');
      if (e.temperature != null) {
        final tempContext = e.temperature! > 30
            ? '(hot)'
            : e.temperature! > 20
            ? '(comfortable)'
            : e.temperature! > 10
            ? '(cool)'
            : '(cold)';
        buf.writeln('• Temperature : ${e.temperature}°C $tempContext');
      }
      if (e.conditions != null) buf.writeln('• Conditions  : ${e.conditions}');
      if (e.aqi != null) {
        final aqiContext = e.aqi! <= 50
            ? '(good)'
            : e.aqi! <= 100
            ? '(moderate)'
            : '(unhealthy)';
        buf.writeln('• Air quality : ${e.aqi} AQI $aqiContext');
      }
      if (e.uvIndex != null) {
        final uvContext = e.uvIndex! >= 8
            ? '(very high)'
            : e.uvIndex! >= 6
            ? '(high)'
            : e.uvIndex! >= 3
            ? '(moderate)'
            : '(low)';
        buf.writeln('• UV index    : ${e.uvIndex} $uvContext');
      }
      if (e.humidity != null) buf.writeln('• Humidity    : ${e.humidity}%');
      buf.writeln();
    }

    // ── Location Data ─────────────────────────────────────────────────────
    final l = c.locationData;
    if (l != null) {
      buf.writeln('═══ LOCATION ═══');
      if (l.city != null) buf.writeln('• City    : ${l.city}');
      if (l.region != null) buf.writeln('• Region  : ${l.region}');
      if (l.country != null) buf.writeln('• Country : ${l.country}');
      buf.writeln(
        '(Infer location_context: home/work/gym/outdoors/transit/social/other)',
      );
      buf.writeln();
    }

    // ── Calendar Context ──────────────────────────────────────────────────
    if (c.calendarEvents.isNotEmpty) {
      buf.writeln('═══ CALENDAR ═══');
      buf.writeln('• Events: ${c.calendarEvents.join(', ')}');
      buf.writeln(
        '(Consider: Do these events suggest work, social, or personal time?)',
      );
      buf.writeln();
    }

    // ── Nutrition / Food Scans ──────────────────────────────────────────────
    if (c.nutritionData.isNotEmpty) {
      buf.writeln('═══ NUTRITION / FOOD SCANS ═══');
      buf.writeln(
        'The user scanned ${c.nutritionData.length} food product(s) with this capture.',
      );
      buf.writeln(
        'Use this for nutrition-health CORRELATION: e.g. sugar intake → next-day HRV dip, late-night snacking → morning sluggishness.',
      );
      buf.writeln();
      for (final food in c.nutritionData) {
        buf.writeln('• ${food.displayLabel}');
        if (food.nutriScore != null) {
          buf.writeln('  Nutri-Score: ${food.nutriScore!.toUpperCase()}');
        }
        if (food.novaGroup != null) {
          final desc = food.novaGroup == 4
              ? '(ultra-processed)'
              : food.novaGroup == 3
              ? '(processed)'
              : food.novaGroup == 2
              ? '(processed culinary)'
              : '(unprocessed)';
          buf.writeln('  NOVA group: ${food.novaGroup} $desc');
        }
        final facts = food.per100g;
        if (facts != null) {
          buf.writeln('  Per 100g: ${facts.macroLine}');
        }
        final servFacts = food.perServing;
        if (servFacts != null && food.servingSize != null) {
          buf.writeln(
            '  Per serving (${food.servingSize}): ${servFacts.macroLine}',
          );
        }
      }
      buf.writeln();
    }

    // ── Capture Metadata ──────────────────────────────────────────────────
    buf.writeln('═══ CAPTURE INFO ═══');
    buf.writeln('• Source  : ${c.source.name}');
    if (c.trigger != null) buf.writeln('• Trigger : ${c.trigger!.name}');
    if (c.batteryLevel != null) {
      buf.writeln('• Battery : ${c.batteryLevel}%');
    }
    buf.writeln();

    // ── Output Schema ─────────────────────────────────────────────────────
    buf.writeln('═══ REQUIRED OUTPUT ═══');
    buf.writeln('Return ONLY valid JSON with this exact structure:');
    buf.writeln('''{
  "summary": "<one sentence describing this moment>",
  "themes": ["<2-4 themes like: recovery, productive, stress, active, relaxed, social, focused>"],
  "energy_level": "<high|medium|low>",
  "mood_assessment": "<brief mood description>",
  "tags": ["<3-5 searchable tags>"],
  "notable_signals": ["<any significant health/environment signals>"],
  
  "time_of_day": "<early-morning|morning|midday|afternoon|evening|night|late-night>",
  "day_type": "<weekday|weekend>",
  "activity_category": "<active|light-activity|sedentary|recovering|sleeping>",
  "location_context": "<home|work|gym|outdoors|transit|social|other>",
  "sleep_quality": <1-10 or null if no sleep data>,
  "stress_level": <1-10 based on all signals>,
  "weather_impact": "<positive|neutral|negative>",
  "social_context": "<alone|with-others|unknown>",
  "body_signal": "<primary body state: well-rested|fatigued|energized|recovering|stressed|calm>",
  "environment_score": <1-10 based on AQI, UV, weather>,
  "pattern_hints": ["<2-3 correlation hypotheses like: post-workout-energy, weekday-stress, weather-mood-link, late-night-sugar-hrv-dip>"],
  "hrv_context": "<null, or a brief interpretation of the HRV/HR data: e.g. relaxed-autonomic-tone, pre-exertion-elevated, post-workout-recovery>",
  "hr_arc": "<null, or one sentence describing the BPM story: trend, notable spikes, what it may suggest>",
  "nutrition_context": "<null, or a brief analysis of the scanned food: quality, sugar load, ultra-processing level, and predicted next-day impact on HRV/energy>"
}''');

    return buf.toString();
  }

  /// Writes a one-sentence narrative of the BLE HR session arc into [buf].
  void _writeBleNarrative(StringBuffer buf, BleHrSession session) {
    if (session.samples.isEmpty) return;
    final first = session.samples.first.bpm;
    final last = session.samples.last.bpm;
    final avg = session.avgBpm ?? first;
    final max = session.maxBpm ?? first;
    final min = session.minBpm ?? first;
    final trend = session.bpmTrend;

    buf.writeln('HR STORY (use this as narrative context for ai):');
    buf.write(
      '  BPM started at $first, averaged $avg, peaked at $max, settled to $last bpm. '
      'Overall trend: $trend.',
    );
    if (max - min >= 20) {
      buf.write(
        ' Notable swing of ${max - min} bpm — possible activity or stress spike.',
      );
    }
    final hrv = session.hrv;
    if (hrv?.rmssd != null) {
      buf.write(
        ' Autonomic tone: ${hrv!.stressHint} (RMSSD ${hrv.rmssd!.toStringAsFixed(1)} ms).',
      );
    }
    buf.writeln();
  }

  /// Parse the raw AI text into a [CaptureAiMetadata], stripping any accidental
  /// markdown fences.
  CaptureAiMetadata? _parseResponse(String raw) {
    try {
      // Strip potential markdown fences
      var cleaned = raw.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceAll(RegExp(r'^```[a-z]*\n?', multiLine: false), '')
            .replaceAll(RegExp(r'```$', multiLine: false), '')
            .trim();
      }

      final jsonStart = cleaned.indexOf('{');
      final jsonEnd = cleaned.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final jsonStr = cleaned.substring(jsonStart, jsonEnd + 1);
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return CaptureAiMetadata.fromJson({
        ...decoded,
        'generated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint(
        '[CaptureMetadata] Failed to parse AI response: $e\nRaw: $raw',
      );
      return null;
    }
  }
}
