import 'package:flutter_test/flutter_test.dart';
import 'package:switch_sense_app/repositories/mock_relay_repository.dart';
import 'package:switch_sense_app/repositories/relay_repository.dart';

void main() {
  group('MockRelayRepository Lifecycle & Notification Tests', () {
    late MockRelayRepository repository;

    setUp(() {
      repository = MockRelayRepository(
        simulatedLatency: const Duration(milliseconds: 10),
      );
    });

    tearDown(() {
      repository.dispose();
    });

    test('Initial state is disconnected with no connected device', () {
      expect(repository.currentStatus, equals(BleConnectionStatus.disconnected));
      expect(repository.connectedDevice, isNull);
    });

    test('startScan emits mock peripherals including ESP32-Relay-8', () async {
      final devicesFuture = repository.discoveredDevicesStream.first;
      await repository.startScan();

      final devices = await devicesFuture;
      expect(devices, isNotEmpty);
      expect(devices.any((d) => d.name == 'ESP32-Relay-8'), isTrue);
      expect(devices.any((d) => d.hasMatchingService), isTrue);
    });

    test('connect sets status to connected and emits safe initial relay states (all OFF)', () async {
      final stateEvents = <List<bool>>[];
      repository.relayStatesStream.listen(stateEvents.add);

      await repository.connect('AA:BB:CC:DD:EE:01');

      expect(repository.currentStatus, equals(BleConnectionStatus.connected));
      expect(repository.connectedDevice?.name, equals('ESP32-Relay-8'));

      // Wait a tick for stream event
      await Future.delayed(const Duration(milliseconds: 30));
      expect(stateEvents, isNotEmpty);
      expect(stateEvents.last, equals(List.filled(8, false)));
    });

    test('sendRelayCommand updates single channel and fires GATT notification stream', () async {
      await repository.connect('AA:BB:CC:DD:EE:01');

      final updateFuture = repository.relayStatesStream.first;
      await repository.sendRelayCommand(2, true); // Turn ON Relay 3 (GPIO 14)

      final updated = await updateFuture;
      expect(updated[2], isTrue, reason: 'Relay 3 (index 2) must be ON');
      expect(updated[0], isFalse);
      expect(updated[1], isFalse);
    });

    test('sendAllRelaysCommand updates all 8 channels simultaneously', () async {
      await repository.connect('AA:BB:CC:DD:EE:01');

      final updateFuture = repository.relayStatesStream.first;
      await repository.sendAllRelaysCommand(true);

      final updated = await updateFuture;
      expect(updated, equals(List.filled(8, true)));

      // Now turn all OFF
      final offFuture = repository.relayStatesStream.first;
      await repository.sendAllRelaysCommand(false);

      final allOff = await offFuture;
      expect(allOff, equals(List.filled(8, false)));
    });

    test('disconnect resets status and clears connected peripheral', () async {
      await repository.connect('AA:BB:CC:DD:EE:01');
      expect(repository.currentStatus, equals(BleConnectionStatus.connected));

      await repository.disconnect();
      expect(repository.currentStatus, equals(BleConnectionStatus.disconnected));
      expect(repository.connectedDevice, isNull);
    });
  });
}
