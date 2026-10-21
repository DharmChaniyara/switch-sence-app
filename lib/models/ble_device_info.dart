import 'package:flutter/foundation.dart';

/// Simplified platform-independent representation of a discovered BLE device.
@immutable
class BleDeviceInfo {
  /// Unique device identifier (MAC address on Android, UUID on iOS)
  final String id;

  /// Advertised name or platform friendly name
  final String name;

  /// Received Signal Strength Indicator in dBm
  final int rssi;

  /// Whether the device explicitly advertised the Switch Sense service UUID
  final bool hasMatchingService;

  const BleDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
    this.hasMatchingService = false,
  });

  /// User-friendly name fallback
  String get displayName => name.trim().isEmpty ? 'Unknown BLE Device' : name;

  /// Qualitative signal strength category (for UI iconography and color)
  String get signalQuality {
    if (rssi >= -60) return 'Excellent';
    if (rssi >= -75) return 'Good';
    if (rssi >= -85) return 'Fair';
    return 'Weak';
  }

  /// Normalized 0-1 signal quality fraction
  double get signalFraction {
    if (rssi >= -50) return 1.0;
    if (rssi <= -100) return 0.05;
    return (rssi + 100) / 50.0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDeviceInfo &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          rssi == other.rssi &&
          hasMatchingService == other.hasMatchingService;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      rssi.hashCode ^
      hasMatchingService.hashCode;

  @override
  String toString() => 'BleDeviceInfo(id: $id, name: "$name", rssi: $rssi dBm)';
}
