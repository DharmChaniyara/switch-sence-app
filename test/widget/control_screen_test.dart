import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:switch_sense_app/controllers/relay_repository_provider.dart';
import 'package:switch_sense_app/controllers/settings_controller.dart';
import 'package:switch_sense_app/repositories/mock_relay_repository.dart';
import 'package:switch_sense_app/screens/control_screen.dart';
import 'package:switch_sense_app/services/storage_service.dart';

void main() {
  group('ControlScreen Widget Tests', () {
    late MockRelayRepository mockRepository;
    late StorageService storageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storageService = StorageService(prefs);
      mockRepository = MockRelayRepository(
        simulatedLatency: Duration.zero,
      );
    });

    tearDown(() {
      mockRepository.dispose();
    });

    testWidgets('Renders all 8 relay channels with correct GPIO mappings and master buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storageService),
            relayRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: const MaterialApp(
            home: ControlScreen(),
          ),
        ),
      );

      await tester.pump();

      // Verify Screen Title
      expect(find.text('Switch Sense'), findsOneWidget);

      // Verify Master Actions
      expect(find.text('ALL ON'), findsOneWidget);
      expect(find.text('ALL OFF'), findsOneWidget);

      // Verify All 8 Relay Channel titles exist
      for (int i = 1; i <= 8; i++) {
        expect(find.text('Relay $i'), findsWidgets);
      }

      // Verify Preserved Hardware GPIO mappings
      expect(find.text('GPIO 13'), findsOneWidget);
      expect(find.text('GPIO 12'), findsOneWidget);
      expect(find.text('GPIO 14'), findsOneWidget);
      expect(find.text('GPIO 27'), findsOneWidget);
      expect(find.text('GPIO 26'), findsOneWidget);
      expect(find.text('GPIO 25'), findsOneWidget);
      expect(find.text('GPIO 33'), findsOneWidget);
      expect(find.text('GPIO 32'), findsOneWidget);
    });

    testWidgets('Tapping ALL ON opens safety confirmation dialog', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Connect mock device first
      await mockRepository.connect('AA:BB:CC:DD:EE:01');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storageService),
            relayRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: const MaterialApp(
            home: ControlScreen(),
          ),
        ),
      );

      await tester.pump();

      // Tap ALL ON
      final allOnButton = find.text('ALL ON');
      expect(allOnButton, findsOneWidget);
      await tester.tap(allOnButton);
      await tester.pump();

      // Verify Confirmation Modal appears
      expect(find.text('Turn ON All Relays?'), findsOneWidget);
      expect(find.text('Confirm ALL ON'), findsOneWidget);

      // Tap Cancel
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // Modal dismissed
      expect(find.text('Turn ON All Relays?'), findsNothing);
    });

    testWidgets('Tapping single relay switch sends command and updates UI after confirmation',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await mockRepository.connect('AA:BB:CC:DD:EE:01');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            storageServiceProvider.overrideWithValue(storageService),
            relayRepositoryProvider.overrideWithValue(mockRepository),
          ],
          child: const MaterialApp(
            home: ControlScreen(),
          ),
        ),
      );

      await tester.pump();

      // Find first Switch widget (Relay 1)
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      // Tap the first switch
      await tester.tap(switches.first);
      await tester.pump();

      // Relay 1 should now be confirmed ON
      expect(find.text('ON'), findsWidgets);
    });
  });
}
