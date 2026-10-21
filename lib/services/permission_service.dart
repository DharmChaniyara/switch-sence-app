import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum BlePermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  bluetoothDisabled,
  unsupported,
}

/// Service managing OS runtime permissions and Bluetooth adapter power state.
class PermissionService {
  /// Checks current Bluetooth Low Energy availability and permission status.
  Future<BlePermissionStatus> checkStatus() async {
    // 1. Check if Bluetooth is supported by hardware
    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) {
      return BlePermissionStatus.unsupported;
    }

    // 2. Check adapter power state
    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      return BlePermissionStatus.bluetoothDisabled;
    }

    // 3. Check runtime permissions based on operating system
    if (Platform.isAndroid) {
      // Android 12+ requires bluetoothScan and bluetoothConnect
      final scanStatus = await Permission.bluetoothScan.status;
      final connectStatus = await Permission.bluetoothConnect.status;

      if (scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied) {
        return BlePermissionStatus.permanentlyDenied;
      }

      if (scanStatus.isGranted && connectStatus.isGranted) {
        return BlePermissionStatus.granted;
      }

      // Check legacy location permission if scan/connect are not determined
      final locationStatus = await Permission.locationWhenInUse.status;
      if (locationStatus.isPermanentlyDenied) {
        return BlePermissionStatus.permanentlyDenied;
      }

      if (locationStatus.isGranted && (scanStatus.isGranted || scanStatus.isRestricted)) {
        return BlePermissionStatus.granted;
      }

      return BlePermissionStatus.denied;
    } else if (Platform.isIOS) {
      final bluetoothStatus = await Permission.bluetooth.status;
      if (bluetoothStatus.isPermanentlyDenied) {
        return BlePermissionStatus.permanentlyDenied;
      }
      if (bluetoothStatus.isGranted) {
        return BlePermissionStatus.granted;
      }
      return BlePermissionStatus.denied;
    }

    return BlePermissionStatus.granted;
  }

  /// Requests all necessary permissions for Bluetooth scanning and connectivity.
  Future<BlePermissionStatus> requestPermissions() async {
    final isSupported = await FlutterBluePlus.isSupported;
    if (!isSupported) {
      return BlePermissionStatus.unsupported;
    }

    if (Platform.isAndroid) {
      // Request modern Android 12+ permissions
      final statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();

      final scanStatus = statuses[Permission.bluetoothScan];
      final connectStatus = statuses[Permission.bluetoothConnect];
      final locStatus = statuses[Permission.locationWhenInUse];

      if (scanStatus == PermissionStatus.permanentlyDenied ||
          connectStatus == PermissionStatus.permanentlyDenied ||
          locStatus == PermissionStatus.permanentlyDenied) {
        return BlePermissionStatus.permanentlyDenied;
      }

      final scanOk = scanStatus?.isGranted ?? false;
      final connectOk = connectStatus?.isGranted ?? false;
      final locOk = locStatus?.isGranted ?? false;

      // On Android 12+, scan and connect are sufficient. On Android 11-, location is required.
      if ((scanOk && connectOk) || locOk) {
        // Now check adapter state
        final adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState != BluetoothAdapterState.on) {
          return BlePermissionStatus.bluetoothDisabled;
        }
        return BlePermissionStatus.granted;
      }

      return BlePermissionStatus.denied;
    } else if (Platform.isIOS) {
      final status = await Permission.bluetooth.request();
      if (status.isPermanentlyDenied) {
        return BlePermissionStatus.permanentlyDenied;
      }
      if (status.isGranted) {
        final adapterState = await FlutterBluePlus.adapterState.first;
        if (adapterState != BluetoothAdapterState.on) {
          return BlePermissionStatus.bluetoothDisabled;
        }
        return BlePermissionStatus.granted;
      }
      return BlePermissionStatus.denied;
    }

    return BlePermissionStatus.granted;
  }

  /// Requests the user to turn on Bluetooth on Android if supported.
  Future<void> enableBluetooth() async {
    try {
      if (Platform.isAndroid) {
        await FlutterBluePlus.turnOn();
      }
    } catch (e) {
      debugPrint('Error prompting turn on Bluetooth: $e');
    }
  }

  /// Directs the user to the app system settings page to grant permanently denied permissions.
  Future<bool> openSettings() {
    return openAppSettings();
  }

  /// Listens to adapter state changes (e.g. user toggles Bluetooth in quick settings)
  Stream<BluetoothAdapterState> get adapterStateStream =>
      FlutterBluePlus.adapterState;
}
