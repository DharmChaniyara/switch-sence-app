import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/relay_controller.dart';
import '../controllers/scan_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/ble_device_info.dart';
import '../repositories/relay_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_scan_view.dart';
import 'control_screen.dart';
import 'settings_screen.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  String? _connectingDeviceId;

  @override
  void initState() {
    super.initState();
    // Auto-start scanning when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scanControllerProvider.notifier).startScan();
    });
  }

  Future<void> _handleConnect(BleDeviceInfo device) async {
    setState(() => _connectingDeviceId = device.id);

    try {
      final controller = ref.read(relayControllerProvider.notifier);
      await controller.connect(device.id);

      if (!mounted) return;

      final status = ref.read(relayControllerProvider).connectionStatus;
      if (status == BleConnectionStatus.connected) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ControlScreen()),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to connect to ${device.displayName}: $e'),
          backgroundColor: AppTheme.roseDanger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _connectingDeviceId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanState = ref.watch(scanControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect ESP32 Relay'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
        bottom: scanState.isScanning
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3.0),
                child: LinearProgressIndicator(
                  minHeight: 3.0,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyanAccent),
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          // Subheader Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scanState.isScanning
                            ? AppTheme.cyanAccent
                            : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      scanState.isScanning ? 'Scanning for peripherals...' : 'Scan idle',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
                scanState.isScanning
                    ? TextButton.icon(
                        icon: const Icon(Icons.stop_rounded, size: 16),
                        label: const Text('Stop'),
                        onPressed: () => ref.read(scanControllerProvider.notifier).stopScan(),
                      )
                    : TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Scan Again'),
                        onPressed: () => ref.read(scanControllerProvider.notifier).startScan(),
                      ),
              ],
            ),
          ),

          // Error Banner if present
          if (scanState.errorMessage != null)
            MaterialBanner(
              backgroundColor: AppTheme.roseDanger.withValues(alpha: 0.15),
              content: Text(
                scanState.errorMessage!,
                style: const TextStyle(color: AppTheme.roseDanger, fontSize: 13),
              ),
              actions: [
                TextButton(
                  onPressed: () => ref.read(scanControllerProvider.notifier).clearError(),
                  child: const Text('Dismiss'),
                ),
              ],
            ),

          // Discovered Devices List or Empty State
          Expanded(
            child: scanState.devices.isEmpty
                ? (scanState.isScanning
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 18),
                            Text(
                              'Listening for ESP32 advertisement beacons...',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : EmptyScanView(
                        onRescan: () => ref.read(scanControllerProvider.notifier).startScan(),
                        onEnableDemoMode: () async {
                          final navigator = Navigator.of(context);
                          await ref.read(settingsControllerProvider.notifier).setDemoMode(true);
                          navigator.pushReplacement(
                            MaterialPageRoute(builder: (_) => const ControlScreen()),
                          );
                        },
                      ))
                : RefreshIndicator(
                    onRefresh: () => ref.read(scanControllerProvider.notifier).startScan(),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: scanState.devices.length,
                      separatorBuilder: (ctx, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final device = scanState.devices[index];
                        final isConnecting = _connectingDeviceId == device.id;

                        return _buildDeviceTile(
                          context: context,
                          device: device,
                          isConnecting: isConnecting,
                          isDark: isDark,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceTile({
    required BuildContext context,
    required BleDeviceInfo device,
    required bool isConnecting,
    required bool isDark,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Signal RSSI Icon with visual level
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.bluetooth_rounded,
                color: AppTheme.primaryBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),

            // Device Name and Hardware Identifiers
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          device.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (device.hasMatchingService) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldActive.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'MATCH',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.emeraldActive,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        device.id,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  ${device.rssi} dBm (${device.signalQuality})',
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

            const SizedBox(width: 12),

            // Connect Action
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: isConnecting ? null : () => _handleConnect(device),
              child: isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}
