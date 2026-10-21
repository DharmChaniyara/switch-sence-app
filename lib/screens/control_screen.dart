import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/relay_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/relay_item.dart';
import '../repositories/relay_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/connection_status_bar.dart';
import '../widgets/relay_card.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';

class ControlScreen extends ConsumerStatefulWidget {
  const ControlScreen({super.key});

  @override
  ConsumerState<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends ConsumerState<ControlScreen> {
  @override
  Widget build(BuildContext context) {
    final relayState = ref.watch(relayControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Listen for error messages and display floating snackbar
    ref.listen<RelayDashboardState>(relayControllerProvider, (prev, next) {
      if (next.errorMessage != null && next.errorMessage != prev?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppTheme.roseDanger,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () => ref.read(relayControllerProvider.notifier).clearError(),
            ),
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Switch Sense'),
            if (settings.isDemoMode) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.amberWarning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.amberWarning, width: 0.8),
                ),
                child: const Text(
                  'DEMO MODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.amberWarning,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Relays',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Connection Status Banner
            ConnectionStatusBar(
              status: relayState.connectionStatus,
              device: relayState.connectedDevice,
              activeRelaysCount: relayState.activeCount,
              onDisconnect: () async {
                final navigator = Navigator.of(context);
                await ref.read(relayControllerProvider.notifier).disconnect();
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const ScanScreen()),
                );
              },
            ),

            // Disconnected Warning Banner if connection drops
            if (relayState.connectionStatus != BleConnectionStatus.connected)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppTheme.roseDanger.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppTheme.roseDanger, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'ESP32 disconnected. Relays cannot be toggled.',
                        style: TextStyle(color: AppTheme.roseDanger, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const ScanScreen()),
                        );
                      },
                      child: const Text('Re-scan'),
                    ),
                  ],
                ),
              ),

            // Master Action Bar: ALL ON / ALL OFF
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.power_off_rounded, size: 18),
                      label: const Text('ALL OFF'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: relayState.isConnected
                          ? () {
                              HapticFeedback.mediumImpact();
                              ref.read(relayControllerProvider.notifier).setAllRelays(false);
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: const Text('ALL ON'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emeraldActive,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: relayState.isConnected
                          ? () async {
                              final confirmed = await ConfirmAllOnDialog.show(context);
                              if (confirmed == true) {
                                HapticFeedback.heavyImpact();
                                ref.read(relayControllerProvider.notifier).setAllRelays(true);
                              }
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),

            // Responsive Relay Cards Grid
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Responsive column calculation: 2 columns on phone, 3 on small tablet, 4 on large tablet
                  int crossAxisCount = 2;
                  if (constraints.maxWidth >= 900) {
                    crossAxisCount = 4;
                  } else if (constraints.maxWidth >= 600) {
                    crossAxisCount = 3;
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: constraints.maxWidth < 400 ? 0.95 : 1.05,
                    ),
                    itemCount: relayState.relays.length,
                    itemBuilder: (context, index) {
                      final relay = relayState.relays[index];
                      return RelayCard(
                        relay: relay,
                        onToggle: (idx) {
                          ref.read(relayControllerProvider.notifier).toggleRelay(idx);
                        },
                        onEditRequested: (idx) => _showEditRelayDialog(context, relay),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditRelayDialog(BuildContext context, RelayItem relay) {
    final textController = TextEditingController(text: relay.name);
    String selectedIcon = relay.iconKey;

    final icons = [
      {'key': 'light', 'name': 'Light', 'icon': Icons.lightbulb_rounded},
      {'key': 'fan', 'name': 'Fan', 'icon': Icons.mode_fan_off_rounded},
      {'key': 'outlet', 'name': 'Socket', 'icon': Icons.power_rounded},
      {'key': 'tv', 'name': 'TV', 'icon': Icons.tv_rounded},
      {'key': 'ac', 'name': 'AC', 'icon': Icons.ac_unit_rounded},
      {'key': 'kitchen', 'name': 'Appliance', 'icon': Icons.microwave_rounded},
      {'key': 'router', 'name': 'Router', 'icon': Icons.router_rounded},
      {'key': 'switch', 'name': 'Switch', 'icon': Icons.toggle_on_rounded},
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            title: Text('Customize Relay ${relay.number} (GPIO ${relay.gpio})'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: textController,
                    decoration: const InputDecoration(
                      labelText: 'Appliance / Location Label',
                      hintText: 'e.g., Workshop Bench Light',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 24,
                  ),
                  const SizedBox(height: 12),
                  const Text('Select Icon:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: icons.map((item) {
                      final key = item['key'] as String;
                      final iconData = item['icon'] as IconData;
                      final isSelected = selectedIcon == key;

                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = key),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.cyanAccent.withValues(alpha: 0.2)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? AppTheme.cyanAccent : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            iconData,
                            size: 24,
                            color: isSelected
                                ? AppTheme.cyanAccent
                                : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newName = textController.text.trim();
                  ref.read(relayControllerProvider.notifier).renameRelay(
                        relay.index,
                        newName.isEmpty ? 'Relay ${relay.number}' : newName,
                      );
                  ref.read(relayControllerProvider.notifier).setRelayIcon(
                        relay.index,
                        selectedIcon,
                      );
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}
