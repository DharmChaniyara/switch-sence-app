import 'package:flutter/material.dart';

/// Represents a single physical relay channel on the 8-channel board.
@immutable
class RelayItem {
  /// Zero-based index (0 to 7)
  final int index;

  /// Hardware ESP32 GPIO pin number
  final int gpio;

  /// User-customizable label (e.g., "Main Light", "Ceiling Fan")
  final String name;

  /// Current confirmed state from hardware (true = ON / energized, false = OFF / de-energized)
  final bool isOn;

  /// Icon identifier for user personalization
  final String iconKey;

  /// True when a command has been dispatched over BLE and we are awaiting GATT notification confirmation
  final bool isPending;

  const RelayItem({
    required this.index,
    required this.gpio,
    required this.name,
    this.isOn = false,
    this.iconKey = 'power',
    this.isPending = false,
  });

  /// 1-based display number for users ("Relay 1", etc.)
  int get number => index + 1;

  /// Fallback display title if user hasn't set a custom label
  String get displayName => name.trim().isEmpty ? 'Relay $number' : name;

  /// Accessibility semantic label
  String get semanticLabel =>
      '$displayName on GPIO $gpio, currently ${isOn ? "on" : "off"}${isPending ? ", updating" : ""}';

  RelayItem copyWith({
    int? index,
    int? gpio,
    String? name,
    bool? isOn,
    String? iconKey,
    bool? isPending,
  }) {
    return RelayItem(
      index: index ?? this.index,
      gpio: gpio ?? this.gpio,
      name: name ?? this.name,
      isOn: isOn ?? this.isOn,
      iconKey: iconKey ?? this.iconKey,
      isPending: isPending ?? this.isPending,
    );
  }

  /// Maps string iconKey to Material IconData
  IconData get iconData {
    switch (iconKey.toLowerCase()) {
      case 'light':
      case 'lightbulb':
        return Icons.lightbulb_rounded;
      case 'fan':
        return Icons.mode_fan_off_rounded;
      case 'outlet':
      case 'socket':
        return Icons.power_rounded;
      case 'tv':
        return Icons.tv_rounded;
      case 'ac':
        return Icons.ac_unit_rounded;
      case 'kitchen':
        return Icons.microwave_rounded;
      case 'computer':
        return Icons.computer_rounded;
      case 'water':
        return Icons.water_drop_rounded;
      case 'router':
        return Icons.router_rounded;
      case 'switch':
      default:
        return Icons.toggle_on_rounded;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RelayItem &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          gpio == other.gpio &&
          name == other.name &&
          isOn == other.isOn &&
          iconKey == other.iconKey &&
          isPending == other.isPending;

  @override
  int get hashCode =>
      index.hashCode ^
      gpio.hashCode ^
      name.hashCode ^
      isOn.hashCode ^
      iconKey.hashCode ^
      isPending.hashCode;

  @override
  String toString() {
    return 'RelayItem(index: $index, gpio: $gpio, name: "$name", isOn: $isOn, isPending: $isPending)';
  }
}
