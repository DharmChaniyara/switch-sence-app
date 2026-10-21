import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/ble_relay_repository.dart';
import '../repositories/mock_relay_repository.dart';
import '../repositories/relay_repository.dart';
import 'settings_controller.dart';

/// Provider for the active RelayRepository (switches between BLE and Mock based on Demo Mode).
final relayRepositoryProvider = Provider<RelayRepository>((ref) {
  final isDemoMode = ref.watch(settingsControllerProvider.select((s) => s.isDemoMode));

  final repository = isDemoMode
      ? MockRelayRepository()
      : BleRelayRepository();

  ref.onDispose(() {
    repository.dispose();
  });

  return repository;
});
