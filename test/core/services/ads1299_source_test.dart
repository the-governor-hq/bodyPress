import 'package:bodypress_flutter/core/services/sources/ads1299_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Ads1299Source source;

  setUp(() {
    source = Ads1299Source();
  });

  // ─── Identity ───────────────────────────────────────────────────────────

  group('Ads1299Source identity', () {
    test('id is ads1299', () {
      expect(source.id, 'ads1299');
    });

    test('displayName is set', () {
      expect(source.displayName, contains('ADS1299'));
    });

    test('description is non-empty', () {
      expect(source.description, isNotEmpty);
    });

    test('icon is psychology_alt', () {
      expect(source.icon, Icons.psychology_alt);
    });

    test('advertised names include EAREEG', () {
      expect(source.advertisedNames, contains('EAREEG'));
    });
  });

  // ─── BLE identifiers ──────────────────────────────────────────────────

  group('Ads1299Source BLE config', () {
    test('serviceUuid is set', () {
      expect(source.serviceUuid, isNotEmpty);
      expect(source.serviceUuid, contains('fe42'));
    });

    test('notifyCharacteristicUuid is set', () {
      expect(source.notifyCharacteristicUuid, isNotEmpty);
    });
  });

  // ─── Channel layout ───────────────────────────────────────────────────

  group('Ads1299Source channel layout', () {
    test('has 8 channels', () {
      expect(source.channelCount, 8);
      expect(source.channelDescriptors.length, 8);
    });

    test('channels have 10-20 electrode labels', () {
      final labels = source.channelDescriptors.map((c) => c.label).toList();
      expect(labels, ['Fp1', 'Fp2', 'C3', 'C4', 'P3', 'P4', 'O1', 'O2']);
    });

    test('channels are in µV', () {
      for (final ch in source.channelDescriptors) {
        expect(ch.unit, 'µV');
      }
    });

    test('channels have defaultScale of 100', () {
      for (final ch in source.channelDescriptors) {
        expect(ch.defaultScale, 100);
      }
    });

    test('sample rate is 250 Hz', () {
      expect(source.sampleRateHz, 250);
    });
  });

  // ─── parseNotification ────────────────────────────────────────────────

  group('Ads1299Source.parseNotification', () {
    test('returns null for empty data', () {
      expect(source.parseNotification([]), isNull);
    });

    test('returns null for data shorter than 24 bytes', () {
      expect(source.parseNotification(List.filled(23, 0)), isNull);
    });

    test('parses exactly 24 bytes into 8 channels', () {
      // All zeros → all channels should be 0.0 µV
      final data = List.filled(24, 0);
      final sample = source.parseNotification(data);

      expect(sample, isNotNull);
      expect(sample!.channels.length, 8);
      for (final v in sample.channels) {
        expect(v, 0.0);
      }
    });

    test('parses all 0x7FFFFF (positive full-scale)', () {
      // 0x7FFFFF = 8388607, biggest positive 24-bit two's complement
      // Expected µV = 1_000_000 * 4.5 * (8388607 / 16777215)
      //            ≈ 2_250_000 * 0.49999997 ≈ ~2249999.93
      final data = <int>[];
      for (var i = 0; i < 8; i++) {
        data.addAll([0x7F, 0xFF, 0xFF]);
      }
      final sample = source.parseNotification(data);

      expect(sample, isNotNull);
      for (final v in sample!.channels) {
        // Positive, close to half the ADC range in µV
        expect(v, greaterThan(2249999));
        expect(v, lessThan(2250001));
      }
    });

    test('parses 0x800000 (most negative value)', () {
      // 0x800000 unsigned = 8388608, after sign extension = -8388608
      // Expected µV = 1_000_000 * 4.5 * (-8388608 / 16777215) ≈ -2250000.27
      final data = <int>[];
      for (var i = 0; i < 8; i++) {
        data.addAll([0x80, 0x00, 0x00]);
      }
      final sample = source.parseNotification(data);

      expect(sample, isNotNull);
      for (final v in sample!.channels) {
        expect(v, lessThan(-2249999));
        expect(v, greaterThan(-2250001));
      }
    });

    test('parses 0xFFFFFF as -1 (small negative)', () {
      // 0xFFFFFF unsigned = 16777215, after sign extension = -1
      // Expected µV = 1_000_000 * 4.5 * (-1 / 16777215) ≈ -0.27
      final data = <int>[];
      for (var i = 0; i < 8; i++) {
        data.addAll([0xFF, 0xFF, 0xFF]);
      }
      final sample = source.parseNotification(data);

      expect(sample, isNotNull);
      for (final v in sample!.channels) {
        expect(v, lessThan(0));
        expect(v, greaterThan(-1));
      }
    });

    test('parses mixed channel values correctly', () {
      // Ch0: 0x000001 = +1  → small positive
      // Ch1: 0xFFFFFF = -1  → small negative
      // Ch2-7: 0x000000 = 0
      final data = List.filled(24, 0);
      // Ch0: [0x00, 0x00, 0x01]
      data[2] = 0x01;
      // Ch1: [0xFF, 0xFF, 0xFF]
      data[3] = 0xFF;
      data[4] = 0xFF;
      data[5] = 0xFF;

      final sample = source.parseNotification(data);

      expect(sample, isNotNull);
      expect(sample!.channels[0], greaterThan(0)); // +1 raw → small positive µV
      expect(sample.channels[1], lessThan(0)); // -1 raw → small negative µV
      for (var i = 2; i < 8; i++) {
        expect(sample.channels[i], 0.0);
      }
    });

    test('handles data longer than 24 bytes (ignores extra)', () {
      final data = List.filled(48, 0);
      final sample = source.parseNotification(data);

      expect(sample, isNotNull);
      expect(sample!.channels.length, 8);
    });

    test('returned sample has a timestamp', () {
      final data = List.filled(24, 0);
      final before = DateTime.now();
      final sample = source.parseNotification(data);
      final after = DateTime.now();

      expect(sample, isNotNull);
      expect(sample!.time.isAfter(before) || sample.time == before, isTrue);
      expect(sample.time.isBefore(after) || sample.time == after, isTrue);
    });

    test('big-endian byte order: 0x01 0x02 0x03 = 0x010203', () {
      // Raw unsigned = 0x010203 = 66051
      // Positive (< 0x800000), no sign extension
      // µV = 1_000_000 * 4.5 * (66051 / 16777215) ≈ 17716.26
      final data = List.filled(24, 0);
      data[0] = 0x01;
      data[1] = 0x02;
      data[2] = 0x03;

      final sample = source.parseNotification(data);

      expect(sample, isNotNull);
      expect(sample!.channels[0], closeTo(17716.26, 0.1));
    });
  });
}
