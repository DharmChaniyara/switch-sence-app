import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:switch_sense_app/controllers/relay_repository_provider.dart';
import 'package:switch_sense_app/controllers/settings_controller.dart';
import 'package:switch_sense_app/repositories/mock_relay_repository.dart';
import 'package:switch_sense_app/screens/scan_screen.dart';
import 'package:switch_sense_app/services/storage_service.dart';

void main() {
  group('ScanScreen Widget Tests', () {
    late MockRelayRepository mockRepository;
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      mockRepository = MockRelayRepository(
        simulatedLatency: const Duration(milliseconds: 10),
      );
    });

    tearDown(() {
      mockRepository.dispose();
    });

    testWidgets('Scans and discovers ESP32-Relay-8 peripheral with Connect button',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storageService),
            relayRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: const MaterialApp(
            home: ScanScreen(),
          ),
        ),
      );

      // Advance frames without waiting for infinite linear progress indicator animation
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      // Verify discovered device name
      expect(find.text('ESP32-Relay-8'), findsOneWidget);

      // Verify Connect button
      expect(find.text('Connect'), findsWidgets);
    });
  });
}
