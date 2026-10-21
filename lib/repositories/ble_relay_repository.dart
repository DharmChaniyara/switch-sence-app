import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../constants/ble_constants.dart';
import '../models/ble_device_info.dart';
import 'relay_repository.dart';

/// Concrete production implementation of RelayRepository using flutter_blue_plus.
class BleRelayRepository implements RelayRepository {
  final _connectionStatusController =
      StreamController<BleConnectionStatus>.broadcast();
  final _discoveredDevicesController =
      StreamController<List<BleDeviceInfo>>.broadcast();
  final _relayStatesController =
      StreamController<List<bool>>.broadcast();

  BleConnectionStatus _currentStatus = BleConnectionStatus.disconnected;
  BleDeviceInfo? _connectedDeviceInfo;
  BluetoothDevice? _connectedDevice;

  BluetoothCharacteristic? _cmdCharacteristic;

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSubscription;
  StreamSubscription<List<int>>? _stateCharSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;

  final Map<String, BleDeviceInfo> _discoveredMap = {};

  BleRelayRepository() {
    _initAdapterListener();
  }

  void _initAdapterListener() {
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state != BluetoothAdapterState.on &&
          _currentStatus == BleConnectionStatus.connected) {
        debugPrint('[BLE REPO] Bluetooth adapter turned off while connected.');
        _handleUnexpectedDisconnect('Bluetooth turned off');
      }
    });
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
    // Cancel any existing scan subscription
    await _scanSubscription?.cancel();
    _discoveredMap.clear();
    _discoveredDevicesController.add([]);

    _updateStatus(BleConnectionStatus.scanning);

    try {
      final targetService = Guid(BleConstants.serviceUuid);

      // Start scan with broad discovery, filtering both by service UUID and by known name
      await FlutterBluePlus.startScan(
        withServices: [targetService],
        timeout: timeout ?? BleConstants.scanTimeout,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          final device = r.device;
          final advName = r.advertisementData.advName;
          final platformName = device.platformName;
          final name = advName.isNotEmpty ? advName : platformName;

          final hasService = r.advertisementData.serviceUuids.contains(targetService);

          // Add to map if it has matching service OR matches the relay device name
          if (hasService || name.contains(BleConstants.defaultDeviceName)) {
            final info = BleDeviceInfo(
              id: device.remoteId.str,
              name: name.isNotEmpty ? name : BleConstants.defaultDeviceName,
              rssi: r.rssi,
              hasMatchingService: hasService,
            );
            _discoveredMap[info.id] = info;
          }
        }

        final sorted = _discoveredMap.values.toList()
          ..sort((a, b) => b.rssi.compareTo(a.rssi));

        if (!_discoveredDevicesController.isClosed) {
          _discoveredDevicesController.add(sorted);
        }
      });
    } catch (e) {
      debugPrint('[BLE REPO] Error starting scan: $e');
      _updateStatus(BleConnectionStatus.error);
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      if (_currentStatus == BleConnectionStatus.scanning) {
        _updateStatus(BleConnectionStatus.disconnected);
      }
    } catch (e) {
      debugPrint('[BLE REPO] Error stopping scan: $e');
    }
  }

  @override
  Future<void> connect(String deviceId) async {
    // 1. Stop scanning first
    await stopScan();

    _updateStatus(BleConnectionStatus.connecting);

    try {
      final device = BluetoothDevice.fromId(deviceId);
      _connectedDevice = device;

      // 2. Establish connection with timeout and nonprofit license parameter
      await device.connect(
        license: License.nonprofit,
        timeout: BleConstants.connectTimeout,
        autoConnect: false,
      );

      // 3. Listen for unexpected disconnects
      await _deviceStateSubscription?.cancel();
      _deviceStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleUnexpectedDisconnect('Remote device disconnected');
        }
      });

      // 4. Discover GATT Services
      final services = await device.discoverServices();
      final targetServiceGuid = Guid(BleConstants.serviceUuid);
      final cmdCharGuid = Guid(BleConstants.commandCharUuid);
      final stateCharGuid = Guid(BleConstants.stateCharUuid);

      BluetoothService? matchedService;
      for (final s in services) {
        if (s.uuid == targetServiceGuid) {
          matchedService = s;
          break;
        }
      }

      if (matchedService == null) {
        throw Exception(
            'Target GATT service (${BleConstants.serviceUuid}) not found on peripheral.');
      }

      // 5. Discover Characteristics
      BluetoothCharacteristic? cmdChar;
      BluetoothCharacteristic? stateChar;

      for (final c in matchedService.characteristics) {
        if (c.uuid == cmdCharGuid) {
          cmdChar = c;
        } else if (c.uuid == stateCharGuid) {
          stateChar = c;
        }
      }

      if (cmdChar == null || stateChar == null) {
        throw Exception(
            'Required Command or State characteristics not found in GATT service.');
      }

      _cmdCharacteristic = cmdChar;

      // 6. Subscribe to State Notifications
      await stateChar.setNotifyValue(true);
      await _stateCharSubscription?.cancel();
      _stateCharSubscription = stateChar.onValueReceived.listen((bytes) {
        if (bytes.isNotEmpty) {
          final bitmask = bytes[0];
          final states = BleConstants.decodeStateBitmask(bitmask);
          if (!_relayStatesController.isClosed) {
            _relayStatesController.add(states);
          }
        }
      });

      // 7. Initial read of current state
      try {
        final initialBytes = await stateChar.read();
        if (initialBytes.isNotEmpty) {
          final bitmask = initialBytes[0];
          final states = BleConstants.decodeStateBitmask(bitmask);
          if (!_relayStatesController.isClosed) {
            _relayStatesController.add(states);
          }
        }
      } catch (readErr) {
        debugPrint('[BLE REPO] Initial state read warning: $readErr');
      }

      // Record connected metadata
      _connectedDeviceInfo = BleDeviceInfo(
        id: deviceId,
        name: device.platformName.isNotEmpty
            ? device.platformName
            : (_discoveredMap[deviceId]?.name ?? BleConstants.defaultDeviceName),
        rssi: _discoveredMap[deviceId]?.rssi ?? -60,
        hasMatchingService: true,
      );

      _updateStatus(BleConnectionStatus.connected);
      debugPrint('[BLE REPO] Successfully connected and synced with ${device.platformName}');
    } catch (e) {
      debugPrint('[BLE REPO] Connection failed: $e');
      await _cleanupConnectedDevice();
      _updateStatus(BleConnectionStatus.error);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _updateStatus(BleConnectionStatus.disconnecting);
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
    } catch (e) {
      debugPrint('[BLE REPO] Disconnect error: $e');
    } finally {
      await _cleanupConnectedDevice();
      _updateStatus(BleConnectionStatus.disconnected);
    }
  }

  void _handleUnexpectedDisconnect(String reason) async {
    debugPrint('[BLE REPO] Connection lost: $reason');
    await _cleanupConnectedDevice();
    if (_currentStatus == BleConnectionStatus.connected ||
        _currentStatus == BleConnectionStatus.connecting) {
      _updateStatus(BleConnectionStatus.disconnected);
    }
  }

  Future<void> _cleanupConnectedDevice() async {
    await _deviceStateSubscription?.cancel();
    _deviceStateSubscription = null;

    await _stateCharSubscription?.cancel();
    _stateCharSubscription = null;

    _cmdCharacteristic = null;
    _connectedDevice = null;
    _connectedDeviceInfo = null;
  }

  @override
  Future<void> sendRelayCommand(int relayIndex, bool turnOn) async {
    if (_currentStatus != BleConnectionStatus.connected ||
        _cmdCharacteristic == null) {
      throw StateError('Cannot send command: not connected to ESP32 relay.');
    }

    final payload = BleConstants.encodeRelayCommand(relayIndex, turnOn);
    try {
      await _cmdCharacteristic!.write(
        payload,
        withoutResponse: _cmdCharacteristic!.properties.writeWithoutResponse,
      );
      debugPrint('[BLE REPO] Dispatched command for Relay $relayIndex -> $turnOn');
    } catch (e) {
      debugPrint('[BLE REPO] Failed to write relay command: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendAllRelaysCommand(bool turnOn) async {
    if (_currentStatus != BleConnectionStatus.connected ||
        _cmdCharacteristic == null) {
      throw StateError('Cannot send command: not connected to ESP32 relay.');
    }

    final payload = BleConstants.encodeAllCommand(turnOn);
    try {
      await _cmdCharacteristic!.write(
        payload,
        withoutResponse: _cmdCharacteristic!.properties.writeWithoutResponse,
      );
      debugPrint('[BLE REPO] Dispatched ALL Relays command -> $turnOn');
    } catch (e) {
      debugPrint('[BLE REPO] Failed to write ALL command: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _deviceStateSubscription?.cancel();
    _stateCharSubscription?.cancel();
    _adapterStateSubscription?.cancel();

    _connectionStatusController.close();
    _discoveredDevicesController.close();
    _relayStatesController.close();
  }
}
