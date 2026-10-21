import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Modal dialog confirming master activation of all 8 relays.
class ConfirmAllOnDialog extends StatelessWidget {
  const ConfirmAllOnDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmAllOnDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      icon: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.amberWarning.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.warning_amber_rounded,
          color: AppTheme.amberWarning,
          size: 32,
        ),
      ),
      title: const Text(
        'Turn ON All Relays?',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
      ),
      content: Text(
        'This will simultaneously energize all 8 channels, activating all connected high-voltage appliances, tools, and lights.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        ),
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.amberWarning,
            foregroundColor: Colors.black,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Confirm ALL ON'),
        ),
      ],
    );
  }
}
