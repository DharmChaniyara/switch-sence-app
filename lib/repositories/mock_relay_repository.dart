import 'dart:async';
import '../constants/ble_constants.dart';
import '../models/ble_device_info.dart';
import 'relay_repository.dart';

/// Deterministic mock implementation of RelayRepository for testing and interactive Demo Mode.
class MockRelayRepository implements RelayRepository {
  final _connectionStatusController =
      StreamController<BleConnectionStatus>.broadcast();
  final _discoveredDevicesController =
      StreamController<List<BleDeviceInfo>>.broadcast();
  final _relayStatesController =
      StreamController<List<bool>>.broadcast();

  BleConnectionStatus _currentStatus = BleConnectionStatus.disconnected;
  BleDeviceInfo? _connectedDeviceInfo;

  // In-memory 8-channel states (all OFF initially, matching hardware safe boot)
  List<bool> _states = List<bool>.filled(BleConstants.totalRelays, false);

  /// Artificial latency for command response simulation
  final Duration simulatedLatency;

  MockRelayRepository({
    this.simulatedLatency = const Duration(milliseconds: 60),
    List<bool>? initialStates,
  }) {
    if (initialStates != null &&
        initialStates.length == BleConstants.totalRelays) {
      _states = List<bool>.from(initialStates);
    }
  }

  @override
  Stream<BleConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  @override
  BleConnectionStatus get currentStatus => _currentStatus;

  @override
  Stream<List<BleDeviceInfo>> get discoveredDevicesStream =>
      _discoveredDevicesController.stream;

  @override
  Stream<List<bool>> get relayStatesStream =>
      _relayStatesController.stream;

  @override
  BleDeviceInfo? get connectedDevice => _connectedDeviceInfo;

  void _updateStatus(BleConnectionStatus status) {
    _currentStatus = status;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.add(status);
    }
  }

  @override
  Future<void> startScan({Duration? timeout}) async {
    _updateStatus(BleConnectionStatus.scanning);

    if (simulatedLatency > Duration.zero) {
      await Future.delayed(simulatedLatency);
    }

    final mockDevices = [
      const BleDeviceInfo(
        id: 'AA:BB:CC:DD:EE:01',
        name: 'ESP32-Relay-8',
        rssi: -58,
        hasMatchingService: true,
      ),
      const BleDeviceInfo(
        id: 'AA:BB:CC:DD:EE:02',
        name: 'Workshop-ESP32-Relay',
        rssi: -74,
        hasMatchingService: true,
      ),
    ];

    if (!_discoveredDevicesController.isClosed) {
      _discoveredDevicesController.add(mockDevices);
    }
  }

  @override
  Future<void> stopScan() async {
    if (_currentStatus == BleConnectionStatus.scanning) {
      _updateStatus(BleConnectionStatus.disconnected);
    }
  }

  @override
  Future<void> connect(String deviceId) async {
    await stopScan();
    _updateStatus(BleConnectionStatus.connecting);

    if (simulatedLatency > Duration.zero) {
      await Future.delayed(simulatedLatency);
    }

    _connectedDeviceInfo = BleDeviceInfo(
      id: deviceId,
      name: deviceId.contains('02') ? 'Workshop-ESP32-Relay' : 'ESP32-Relay-8',
      rssi: -58,
      hasMatchingService: true,
    );

    _updateStatus(BleConnectionStatus.connected);

    // Initial state notification
    if (!_relayStatesController.isClosed) {
      _relayStatesController.add(List<bool>.from(_states));
    }
  }

  @override
  Future<void> disconnect() async {
    _updateStatus(BleConnectionStatus.disconnecting);
    if (simulatedLatency > Duration.zero) {
      await Future.delayed(simulatedLatency);
    }
    _connectedDeviceInfo = null;
    _updateStatus(BleConnectionStatus.disconnected);
  }

  @override
  Future<void> sendRelayCommand(int relayIndex, bool turnOn) async {
    if (_currentStatus != BleConnectionStatus.connected) {
      throw StateError('Cannot send command: Mock relay is not connected.');
    }
    if (relayIndex < 0 || relayIndex >= BleConstants.totalRelays) {
      throw ArgumentError('Invalid relay index: $relayIndex');
    }

    // Simulate round-trip over BLE
    if (simulatedLatency > Duration.zero) {
      await Future.delayed(simulatedLatency);
    }

    _states[relayIndex] = turnOn;

    if (!_relayStatesController.isClosed) {
      _relayStatesController.add(List<bool>.from(_states));
    }
  }

  @override
  Future<void> sendAllRelaysCommand(bool turnOn) async {
    if (_currentStatus != BleConnectionStatus.connected) {
      throw StateError('Cannot send command: Mock relay is not connected.');
    }

    if (simulatedLatency > Duration.zero) {
      await Future.delayed(simulatedLatency);
    }

    _states = List<bool>.filled(BleConstants.totalRelays, turnOn);

    if (!_relayStatesController.isClosed) {
      _relayStatesController.add(List<bool>.from(_states));
    }
  }

  @override
  void dispose() {
    _connectionStatusController.close();
    _discoveredDevicesController.close();
    _relayStatesController.close();
  }
}
