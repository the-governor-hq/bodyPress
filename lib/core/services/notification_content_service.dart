import 'dart:math';

import '../models/body_blog_entry.dart';
import '../models/capture_entry.dart';
import 'local_db_service.dart';

/// Title + body pair for a notification.
typedef NotifContent = ({String title, String body});

/// Generates rich, data-driven notification content for BodyPress.
///
/// Reads recent captures and blog entries to produce personalised,
/// emoji-rich notifications with real biometric data and a clear
/// call-to-action every time.
///
/// Designed to work both inside the main isolate (via Riverpod) and in
/// the WorkManager background isolate (direct instantiation).
class NotificationContentService {
  NotificationContentService({required LocalDbService db}) : _db = db;

  final LocalDbService _db;
  final _rng = Random();

  // ── Public API ──────────────────────────────────────────────────────────

  /// Build a personalised notification using today's actual data.
  ///
  /// Returns engaging static content when no sensor data is available yet.
  Future<NotifContent> buildSmartNotification() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Gather real data ─────────────────────────────────────────────────
      final blogEntry = await _db.loadEntry(today);
      final captures = await _db.loadCapturesForDate(today);
      final streak = await _computeStreak();
      final stats = _aggregateCaptures(captures);

      // Build a pool of data-driven candidates ──────────────────────────
      final candidates = <NotifContent>[];

      if (stats.steps != null && stats.steps! > 0) {
        candidates.addAll(_stepsMessages(stats.steps!));
      }
      if (stats.sleepHours != null && stats.sleepHours! > 0) {
        candidates.addAll(_sleepMessages(stats.sleepHours!));
      }
      if (stats.heartRate != null && stats.heartRate! > 0) {
        candidates.addAll(_heartRateMessages(stats.heartRate!));
      }
      if (stats.city != null && stats.temperatureC != null) {
        candidates.addAll(
          _weatherMessages(stats.city!, stats.temperatureC!, stats.weatherDesc),
        );
      }
      if (stats.aqiUs != null && stats.aqiUs! > 80) {
        candidates.addAll(_airQualityMessages(stats.aqiUs!, stats.city));
      }
      if (blogEntry != null) {
        candidates.addAll(_blogReadyMessages(blogEntry));
      }
      if (streak >= 2) {
        candidates.addAll(_streakMessages(streak));
      }
      if (captures.length >= 3) {
        candidates.addAll(_captureCountMessages(captures.length));
      }
      if (stats.workouts != null && stats.workouts! > 0) {
        candidates.addAll(_workoutMessages(stats.workouts!));
      }
      if (stats.calories != null && stats.calories! > 100) {
        candidates.addAll(_calorieMessages(stats.calories!));
      }

      // Return a random data-driven notification, or fall back ──────────
      if (candidates.isNotEmpty) {
        return candidates[_rng.nextInt(candidates.length)];
      }

      // No data yet today → nudge to capture
      return nudgeMessages[_rng.nextInt(nudgeMessages.length)];
    } catch (_) {
      return engagingFallbacks[_rng.nextInt(engagingFallbacks.length)];
    }
  }

  /// Whether a smart notification has already been shown today.
  Future<bool> wasSmartNotifShownToday() async {
    final raw = await _db.getSetting('last_smart_notif_date');
    if (raw == null) return false;
    final today = DateTime.now();
    final todayKey =
        '${today.year}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    return raw == todayKey;
  }

  /// Mark today's smart notification as shown.
  Future<void> markSmartNotifShown() async {
    final today = DateTime.now();
    await _db.setSetting(
      'last_smart_notif_date',
      '${today.year}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}',
    );
  }

  // ── Streak computation ────────────────────────────────────────────────

  Future<int> _computeStreak() async {
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 60; i++) {
      final day = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: i));
      final captures = await _db.loadCapturesForDate(day);
      if (captures.isEmpty) break;
      streak++;
    }
    return streak;
  }

  // ── Capture aggregation ───────────────────────────────────────────────

  _DayStats _aggregateCaptures(List<CaptureEntry> captures) {
    int? bestSteps;
    double? bestSleep;
    int? latestHr;
    double? latestTemp;
    String? latestWeather;
    String? latestCity;
    int? latestAqi;
    int? totalWorkouts;
    double? bestCalories;

    for (final c in captures) {
      final h = c.healthData;
      if (h != null) {
        if (h.steps != null && (bestSteps == null || h.steps! > bestSteps)) {
          bestSteps = h.steps;
        }
        if (h.sleepHours != null &&
            (bestSleep == null || h.sleepHours! > bestSleep)) {
          bestSleep = h.sleepHours;
        }
        if (h.heartRate != null && h.heartRate! > 0) {
          latestHr = h.heartRate;
        }
        if (h.workouts != null && h.workouts! > 0) {
          totalWorkouts = (totalWorkouts ?? 0) + h.workouts!;
        }
        if (h.calories != null &&
            (bestCalories == null || h.calories! > bestCalories)) {
          bestCalories = h.calories;
        }
      }
      final e = c.environmentData;
      if (e != null) {
        if (e.temperature != null) latestTemp = e.temperature;
        if (e.weatherDescription != null) latestWeather = e.weatherDescription;
        if (e.aqi != null) latestAqi = e.aqi;
      }
      final l = c.locationData;
      if (l != null && l.city != null) {
        latestCity = l.city;
      }
    }

    return _DayStats(
      steps: bestSteps,
      sleepHours: bestSleep,
      heartRate: latestHr,
      temperatureC: latestTemp,
      weatherDesc: latestWeather,
      city: latestCity,
      aqiUs: latestAqi,
      workouts: totalWorkouts,
      calories: bestCalories,
    );
  }

  // ── Data-driven message builders ──────────────────────────────────────

  List<NotifContent> _stepsMessages(int steps) {
    if (steps >= 10000) {
      return [
        (
          title: '🏆 ${_fmtSteps(steps)} steps — you crushed it!',
          body:
              'Your body is THRIVING. Read what it has to say about this epic day →',
        ),
        (
          title: '🔥 ${_fmtSteps(steps)} steps and counting!',
          body:
              'Your legs wrote a novel today. Open your body blog to read every chapter →',
        ),
        (
          title: '🚀 ${_fmtSteps(steps)} steps! Who even are you?!',
          body:
              'Seriously impressive. Your body is buzzing — see the full breakdown →',
        ),
      ];
    } else if (steps >= 5000) {
      return [
        (
          title: '🚶 ${_fmtSteps(steps)} steps so far — nice rhythm!',
          body: 'Your body noticed the movement. See today\'s story →',
        ),
        (
          title: '👟 ${_fmtSteps(steps)} steps in the bank',
          body: 'Your body has thoughts about today\'s pace. Check them out →',
        ),
      ];
    } else {
      return [
        (
          title: '🌱 ${_fmtSteps(steps)} steps today',
          body:
              'Every step counts. Your body is tracking it all — see the full picture →',
        ),
      ];
    }
  }

  List<NotifContent> _sleepMessages(double hours) {
    final h = hours.toStringAsFixed(1);
    if (hours >= 8) {
      return [
        (
          title: '😴 ${h}h of sleep — your body is grateful',
          body: 'Well-rested bodies tell the best stories. Read yours →',
        ),
        (
          title: '🌙 Solid $h hours of rest last night',
          body:
              'Your body recharged nicely. See how it\'s reflecting that today →',
        ),
      ];
    } else if (hours >= 6) {
      return [
        (
          title: '🛏️ ${h}h sleep — decent night',
          body: 'Not bad! Your body has some observations. Take a look →',
        ),
      ];
    } else if (hours > 0) {
      return [
        (
          title: '⚡ Only ${h}h of sleep — your body noticed',
          body:
              'Short night. Your body wrote about how it\'s coping. Worth a read →',
        ),
        (
          title: '☕ ${h}h sleep. Coffee alone won\'t fix this.',
          body:
              'Your body has recovery tips baked into today\'s story. Check in →',
        ),
      ];
    }
    return [];
  }

  List<NotifContent> _heartRateMessages(int hr) {
    return [
      (
        title: '❤️ Heart rate: $hr bpm',
        body:
            'Your heart has its own rhythm today. See the full story in your body blog →',
      ),
      (
        title: '💓 $hr bpm — your heart is talking',
        body:
            'Pulse, pace, patterns. Your body captured it all. Read today\'s entry →',
      ),
    ];
  }

  List<NotifContent> _weatherMessages(String city, double temp, String? desc) {
    final t = temp.round();
    final weather = desc ?? '';
    final weatherBit = weather.isNotEmpty ? ' · $weather' : '';
    return [
      (
        title: '🌡️ $t°C in $city$weatherBit',
        body:
            'Your environment shapes your body\'s story. Today\'s chapter is ready →',
      ),
      (
        title: '📍 $city · $t°C — your body feels it',
        body:
            'Temperature, air, UV — see how outdoor conditions show up in your biometrics →',
      ),
    ];
  }

  List<NotifContent> _airQualityMessages(int aqi, String? city) {
    final where = city != null ? ' in $city' : '';
    if (aqi > 150) {
      return [
        (
          title: '🟠 AQI $aqi$where — your body flagged this',
          body:
              'Air quality isn\'t great. Your body blog explains what it means for you →',
        ),
      ];
    }
    return [
      (
        title: '🌫️ AQI $aqi$where today',
        body:
            'Your body is factoring air quality into today\'s narrative. Take a look →',
      ),
    ];
  }

  List<NotifContent> _blogReadyMessages(BodyBlogEntry entry) {
    final mood = entry.moodEmoji.isNotEmpty ? entry.moodEmoji : '📝';
    return [
      (
        title: '$mood "${entry.headline}"',
        body:
            '${entry.summary.length > 80 ? '${entry.summary.substring(0, 77)}…' : entry.summary} — Tap to read →',
      ),
      (
        title: '$mood Your body\'s journal is ready',
        body:
            '"${entry.headline}" — feeling ${entry.mood}. Open to read today\'s narrative →',
      ),
      (
        title: '$mood Fresh body blog just dropped',
        body:
            'Today\'s mood: ${entry.mood}. Your body has a lot to say — dive in →',
      ),
    ];
  }

  List<NotifContent> _streakMessages(int days) {
    if (days >= 30) {
      return [
        (
          title: '🏅 $days-day streak — legendary!',
          body:
              'A whole month of body awareness. Your consistency is inspiring →',
        ),
        (
          title: '👑 $days days. You\'re a machine.',
          body: 'Your body has never been more understood. Keep it going →',
        ),
      ];
    } else if (days >= 7) {
      return [
        (
          title: '🔥 $days days in a row!',
          body:
              'Your body loves the consistency. Keep the streak alive — read today\'s story →',
        ),
        (
          title: '💪 $days-day streak going strong',
          body: 'You\'re building a real body diary. Don\'t break the chain →',
        ),
      ];
    }
    return [
      (
        title: '✨ $days-day streak!',
        body:
            'Your body is becoming a regular author. Keep it going — today\'s post is up →',
      ),
    ];
  }

  List<NotifContent> _captureCountMessages(int count) {
    return [
      (
        title: '📊 $count captures logged today',
        body:
            'Your body has rich data to work with. See the insights it uncovered →',
      ),
      (
        title: '🎯 $count snapshots — data-rich day!',
        body: 'More captures = richer story. Your body blog is packed today →',
      ),
    ];
  }

  List<NotifContent> _workoutMessages(int workouts) {
    return [
      (
        title: '💪 $workouts workout${workouts > 1 ? 's' : ''} logged today!',
        body: 'Your body registered the effort. See how it tells the story →',
      ),
      (
        title:
            '🏋️ You showed up today — $workouts session${workouts > 1 ? 's' : ''}!',
        body:
            'Sweat, heart rate, recovery — your body blog has the full recap →',
      ),
    ];
  }

  List<NotifContent> _calorieMessages(double calories) {
    final cal = calories.round();
    return [
      (
        title: '🔥 $cal kcal burned so far',
        body:
            'Your body is keeping score. See the full energy story in today\'s blog →',
      ),
    ];
  }

  // ── Formatting helpers ────────────────────────────────────────────────

  String _fmtSteps(int steps) {
    if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(1)}K';
    return steps.toString();
  }

  // ── Static message pools ──────────────────────────────────────────────

  /// Nudge messages for days with no data yet.
  static const nudgeMessages = <NotifContent>[
    (
      title: '📱 Your body is waiting to be heard',
      body:
          'No captures yet today. 10 seconds for a quick snapshot — your future self will thank you →',
    ),
    (
      title: '🫣 Radio silence from your body',
      body:
          'It has things to say! Tap for a quick capture and let your body tell its story →',
    ),
    (
      title: '👋 Hey — your body has been quiet today',
      body: 'One quick capture = one data-rich story tonight. Start now →',
    ),
    (
      title: '🤫 Your body blog has a blank page today',
      body: 'Fill it with a capture. Just one tap, real data, zero effort →',
    ),
    (
      title: '⏰ Don\'t leave your body on read',
      body:
          'It\'s been collecting signals all day. Capture them before they fade →',
    ),
    (
      title: '🫠 Your body blog is feeling empty',
      body:
          'Give it something to work with! One capture now = real insights later →',
    ),
    (
      title: '📝 Blank page energy today',
      body: 'Your body wants to write but needs data first. Quick capture? →',
    ),
    (
      title: '🧬 Your body has stories to tell',
      body: 'But it needs a capture first. One tap — that\'s all it takes →',
    ),
  ];

  /// Engaging fallback messages when data can't be read.
  static const engagingFallbacks = <NotifContent>[
    (
      title: '🧬 Your body wrote something today',
      body: 'Steps, sleep, heart rate — it\'s all there. Open your body blog →',
    ),
    (
      title: '📖 New chapter in your body\'s diary',
      body: 'Every day tells a different story. Today\'s is waiting for you →',
    ),
    (
      title: '🔬 Your daily body report is in',
      body: 'Real data, real insights, written by your own body. Read it now →',
    ),
    (
      title: '💡 Your body dropped some knowledge',
      body:
          'Patterns you didn\'t notice, signals you missed. It\'s all in today\'s blog →',
    ),
    (
      title: '🎯 Body check-in time!',
      body:
          'Your body has been tracking everything. See the summary — you might be surprised →',
    ),
    (
      title: '⚡ Fresh insights from your body',
      body:
          'Heart, steps, sleep, mood — compiled into today\'s story. Don\'t miss it →',
    ),
    (
      title: '🌟 Your body\'s daily dispatch',
      body:
          'No fluff, just your real biometrics turned into a story. Tap to read →',
    ),
    (
      title: '🧠 Your body is smarter than you think',
      body: 'It noticed things today. Check out what it observed →',
    ),
    (
      title: '🫀 Pulse. Steps. Sleep. Story.',
      body:
          'Your body turned today\'s numbers into narrative. Read the latest →',
    ),
    (
      title: '📊 Data in, story out',
      body:
          'Your body collected the signals. BodyPress turned them into insight →',
    ),
    (
      title: '🌊 Ride today\'s body wave',
      body:
          'Energy, recovery, movement — your body captured the full picture →',
    ),
    (
      title: '🔋 How\'s your body battery today?',
      body:
          'Sleep, steps, and stress all factor in. Your body blog has the answer →',
    ),
    (
      title: '💬 Your body left you a voice note',
      body: 'Well, a text note. With data. And insights. Open it →',
    ),
    (
      title: '🎤 Your body has the mic today',
      body:
          'It\'s not holding back. Steps, rhythm, environment — all in today\'s narrative →',
    ),
    (
      title: '🪞 Mirror check: the inside edition',
      body:
          'Forget the outside — your body blog shows what\'s really happening →',
    ),
  ];
}

// ── Internal helpers ──────────────────────────────────────────────────────

class _DayStats {
  const _DayStats({
    this.steps,
    this.sleepHours,
    this.heartRate,
    this.temperatureC,
    this.weatherDesc,
    this.city,
    this.aqiUs,
    this.workouts,
    this.calories,
  });

  final int? steps;
  final double? sleepHours;
  final int? heartRate;
  final double? temperatureC;
  final String? weatherDesc;
  final String? city;
  final int? aqiUs;
  final int? workouts;
  final double? calories;
}
