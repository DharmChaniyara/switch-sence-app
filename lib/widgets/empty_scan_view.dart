import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Informative empty state component rendered when a scan completes without discovering hardware.
class EmptyScanView extends StatelessWidget {
  final VoidCallback onRescan;
  final VoidCallback onEnableDemoMode;

  const EmptyScanView({
    super.key,
    required this.onRescan,
    required this.onEnableDemoMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.bluetooth_searching_rounded,
                size: 40,
                color: AppTheme.cyanAccent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No ESP32 Relays Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scanning for devices advertising the Switch Sense GATT service or name "ESP32-Relay-8".',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Troubleshooting Checklist Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hardware Checklist:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _checklistRow('1. ESP32 board is powered (RED LED ON)', isDark),
                  _checklistRow('2. Firmware esp32_relay_ble.ino flashed', isDark),
                  _checklistRow('3. Bluetooth is ON and within range (~10m)', isDark),
                  _checklistRow('4. Location GPS is ON (required on Android ≤11)', isDark),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Actions: Rescan and Demo Mode
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: const Text('Try Demo Mode'),
                  onPressed: onEnableDemoMode,
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Rescan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onRescan,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _checklistRow(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.emeraldActive),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
