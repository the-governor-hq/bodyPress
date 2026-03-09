import 'package:bodypress_flutter/core/services/ble_source_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ─── SignalSample ─────────────────────────────────────────────────────────

  group('SignalSample', () {
    test('toJson / fromJson round-trip', () {
      final now = DateTime.now();
      final original = SignalSample(
        time: now,
        channels: [1.5, -2.3, 0.0, 100.99],
      );
      final json = original.toJson();
      final decoded = SignalSample.fromJson(json);

      expect(decoded.time, original.time);
      expect(decoded.channels, original.channels);
    });

    test('toJson encodes microseconds and channel list', () {
      final sample = SignalSample(
        time: DateTime.fromMicrosecondsSinceEpoch(1234567890),
        channels: [10.0, 20.0],
      );
      final json = sample.toJson();

      expect(json['t'], 1234567890);
      expect(json['ch'], [10.0, 20.0]);
    });

    test('fromJson handles integer channel values', () {
      final sample = SignalSample.fromJson({
        't': 1000000,
        'ch': [1, 2, 3],
      });

      expect(sample.channels, [1.0, 2.0, 3.0]);
    });
  });

  // ─── ChannelDescriptor ────────────────────────────────────────────────────

  group('ChannelDescriptor', () {
    test('toJson / fromJson round-trip', () {
      const original = ChannelDescriptor(
        label: 'Fp1',
        unit: 'µV',
        defaultScale: 100,
      );
      final json = original.toJson();
      final decoded = ChannelDescriptor.fromJson(json);

      expect(decoded.label, 'Fp1');
      expect(decoded.unit, 'µV');
      expect(decoded.defaultScale, 100);
    });

    test('fromJson defaults unit to µV when missing', () {
      final decoded = ChannelDescriptor.fromJson({'label': 'Ch 1'});

      expect(decoded.label, 'Ch 1');
      expect(decoded.unit, 'µV');
      expect(decoded.defaultScale, isNull);
    });

    test('fromJson handles null defaultScale', () {
      final decoded = ChannelDescriptor.fromJson({
        'label': 'O2',
        'unit': 'mV',
        'default_scale': null,
      });

      expect(decoded.label, 'O2');
      expect(decoded.unit, 'mV');
      expect(decoded.defaultScale, isNull);
    });
  });

  // ─── SignalSession ────────────────────────────────────────────────────────

  group('SignalSession', () {
    final time1 = DateTime(2026, 1, 1, 12, 0, 0);
    final time2 = DateTime(2026, 1, 1, 12, 0, 10);

    SignalSession buildSession() => SignalSession(
      sourceId: 'ads1299',
      sourceName: 'ADS1299 8-Ch EEG',
      deviceName: 'EAREEG',
      channels: const [
        ChannelDescriptor(label: 'Fp1', unit: 'µV', defaultScale: 100),
        ChannelDescriptor(label: 'Fp2', unit: 'µV', defaultScale: 100),
      ],
      samples: [
        SignalSample(time: time1, channels: [1.0, 2.0]),
        SignalSample(time: time2, channels: [3.0, 4.0]),
      ],
      sampleRateHz: 250,
    );

    test('encode / decode round-trip', () {
      final original = buildSession();
      final encoded = original.encode();
      final decoded = SignalSession.decode(encoded);

      expect(decoded, isNotNull);
      expect(decoded!.sourceId, 'ads1299');
      expect(decoded.sourceName, 'ADS1299 8-Ch EEG');
      expect(decoded.deviceName, 'EAREEG');
      expect(decoded.sampleRateHz, 250);
      expect(decoded.channelCount, 2);
      expect(decoded.channels[0].label, 'Fp1');
      expect(decoded.channels[1].label, 'Fp2');
      expect(decoded.samples.length, 2);
      expect(decoded.samples[0].channels, [1.0, 2.0]);
      expect(decoded.samples[1].channels, [3.0, 4.0]);
    });

    test('duration returns difference between first and last sample', () {
      final session = buildSession();
      expect(session.duration, const Duration(seconds: 10));
    });

    test('duration returns zero with fewer than 2 samples', () {
      final session = SignalSession(
        sourceId: 'test',
        sourceName: 'Test',
        channels: const [ChannelDescriptor(label: 'Ch 1')],
        samples: [
          SignalSample(time: DateTime.now(), channels: [0.0]),
        ],
      );
      expect(session.duration, Duration.zero);
    });

    test('duration returns zero with empty samples', () {
      final session = SignalSession(
        sourceId: 'test',
        sourceName: 'Test',
        channels: const [],
        samples: const [],
      );
      expect(session.duration, Duration.zero);
    });

    test('decode returns null for null input', () {
      expect(SignalSession.decode(null), isNull);
    });

    test('decode returns null for malformed JSON', () {
      expect(SignalSession.decode('not json'), isNull);
    });

    test('decode returns null for incomplete JSON', () {
      expect(SignalSession.decode('{}'), isNull);
    });

    test('encode preserves deviceName: null', () {
      final session = SignalSession(
        sourceId: 'test',
        sourceName: 'Test',
        channels: const [],
        samples: const [],
      );
      final decoded = SignalSession.decode(session.encode());
      expect(decoded!.deviceName, isNull);
    });

    test('channelCount matches channel list length', () {
      final session = buildSession();
      expect(session.channelCount, session.channels.length);
    });
  });

  // ─── BleSourceRegistry ────────────────────────────────────────────────────

  group('BleSourceRegistry', () {
    test('starts empty', () {
      final registry = BleSourceRegistry();
      expect(registry.isEmpty, isTrue);
      expect(registry.count, 0);
      expect(registry.providers, isEmpty);
    });

    test('register adds a provider', () {
      final registry = BleSourceRegistry();
      registry.register(_FakeSource('alpha'));

      expect(registry.count, 1);
      expect(registry.isEmpty, isFalse);
      expect(registry.getById('alpha'), isNotNull);
      expect(registry.getById('alpha')!.id, 'alpha');
    });

    test('register replaces provider with same id', () {
      final registry = BleSourceRegistry();
      registry.register(_FakeSource('alpha', displayName: 'V1'));
      registry.register(_FakeSource('alpha', displayName: 'V2'));

      expect(registry.count, 1);
      expect(registry.getById('alpha')!.displayName, 'V2');
    });

    test('getById returns null for unknown id', () {
      final registry = BleSourceRegistry();
      registry.register(_FakeSource('alpha'));

      expect(registry.getById('beta'), isNull);
    });

    test('providers returns all registered providers', () {
      final registry = BleSourceRegistry();
      registry.register(_FakeSource('alpha'));
      registry.register(_FakeSource('beta'));
      registry.register(_FakeSource('gamma'));

      final ids = registry.providers.map((p) => p.id).toSet();
      expect(ids, {'alpha', 'beta', 'gamma'});
      expect(registry.count, 3);
    });
  });
}

// ─── Fake source for registry tests ─────────────────────────────────────────

class _FakeSource extends BleSourceProvider {
  final String _id;
  final String _displayName;

  _FakeSource(this._id, {String displayName = 'Fake'})
    : _displayName = displayName;

  @override
  String get id => _id;
  @override
  String get displayName => _displayName;
  @override
  String get description => 'Fake source';
  @override
  IconData get icon => const IconData(0xe0b0);
  @override
  List<String> get advertisedNames => [];
  @override
  String get serviceUuid => '00001234-0000-1000-8000-00805f9b34fb';
  @override
  String get notifyCharacteristicUuid => '00001234-0000-1000-8000-00805f9b34fb';
  @override
  List<ChannelDescriptor> get channelDescriptors => [
    const ChannelDescriptor(label: 'Ch 1'),
  ];
  @override
  double get sampleRateHz => 100;
  @override
  SignalSample? parseNotification(List<int> data) => null;
}
