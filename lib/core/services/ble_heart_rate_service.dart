import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// A single heart-rate reading streamed from a BLE HR Profile device.
/// Includes the raw RR-interval list (milliseconds) for HRV computation;
/// may be empty if the device does not report RR intervals.
class BleHrReading {
  final int bpm;
  final List<double> rrMs;

  const BleHrReading({required this.bpm, this.rrMs = const []});
}

// ─────────────────────────────────────────────────────────────────────────────
// Session recording models
// ─────────────────────────────────────────────────────────────────────────────

/// A single timestamped BPM sample recorded during a BLE session.
class BleHrSample {
  final DateTime time;
  final int bpm;

  const BleHrSample({required this.time, required this.bpm});

  Map<String, dynamic> toJson() => {'t': time.millisecondsSinceEpoch, 'b': bpm};

  factory BleHrSample.fromJson(Map<String, dynamic> j) => BleHrSample(
    time: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    bpm: j['b'] as int,
  );
}

/// HRV metrics derived from RR intervals.
class BleHrvMetrics {
  /// Root mean square of successive differences (ms) — primary HRV index.
  final double? rmssd;

  /// Standard deviation of all RR intervals (ms).
  final double? sdnn;

  /// Mean RR interval (ms).
  final double? meanRr;

  const BleHrvMetrics({this.rmssd, this.sdnn, this.meanRr});

  /// Human-readable stress hint derived from RMSSD.
  /// Low values → higher sympathetic (stress/active); high values → parasympathetic (relaxed).
  String get stressHint {
    if (rmssd == null) return 'unknown';
    if (rmssd! >= 50) return 'relaxed / parasympathetic-dominant';
    if (rmssd! >= 30) return 'moderate autonomic balance';
    if (rmssd! >= 15) return 'mild stress / active';
    return 'high stress / sympathetic-dominant';
  }

  Map<String, dynamic> toJson() => {
    'rmssd': rmssd,
    'sdnn': sdnn,
    'mean_rr': meanRr,
  };

  factory BleHrvMetrics.fromJson(Map<String, dynamic> j) => BleHrvMetrics(
    rmssd: (j['rmssd'] as num?)?.toDouble(),
    sdnn: (j['sdnn'] as num?)?.toDouble(),
    meanRr: (j['mean_rr'] as num?)?.toDouble(),
  );

  /// Compute HRV metrics from a list of RR intervals in milliseconds.
  /// Returns null when fewer than 3 intervals are available (unreliable).
  static BleHrvMetrics? compute(List<double> rrMs) {
    if (rrMs.length < 3) return null;

    final mean = rrMs.reduce((a, b) => a + b) / rrMs.length;

    // RMSSD
    double sumSqDiff = 0;
    for (var i = 0; i < rrMs.length - 1; i++) {
      final diff = rrMs[i + 1] - rrMs[i];
      sumSqDiff += diff * diff;
    }
    final rmssd = math.sqrt(sumSqDiff / (rrMs.length - 1));

    // SDNN
    double sumSqDev = 0;
    for (final rr in rrMs) {
      final dev = rr - mean;
      sumSqDev += dev * dev;
    }
    final sdnn = math.sqrt(sumSqDev / rrMs.length);

    return BleHrvMetrics(rmssd: rmssd, sdnn: sdnn, meanRr: mean);
  }
}

/// A complete BLE HR recording session attached to a capture.
class BleHrSession {
  /// Timestamped BPM readings (one per second typically).
  final List<BleHrSample> samples;

  /// All raw RR intervals collected (ms), used for HRV computation.
  final List<double> rrMs;

  /// HRV metrics computed at save time; null when RR data was unavailable.
  final BleHrvMetrics? hrv;

  /// Name of the connected BLE device.
  final String? deviceName;

  const BleHrSession({
    required this.samples,
    required this.rrMs,
    this.hrv,
    this.deviceName,
  });

  int? get minBpm =>
      samples.isEmpty ? null : samples.map((s) => s.bpm).reduce(math.min);
  int? get maxBpm =>
      samples.isEmpty ? null : samples.map((s) => s.bpm).reduce(math.max);
  int? get avgBpm => samples.isEmpty
      ? null
      : (samples.map((s) => s.bpm).reduce((a, b) => a + b) / samples.length)
            .round();

  Duration get duration => samples.length < 2
      ? Duration.zero
      : samples.last.time.difference(samples.first.time);

  /// Rough trend: compare last-quarter avg vs first-quarter avg.
  String get bpmTrend {
    if (samples.length < 4) return 'stable';
    final q = samples.length ~/ 4;
    final early = samples.take(q).map((s) => s.bpm).reduce((a, b) => a + b) / q;
    final late_ =
        samples
            .skip(samples.length - q)
            .map((s) => s.bpm)
            .reduce((a, b) => a + b) /
        q;
    final delta = late_ - early;
    if (delta > 5) return 'rising';
    if (delta < -5) return 'falling';
    return 'stable';
  }

  String encode() => jsonEncode({
    'samples': samples.map((s) => s.toJson()).toList(),
    'rr_ms': rrMs,
    'hrv': hrv?.toJson(),
    'device': deviceName,
  });

  static BleHrSession? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return BleHrSession(
        samples: (m['samples'] as List)
            .map((e) => BleHrSample.fromJson(e as Map<String, dynamic>))
            .toList(),
        rrMs: (m['rr_ms'] as List).map((e) => (e as num).toDouble()).toList(),
        hrv: m['hrv'] != null
            ? BleHrvMetrics.fromJson(m['hrv'] as Map<String, dynamic>)
            : null,
        deviceName: m['device'] as String?,
      );
    } catch (e) {
      debugPrint('[BleHrSession] decode error: $e');
      return null;
    }
  }
}

/// A BLE device that exposes the Heart Rate service (0x180D).
class BleHrDevice {
  final ScanResult scanResult;

  String get name => scanResult.device.platformName.isNotEmpty
      ? scanResult.device.platformName
      : 'HR Device (${scanResult.device.remoteId.str.substring(0, 8)})';

  int get rssi => scanResult.rssi;

  BluetoothDevice get device => scanResult.device;

  const BleHrDevice(this.scanResult);
}

/// Connection lifecycle states.
enum BleConnectionState { idle, scanning, connecting, streaming, error }

/// Manages scanning, connecting, and streaming live HR data from any
/// Bluetooth Low Energy Heart Rate Profile 0x180D device
/// (Polar H10, Wahoo TICKR, Garmin chest straps, etc.).
///
/// Usage:
/// ```dart
/// final svc = BleHeartRateService();
/// await svc.startScan();
/// svc.devicesStream.listen((devices) { /* show picker */ });
/// await svc.connectAndStream(devices.first.device);
/// svc.hrStream.listen((r) => print('${r.bpm} bpm'));
/// ```
class BleHeartRateService {
  // Standard BT SIG Heart Rate Profile UUIDs (128-bit canonical forms).
  static const String _hrServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String _hrMeasurementUuid =
      '00002a37-0000-1000-8000-00805f9b34fb';

  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<int>>? _hrNotifySubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  final _devicesController = StreamController<List<BleHrDevice>>.broadcast();
  final _hrController = StreamController<BleHrReading>.broadcast();
  final _stateController = StreamController<BleConnectionState>.broadcast();

  BleConnectionState _state = BleConnectionState.idle;

  /// Emits the growing list of discovered HR-capable devices while scanning.
  Stream<List<BleHrDevice>> get devicesStream => _devicesController.stream;

  /// Emits live [BleHrReading] values from the connected device.
  Stream<BleHrReading> get hrStream => _hrController.stream;

  /// Emits [BleConnectionState] whenever the lifecycle changes.
  Stream<BleConnectionState> get stateStream => _stateController.stream;

  BleConnectionState get state => _state;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isStreaming => _state == BleConnectionState.streaming;

  void _setState(BleConnectionState s) {
    _state = s;
    if (!_stateController.isClosed) _stateController.add(s);
  }

  // ── Scanning ──────────────────────────────────────────────────────────

  /// Scan for HR-capable devices for up to [timeoutSeconds] seconds.
  /// Results are pushed into [devicesStream].
  Future<void> startScan({int timeoutSeconds = 10}) async {
    if (_state == BleConnectionState.streaming) return;
    _setState(BleConnectionState.scanning);

    final found = <String, BleHrDevice>{};

    try {
      await FlutterBluePlus.startScan(
        withServices: [Guid(_hrServiceUuid)],
        timeout: Duration(seconds: timeoutSeconds),
      );

      final scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          found[r.device.remoteId.str] = BleHrDevice(r);
        }
        if (!_devicesController.isClosed) {
          _devicesController.add(found.values.toList());
        }
      });

      // Wait until scan finishes.
      await FlutterBluePlus.isScanning
          .where((s) => !s)
          .first
          .timeout(Duration(seconds: timeoutSeconds + 3));

      await scanSub.cancel();
    } catch (e) {
      debugPrint('[BLE] Scan error: $e');
    } finally {
      if (_state == BleConnectionState.scanning) {
        _setState(BleConnectionState.idle);
      }
    }
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  // ── Connection ────────────────────────────────────────────────────────

  /// Connect to [device] and begin streaming HR notifications.
  /// Throws on failure; callers should catch and present an error to the user.
  Future<void> connectAndStream(BluetoothDevice device) async {
    _setState(BleConnectionState.connecting);

    try {
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 15),
      );
      _connectedDevice = device;

      // Monitor disconnection so we can reset state automatically.
      _connectionSubscription = device.connectionState.listen((cs) {
        if (cs == BluetoothConnectionState.disconnected) {
          _setState(BleConnectionState.idle);
          _connectedDevice = null;
        }
      });

      final services = await device.discoverServices();

      final hrService = _findByUuid(
        services.map((s) => (s.uuid.str128.toLowerCase(), s)).toList(),
        _hrServiceUuid,
      );
      if (hrService == null) throw Exception('Heart Rate service not found');

      final hrChar = _findByUuid(
        hrService.characteristics
            .map((c) => (c.uuid.str128.toLowerCase(), c))
            .toList(),
        _hrMeasurementUuid,
      );
      if (hrChar == null) {
        throw Exception('Heart Rate Measurement characteristic not found');
      }

      await hrChar.setNotifyValue(true);
      _setState(BleConnectionState.streaming);

      _hrNotifySubscription = hrChar.lastValueStream.listen((data) {
        if (data.isEmpty) return;
        final reading = _parseHrMeasurement(Uint8List.fromList(data));
        if (reading != null && !_hrController.isClosed) {
          _hrController.add(reading);
        }
      });
    } catch (e) {
      debugPrint('[BLE] Connect error: $e');
      _setState(BleConnectionState.error);
      rethrow;
    }
  }

  /// Disconnect and reset state.
  Future<void> disconnect() async {
    await _hrNotifySubscription?.cancel();
    _hrNotifySubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    try {
      await _connectedDevice?.disconnect();
    } catch (_) {}
    _connectedDevice = null;
    _setState(BleConnectionState.idle);
  }

  // ── HR Measurement parsing ────────────────────────────────────────────

  /// Parses a BT SIG Heart Rate Measurement characteristic value per
  /// specification (flags byte + optional fields).
  ///
  /// Returns null when the data is too short to contain a valid reading.
  BleHrReading? _parseHrMeasurement(Uint8List data) {
    if (data.length < 2) return null;

    final flags = data[0];
    final hrFormat = flags & 0x01; // 0 = uint8, 1 = uint16
    final energyExpendedPresent = (flags >> 3) & 0x01;
    final rrPresent = (flags >> 4) & 0x01;

    // Heart rate value.
    final int bpm;
    int offset;
    if (hrFormat == 0) {
      bpm = data[1];
      offset = 2;
    } else {
      if (data.length < 3) return null;
      bpm = data[1] | (data[2] << 8);
      offset = 3;
    }

    if (energyExpendedPresent == 1) offset += 2;

    // RR-interval values (units: 1/1024 second → convert to ms).
    final rrMs = <double>[];
    if (rrPresent == 1) {
      while (offset + 1 < data.length) {
        final raw = data[offset] | (data[offset + 1] << 8);
        rrMs.add(raw * 1000.0 / 1024.0);
        offset += 2;
      }
    }

    return BleHrReading(bpm: bpm, rrMs: rrMs);
  }

  // ── Helpers ───────────────────────────────────────────────────────────

  T? _findByUuid<T>(List<(String, T)> items, String uuid) {
    for (final (key, value) in items) {
      if (key == uuid) return value;
    }
    return null;
  }

  void dispose() {
    disconnect();
    _devicesController.close();
    _hrController.close();
    _stateController.close();
  }
}
