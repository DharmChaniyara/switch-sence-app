import 'package:flutter_test/flutter_test.dart';
import 'package:switch_sense_app/constants/ble_constants.dart';

void main() {
  group('BLE Protocol Codec Unit Tests', () {
    test('encodeRelayCommand generates exact 2-byte payload for single relay', () {
      // Test each channel 0-7 for ON and OFF
      for (int i = 0; i < 8; i++) {
        final onPayload = BleConstants.encodeRelayCommand(i, true);
        expect(onPayload, equals([i, 0x01]), reason: 'Relay $i ON must encode to [$i, 0x01]');

        final offPayload = BleConstants.encodeRelayCommand(i, false);
        expect(offPayload, equals([i, 0x00]), reason: 'Relay $i OFF must encode to [$i, 0x00]');
      }
    });

    test('encodeAllCommand generates exact 2-byte master payload', () {
      final allOn = BleConstants.encodeAllCommand(true);
      expect(allOn, equals([0xFF, 0x01]));

      final allOff = BleConstants.encodeAllCommand(false);
      expect(allOff, equals([0xFF, 0x00]));
    });

    test('decodeStateBitmask correctly maps 1-byte bitmask to 8 boolean channels', () {
      // 0x00 = All OFF
      final allOff = BleConstants.decodeStateBitmask(0x00);
      expect(allOff, equals([false, false, false, false, false, false, false, false]));

      // 0xFF = All ON
      final allOn = BleConstants.decodeStateBitmask(0xFF);
      expect(allOn, equals([true, true, true, true, true, true, true, true]));

      // Bit 0 = Relay 1 ON (GPIO 13)
      final r1Only = BleConstants.decodeStateBitmask(0x01);
      expect(r1Only, equals([true, false, false, false, false, false, false, false]));

      // Bit 1 = Relay 2 ON (GPIO 12)
      final r2Only = BleConstants.decodeStateBitmask(0x02);
      expect(r2Only, equals([false, true, false, false, false, false, false, false]));

      // Bit 7 = Relay 8 ON (GPIO 32)
      final r8Only = BleConstants.decodeStateBitmask(0x80);
      expect(r8Only, equals([false, false, false, false, false, false, false, true]));

      // Alternating 0x55 (Bits 0, 2, 4, 6)
      final altEven = BleConstants.decodeStateBitmask(0x55);
      expect(altEven, equals([true, false, true, false, true, false, true, false]));

      // Alternating 0xAA (Bits 1, 3, 5, 7)
      final altOdd = BleConstants.decodeStateBitmask(0xAA);
      expect(altOdd, equals([false, true, false, true, false, true, false, true]));
    });

    test('State bitmask encoding and decoding round-trip preserves all 256 combinations', () {
      for (int mask = 0; mask < 256; mask++) {
        final decoded = BleConstants.decodeStateBitmask(mask);
        final reEncoded = BleConstants.encodeStateBitmask(decoded);
        expect(reEncoded, equals(mask),
            reason: 'Round trip failed for bitmask: 0x${mask.toRadixString(16).padLeft(2, '0')}');
      }
    });
  });
}
