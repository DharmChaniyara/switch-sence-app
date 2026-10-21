import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/relay_controller.dart';
import '../controllers/settings_controller.dart';
import '../services/permission_service.dart';
import '../theme/app_theme.dart';
import 'control_screen.dart';
import 'scan_screen.dart';

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

class SplashPermissionScreen extends ConsumerStatefulWidget {
  const SplashPermissionScreen({super.key});

  @override
  ConsumerState<SplashPermissionScreen> createState() => _SplashPermissionScreenState();
}

class _SplashPermissionScreenState extends ConsumerState<SplashPermissionScreen> {
  BlePermissionStatus _status = BlePermissionStatus.denied;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkInitialPermissions();
  }

  Future<void> _checkInitialPermissions() async {
    setState(() => _isChecking = true);
    final service = ref.read(permissionServiceProvider);
    final status = await service.checkStatus();

    if (!mounted) return;

    setState(() {
      _status = status;
      _isChecking = false;
    });

    if (status == BlePermissionStatus.granted) {
      _navigateForward();
    }
  }

  Future<void> _requestPermissions() async {
    final service = ref.read(permissionServiceProvider);
    final result = await service.requestPermissions();

    if (!mounted) return;

    setState(() => _status = result);

    if (result == BlePermissionStatus.granted) {
      _navigateForward();
    }
  }

  Future<void> _enableBluetooth() async {
    final service = ref.read(permissionServiceProvider);
    await service.enableBluetooth();
    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted) return;
    _checkInitialPermissions();
  }

  void _navigateForward() {
    if (!mounted) return;

    final settings = ref.read(settingsControllerProvider);

    if (settings.autoReconnect && settings.lastDeviceId != null) {
      ref.read(relayControllerProvider.notifier).connect(settings.lastDeviceId!);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ControlScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ScanScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.cyanAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.toggle_on_rounded, size: 40, color: AppTheme.cyanAccent),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Checking Bluetooth Permissions...',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // App Logo / Icon Header
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primaryBlue, AppTheme.cyanAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cyanAccent.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.power_rounded, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),

              Text(
                'Switch Sense',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Direct ESP32 Bluetooth Low Energy 8-Channel Relay Controller',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 36),

              // Permission Details Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : AppTheme.lightSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Column(
                  children: [
                    _permissionRow(
                      icon: Icons.bluetooth_searching_rounded,
                      title: 'Bluetooth Scan & Connect',
                      subtitle: 'Discovers and establishes GATT links with your ESP32 board.',
                      isDark: isDark,
                    ),
                    const Divider(height: 24),
                    _permissionRow(
                      icon: Icons.location_on_outlined,
                      title: 'Nearby Devices Access',
                      subtitle: 'Required by Android to scan for BLE beacons without Wi-Fi.',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Context-sensitive Action Buttons
              if (_status == BlePermissionStatus.bluetoothDisabled) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.bluetooth_rounded),
                  label: const Text('Turn On Bluetooth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: _enableBluetooth,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _checkInitialPermissions,
                  child: const Text('Re-check Status'),
                ),
              ] else if (_status == BlePermissionStatus.permanentlyDenied) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Open App Settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.amberWarning,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: () => ref.read(permissionServiceProvider).openSettings(),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _checkInitialPermissions,
                  child: const Text('I have granted permissions in Settings'),
                ),
              ] else ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.security_rounded),
                  label: const Text('Grant Permissions & Continue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: _requestPermissions,
                ),
              ],

              const SizedBox(height: 12),

              // Quick bypass for testing in Demo Mode
              TextButton.icon(
                icon: const Icon(Icons.science_outlined, size: 16),
                label: const Text('Continue in Demo Mode (Without Hardware)'),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await ref.read(settingsControllerProvider.notifier).setDemoMode(true);
                  navigator.pushReplacement(
                    MaterialPageRoute(builder: (_) => const ControlScreen()),
                  );
                },
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.cyanAccent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppTheme.cyanAccent),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
