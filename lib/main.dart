import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'controllers/settings_controller.dart';
import 'screens/splash_permission_screen.dart';
import 'services/storage_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize persistent key-value storage
  final storageService = await StorageService.initialize();

  runApp(
    ProviderScope(
      overrides: [
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const SwitchSenseApp(),
    ),
  );
}

class SwitchSenseApp extends ConsumerWidget {
  const SwitchSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);

    return MaterialApp(
      title: 'Switch Sense',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      home: const SplashPermissionScreen(),
    );
  }
}
