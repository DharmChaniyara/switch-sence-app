import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ble_device_info.dart';
import '../repositories/relay_repository.dart';
import 'relay_repository_provider.dart';

@immutable
class ScanState {
  final List<BleDeviceInfo> devices;
  final bool isScanning;
  final String? errorMessage;

  const ScanState({
    this.devices = const [],
    this.isScanning = false,
    this.errorMessage,
  });

  ScanState copyWith({
    List<BleDeviceInfo>? devices,
    bool? isScanning,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ScanState(
      devices: devices ?? this.devices,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ScanNotifier extends Notifier<ScanState> {
  StreamSubscription<List<BleDeviceInfo>>? _devicesSub;
  StreamSubscription<BleConnectionStatus>? _statusSub;

  @override
  ScanState build() {
    final repository = ref.watch(relayRepositoryProvider);
    _initListeners(repository);

    ref.onDispose(() {
      _devicesSub?.cancel();
      _statusSub?.cancel();
    });

    return const ScanState();
  }

  RelayRepository get _repository => ref.read(relayRepositoryProvider);

  void _initListeners(RelayRepository repository) {
    _devicesSub?.cancel();
    _statusSub?.cancel();

    _devicesSub = repository.discoveredDevicesStream.listen((devices) {
      state = state.copyWith(devices: devices);
    });

    _statusSub = repository.connectionStatusStream.listen((status) {
      if (status == BleConnectionStatus.scanning) {
        state = state.copyWith(isScanning: true, clearError: true);
      } else {
        state = state.copyWith(isScanning: false);
      }

      if (status == BleConnectionStatus.error) {
        state = state.copyWith(
          errorMessage: 'An error occurred during Bluetooth scanning. Ensure Bluetooth is enabled.',
        );
      }
    });
  }

  Future<void> startScan() async {
    state = state.copyWith(clearError: true);
    try {
      await _repository.startScan();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to start scan: $e');
    }
  }

  Future<void> stopScan() async {
    try {
      await _repository.stopScan();
    } catch (e) {
      debugPrint('[SCAN] Error stopping scan: $e');
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final scanControllerProvider =
    NotifierProvider<ScanNotifier, ScanState>(ScanNotifier.new);
