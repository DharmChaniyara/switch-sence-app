import 'package:flutter/material.dart';
import '../models/ble_device_info.dart';
import '../repositories/relay_repository.dart';
import '../theme/app_theme.dart';

/// Status banner showing BLE connection health, device info, active relays, and disconnect button.
class ConnectionStatusBar extends StatelessWidget {
  final BleConnectionStatus status;
  final BleDeviceInfo? device;
  final int activeRelaysCount;
  final VoidCallback onDisconnect;

  const ConnectionStatusBar({
    super.key,
    required this.status,
    required this.device,
    required this.activeRelaysCount,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isConnected = status == BleConnectionStatus.connected;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          // Bluetooth Status Icon with pulse
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isConnected
                  ? AppTheme.cyanAccent.withValues(alpha: 0.15)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
              size: 20,
              color: isConnected ? AppTheme.cyanAccent : AppTheme.darkTextSecondary,
            ),
          ),
          const SizedBox(width: 12),

          // Device Name & Link Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isConnected ? (device?.displayName ?? 'ESP32 Relay') : 'Disconnected',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Active Relays Tag
                    if (isConnected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: activeRelaysCount > 0
                              ? AppTheme.emeraldActive.withValues(alpha: 0.2)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$activeRelaysCount/8 ON',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: activeRelaysCount > 0
                                ? AppTheme.emeraldActive
                                : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected ? AppTheme.emeraldActive : AppTheme.roseDanger,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isConnected
                          ? 'Live GATT Sync • ${device?.rssi ?? -60} dBm (${device?.signalQuality ?? "Good"})'
                          : 'No active peripheral connection',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Disconnect Action
          if (isConnected)
            OutlinedButton.icon(
              icon: const Icon(Icons.link_off_rounded, size: 16),
              label: const Text('Disconnect'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                side: BorderSide(
                  color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                ),
              ),
              onPressed: onDisconnect,
            ),
        ],
      ),
    );
  }
}
