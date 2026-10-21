import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/ble_constants.dart';
import '../controllers/relay_controller.dart';
import '../controllers/settings_controller.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final relayState = ref.watch(relayControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Configuration'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section 1: Appearance & Theme
          _sectionHeader('APPEARANCE', isDark),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme Mode',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose how Switch Sense appears on your device',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded),
                          label: Text('Dark'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded),
                          label: Text('Light'),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (newSelection) {
                        ref.read(settingsControllerProvider.notifier).setThemeMode(newSelection.first);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Connectivity & Automation
          _sectionHeader('BLUETOOTH & AUTOMATION', isDark),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Auto-reconnect on Launch'),
                  subtitle: Text(
                    settings.lastDeviceName != null
                        ? 'Remembers "${settings.lastDeviceName}" and reconnects automatically'
                        : 'Reconnects to the last paired relay board upon opening app',
                  ),
                  value: settings.autoReconnect,
                  onChanged: (val) {
                    ref.read(settingsControllerProvider.notifier).setAutoReconnect(val);
                  },
                ),
                if (settings.lastDeviceId != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.bookmark_remove_outlined),
                    title: const Text('Forget Saved Peripheral'),
                    subtitle: Text('ID: ${settings.lastDeviceId}'),
                    trailing: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.roseDanger,
                        side: const BorderSide(color: AppTheme.roseDanger),
                      ),
                      onPressed: () async {
                        await ref.read(settingsControllerProvider.notifier).forgetLastDevice();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Saved peripheral cleared.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: const Text('Forget'),
                    ),
                  ),
                ],
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Demo / Simulation Mode'),
                  subtitle: const Text('Emulates ESP32 GATT hardware locally for testing without physical board'),
                  value: settings.isDemoMode,
                  onChanged: (val) async {
                    await ref.read(settingsControllerProvider.notifier).setDemoMode(val);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            val
                                ? 'Demo Mode enabled: Local mock relay active.'
                                : 'Demo Mode disabled: Standard BLE stack active.',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 3: Relay Channel Customization
          _sectionHeader('CHANNEL LABELS & ICONS', isDark),
          Card(
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: relayState.relays.length,
              separatorBuilder: (ctx, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final relay = relayState.relays[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.cyanAccent.withValues(alpha: 0.15),
                    child: Icon(relay.iconData, color: AppTheme.cyanAccent, size: 20),
                  ),
                  title: Text(relay.displayName),
                  subtitle: Text('Channel ${relay.number} • GPIO ${relay.gpio}'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showQuickRenameDialog(context, ref, relay.index, relay.name),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Section 4: Specifications & Hardware Info
          _sectionHeader('SYSTEM & PROTOCOL SPECIFICATION', isDark),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: AppTheme.primaryBlue),
              title: const Text('BLE GATT & Hardware Specification'),
              subtitle: const Text('Inspect UUIDs, command byte protocol, pin mapping & safety notes'),
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onTap: () => _showProtocolModal(context, isDark),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  void _showQuickRenameDialog(BuildContext context, WidgetRef ref, int index, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename Channel ${index + 1}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Channel Label',
            border: OutlineInputBorder(),
          ),
          maxLength: 24,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              ref.read(relayControllerProvider.notifier).renameRelay(
                    index,
                    newName.isEmpty ? 'Relay ${index + 1}' : newName,
                  );
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showProtocolModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Switch Sense BLE GATT Specification',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _specItem('Service UUID', BleConstants.serviceUuid),
              _specItem('Command Characteristic (Write)', BleConstants.commandCharUuid),
              _specItem('State Characteristic (Read + Notify)', BleConstants.stateCharUuid),
              _specItem('Device Advertised Name', BleConstants.defaultDeviceName),
              const Divider(height: 28),
              const Text(
                'Hardware Pin Configuration',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Relays 1-8 GPIO Map: 13, 12, 14, 27, 26, 25, 33, 32\n'
                'Logic: Active-LOW (LOW = Relay ON/Energized, HIGH = Relay OFF/Open)\n'
                'Boot Safety: Presets pin HIGH prior to setting pinMode(OUTPUT) to eliminate boot clicks.',
                style: TextStyle(height: 1.4, fontSize: 13),
              ),
              const Divider(height: 28),
              const Text(
                'Strapping Pin Warning (GPIO 12)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.amberWarning),
              ),
              const SizedBox(height: 8),
              const Text(
                'GPIO 12 (MTDI) controls internal flash voltage on ESP32 reset. If externally pulled HIGH by relay board optocouplers at boot, flash failure may occur. Ensure relay board pull-up does not assert GPIO 12 during boot, or burn eFuse to force 3.3V flash voltage.',
                style: TextStyle(height: 1.4, fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close Specification'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _specItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: const TextStyle(fontSize: 13, fontFamily: 'monospace', color: AppTheme.cyanAccent),
          ),
        ],
      ),
    );
  }
}
