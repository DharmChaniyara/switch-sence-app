import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/relay_item.dart';
import '../theme/app_theme.dart';

/// An interactive, accessible Material 3 card representing a physical relay channel.
class RelayCard extends StatelessWidget {
  final RelayItem relay;
  final ValueChanged<int> onToggle;
  final ValueChanged<int>? onEditRequested;

  const RelayCard({
    super.key,
    required this.relay,
    required this.onToggle,
    this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Rich styling depending on ON/OFF state
    final activeBgColor = isDark
        ? const Color(0xFF064E3B).withValues(alpha: 0.4)
        : const Color(0xFFECFDF5);
    final activeBorderColor = AppTheme.emeraldActive.withValues(alpha: 0.8);

    final inactiveBgColor = isDark
        ? AppTheme.darkSurface
        : AppTheme.lightSurface;
    final inactiveBorderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    return Semantics(
      label: relay.semanticLabel,
      button: true,
      toggled: relay.isOn,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: relay.isOn ? activeBgColor : inactiveBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: relay.isOn ? activeBorderColor : inactiveBorderColor,
            width: relay.isOn ? 1.8 : 1.2,
          ),
          boxShadow: relay.isOn
              ? [
                  BoxShadow(
                    color: AppTheme.emeraldActive.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onLongPress: () {
              HapticFeedback.mediumImpact();
              onEditRequested?.call(relay.index);
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Icon, GPIO chip & Edit trigger
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Channel Icon with glow container
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: relay.isOn
                              ? AppTheme.emeraldActive.withValues(alpha: 0.2)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          relay.iconData,
                          size: 24,
                          color: relay.isOn
                              ? AppTheme.emeraldActive
                              : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                        ),
                      ),

                      // GPIO & Channel Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              'GPIO ${relay.gpio}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            tooltip: 'Customize Relay ${relay.number}',
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: () => onEditRequested?.call(relay.index),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Relay Label & Channel Subtitle
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relay ${relay.number}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        relay.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Bottom Row: ON/OFF Text Badge and Accessible Switch / Pending Spinner
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // State Badge (Color + Text ensures accessibility)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: relay.isOn
                              ? AppTheme.emeraldActive.withValues(alpha: 0.2)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: relay.isOn
                                    ? AppTheme.emeraldActive
                                    : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              relay.isOn ? 'ON' : 'OFF',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: relay.isOn
                                    ? AppTheme.emeraldActive
                                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Interactive Switch or Pending Activity Indicator
                      relay.isPending
                          ? Container(
                              width: 48,
                              height: 48,
                              alignment: Alignment.center,
                              child: const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.cyanAccent),
                                ),
                              ),
                            )
                          : SizedBox(
                              width: 48,
                              height: 48,
                              child: Switch(
                                value: relay.isOn,
                                onChanged: (val) {
                                  HapticFeedback.selectionClick();
                                  onToggle(relay.index);
                                },
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
