import '../models/ai_models.dart';
import '../models/body_blog_entry.dart';
import 'ai_service.dart';

/// Manages a conversational dialogue between the user and their "body".
///
/// The body speaks in first person, grounded in real biometric data from the
/// current day's [BodyBlogEntry]. The conversation is multi-turn: the service
/// keeps the full message history so the AI maintains context across exchanges.
class BodyDialogueService {
  final AiService _ai;

  BodyDialogueService({required AiService ai}) : _ai = ai;

  /// Start a new conversation seeded with the given [entry]'s data.
  ///
  /// Returns a [BodyDialogueSession] that callers use to send messages
  /// and receive responses.
  BodyDialogueSession startSession(BodyBlogEntry entry) {
    return BodyDialogueSession(ai: _ai, entry: entry);
  }
}

/// A single dialogue session between the user and their body.
///
/// Holds the message history and exposes [send] to continue the conversation.
class BodyDialogueSession {
  final AiService _ai;
  final BodyBlogEntry _entry;
  final List<ChatMessage> _history = [];

  /// Public read-only view of the conversation so far (excluding the system
  /// prompt).  Each message has `role` = "user" or "assistant".
  List<ChatMessage> get messages => List.unmodifiable(_history);

  BodyDialogueSession({required AiService ai, required BodyBlogEntry entry})
    : _ai = ai,
      _entry = entry;

  /// Send a user message and get the body's response.
  ///
  /// Returns the assistant's reply text.  Throws [AiServiceException] on
  /// network / API failure.
  Future<String> send(String userMessage) async {
    _history.add(ChatMessage.user(userMessage));

    // Build the full prompt list: system → history
    final prompt = <ChatMessage>[
      ChatMessage.system(_buildSystemPrompt()),
      ..._history,
    ];

    final response = await _ai.chatCompletion(
      prompt,
      temperature: 0.75,
      maxTokens: 600,
    );

    final reply = response.content;
    _history.add(ChatMessage.assistant(reply));
    return reply;
  }

  // ── private ───────────────────────────────────────────────────────────────

  String _buildSystemPrompt() {
    final s = _entry.snapshot;
    final buf = StringBuffer()
      ..writeln('You ARE the user\'s body — speak in first person ("I", "we").')
      ..writeln(
        'You are warm, honest, and insightful. You draw on real biometric '
        'data to answer questions. Never give medical advice or diagnoses.',
      )
      ..writeln()
      ..writeln('── Today\'s data ──')
      ..writeln('Date: ${_entry.date.toIso8601String().substring(0, 10)}')
      ..writeln('Mood: ${_entry.mood} ${_entry.moodEmoji}');

    if (s.steps > 0) buf.writeln('Steps: ${s.steps}');
    if (s.caloriesBurned > 0) {
      buf.writeln('Calories burned: ${s.caloriesBurned.toStringAsFixed(0)}');
    }
    if (s.sleepHours > 0) {
      buf.writeln('Sleep: ${s.sleepHours.toStringAsFixed(1)} h');
    }
    if (s.avgHeartRate > 0) buf.writeln('Avg HR: ${s.avgHeartRate} bpm');
    if (s.restingHeartRate > 0) {
      buf.writeln('Resting HR: ${s.restingHeartRate} bpm');
    }
    if (s.hrv != null)
      buf.writeln('HRV (SDNN): ${s.hrv!.toStringAsFixed(1)} ms');
    if (s.workouts > 0) buf.writeln('Workouts: ${s.workouts}');
    if (s.distanceKm > 0) {
      buf.writeln('Distance: ${s.distanceKm.toStringAsFixed(1)} km');
    }
    if (s.temperatureC != null) {
      buf.writeln('Temperature: ${s.temperatureC!.toStringAsFixed(1)} °C');
    }
    if (s.aqiUs != null) buf.writeln('AQI (US): ${s.aqiUs}');
    if (s.uvIndex != null) {
      buf.writeln('UV index: ${s.uvIndex!.toStringAsFixed(1)}');
    }
    if (s.weatherDesc != null) buf.writeln('Weather: ${s.weatherDesc}');
    if (s.city != null) buf.writeln('Location: ${s.city}');
    if (s.calendarEvents.isNotEmpty) {
      buf.writeln('Calendar: ${s.calendarEvents.join(", ")}');
    }

    if (_entry.fullBody.isNotEmpty) {
      buf
        ..writeln()
        ..writeln('── Journal excerpt (your own words earlier today) ──')
        ..writeln(_entry.fullBody);
    }

    buf
      ..writeln()
      ..writeln('── Guidelines ──')
      ..writeln(
        '• Keep replies concise (2-4 sentences). Be conversational, not clinical.',
      )
      ..writeln(
        '• Reference specific data points when relevant (e.g. "our HRV dropped to 38 ms").',
      )
      ..writeln(
        '• If the user asks something outside your data, say so honestly.',
      )
      ..writeln('• Never diagnose, prescribe, or replace medical advice.');

    return buf.toString();
  }
}
