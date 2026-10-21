import '../models/ble_device_info.dart';

/// Connection states for the BLE repository lifecycle.
enum BleConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  disconnecting,
  error,
}

/// Abstract contract for relay communication over BLE or simulated testing.
abstract class RelayRepository {
  /// Broadcast stream of connection lifecycle changes
  Stream<BleConnectionStatus> get connectionStatusStream;

  /// Current instantaneous connection status
  BleConnectionStatus get currentStatus;

  /// Stream of discovered devices during an active scan
  Stream<List<BleDeviceInfo>> get discoveredDevicesStream;

  /// Stream of confirmed hardware relay states (`List<bool>` of 8 items, index 0 = Relay 1)
  Stream<List<bool>> get relayStatesStream;

  /// Currently connected peripheral metadata, if any
  BleDeviceInfo? get connectedDevice;

  /// Starts scanning for peripherals advertising the Switch Sense service or device name
  Future<void> startScan({Duration? timeout});

  /// Aborts an ongoing scan
  Future<void> stopScan();

  /// Connects to a peripheral by its unique ID/MAC address
  Future<void> connect(String deviceId);

  /// Disconnects from the currently connected peripheral
  Future<void> disconnect();

  /// Sends a command to set a specific relay (0 to 7) to ON or OFF
  Future<void> sendRelayCommand(int relayIndex, bool turnOn);

  /// Sends a command to set ALL 8 relays to ON or OFF
  Future<void> sendAllRelaysCommand(bool turnOn);

  /// Cleans up any streams or subscriptions
  void dispose();
}
