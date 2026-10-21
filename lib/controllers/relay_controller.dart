import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/ble_constants.dart';
import '../models/ble_device_info.dart';
import '../models/relay_item.dart';
import '../repositories/relay_repository.dart';
import '../services/storage_service.dart';
import 'relay_repository_provider.dart';
import 'settings_controller.dart';

/// Comprehensive state for the Relay Control Panel.
@immutable
class RelayDashboardState {
  final List<RelayItem> relays;
  final BleConnectionStatus connectionStatus;
  final BleDeviceInfo? connectedDevice;
  final String? errorMessage;
  final String? infoMessage;

  const RelayDashboardState({
    required this.relays,
    this.connectionStatus = BleConnectionStatus.disconnected,
    this.connectedDevice,
    this.errorMessage,
    this.infoMessage,
  });

  bool get isConnected => connectionStatus == BleConnectionStatus.connected;
  bool get isConnecting => connectionStatus == BleConnectionStatus.connecting;

  /// Returns true if all 8 relays are confirmed ON
  bool get areAllOn => relays.every((r) => r.isOn);

  /// Returns true if all 8 relays are confirmed OFF
  bool get areAllOff => relays.every((r) => !r.isOn);

  /// Returns count of relays currently ON
  int get activeCount => relays.where((r) => r.isOn).length;

  RelayDashboardState copyWith({
    List<RelayItem>? relays,
    BleConnectionStatus? connectionStatus,
    BleDeviceInfo? connectedDevice,
    String? errorMessage,
    String? infoMessage,
    bool clearError = false,
    bool clearInfo = false,
    bool clearDevice = false,
  }) {
    return RelayDashboardState(
      relays: relays ?? this.relays,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectedDevice: clearDevice ? null : (connectedDevice ?? this.connectedDevice),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      infoMessage: clearInfo ? null : (infoMessage ?? this.infoMessage),
    );
  }
}

/// Main controller managing the 8 physical relays and their BLE synchronization.
class RelayController extends Notifier<RelayDashboardState> {
  StreamSubscription<BleConnectionStatus>? _statusSub;
  StreamSubscription<List<bool>>? _statesSub;

  // Active command timeout timers per relay index (0-7, plus 0xFF for ALL)
  final Map<int, Timer> _pendingTimers = {};

  @override
  RelayDashboardState build() {
    final repository = ref.watch(relayRepositoryProvider);
    final storage = ref.watch(storageServiceProvider);

    _initSubscriptions(repository);

    ref.onDispose(() {
      _clearAllPendingTimers();
      _statusSub?.cancel();
      _statesSub?.cancel();
    });

    return RelayDashboardState(
      relays: _buildInitialRelays(storage),
      connectionStatus: repository.currentStatus,
      connectedDevice: repository.connectedDevice,
    );
  }

  RelayRepository get _repository => ref.read(relayRepositoryProvider);
  StorageService get _storage => ref.read(storageServiceProvider);

  static List<RelayItem> _buildInitialRelays(StorageService storage) {
    return List.generate(BleConstants.totalRelays, (i) {
      final defaultName = 'Relay ${i + 1}';
      final name = storage.getRelayName(i, fallback: defaultName);
      final icon = storage.getRelayIcon(i, fallback: 'power');
      return RelayItem(
        index: i,
        gpio: BleConstants.relayGpioPins[i],
        name: name,
        iconKey: icon,
        isOn: false,
        isPending: false,
      );
    });
  }

  void _initSubscriptions(RelayRepository repository) {
    _statusSub?.cancel();
    _statesSub?.cancel();

    _statusSub = repository.connectionStatusStream.listen((status) {
      debugPrint('[RELAY CTRL] Connection status changed to: $status');
      state = state.copyWith(
        connectionStatus: status,
        connectedDevice: repository.connectedDevice,
        clearDevice: status == BleConnectionStatus.disconnected,
      );

      if (status == BleConnectionStatus.connected && repository.connectedDevice != null) {
        final device = repository.connectedDevice!;
        ref.read(settingsControllerProvider.notifier).saveLastDevice(
              id: device.id,
              name: device.name,
            );
      }

      if (status == BleConnectionStatus.disconnected) {
        // Clear pending flags if disconnected
        _clearAllPendingTimers();
        final resetRelays = state.relays.map((r) => r.copyWith(isPending: false)).toList();
        state = state.copyWith(relays: resetRelays);
      }
    });

    // Listen to live hardware state notifications
    _statesSub = repository.relayStatesStream.listen((confirmedStates) {
      debugPrint('[RELAY CTRL] Received hardware confirmed states: $confirmedStates');
      _applyConfirmedStates(confirmedStates);
    });
  }

  void _applyConfirmedStates(List<bool> confirmedStates) {
    final updatedList = List<RelayItem>.from(state.relays);

    for (int i = 0; i < BleConstants.totalRelays && i < confirmedStates.length; i++) {
      if (_pendingTimers.containsKey(i)) {
        _pendingTimers[i]?.cancel();
        _pendingTimers.remove(i);
      }

      final item = updatedList[i];
      updatedList[i] = item.copyWith(
        isOn: confirmedStates[i],
        isPending: false,
      );
    }

    if (_pendingTimers.containsKey(BleConstants.allRelaysTarget)) {
      _pendingTimers[BleConstants.allRelaysTarget]?.cancel();
      _pendingTimers.remove(BleConstants.allRelaysTarget);
    }

    state = state.copyWith(
      relays: updatedList,
      clearError: true,
    );
  }

  /// Toggles a single relay with optimistic pending indicator and 2-second confirmation timeout.
  Future<void> toggleRelay(int index) async {
    if (index < 0 || index >= state.relays.length) return;

    final targetRelay = state.relays[index];

    // Debounce / Pending lock: if command is already in-flight, ignore repeated taps
    if (targetRelay.isPending) {
      debugPrint('[RELAY CTRL] Relay $index is already pending. Tap ignored.');
      return;
    }

    if (!state.isConnected) {
      state = state.copyWith(
        errorMessage: 'Cannot toggle Relay ${index + 1}: Not connected to ESP32.',
      );
      return;
    }

    final newTargetState = !targetRelay.isOn;

    // 1. Mark as pending in UI
    final updatedList = List<RelayItem>.from(state.relays);
    updatedList[index] = targetRelay.copyWith(isPending: true);
    state = state.copyWith(relays: updatedList, clearError: true);

    // 2. Start 2-second timeout timer
    _pendingTimers[index]?.cancel();
    _pendingTimers[index] = Timer(BleConstants.commandTimeout, () {
      _handleCommandTimeout(index);
    });

    // 3. Dispatch BLE command
    try {
      await _repository.sendRelayCommand(index, newTargetState);
    } catch (e) {
      _pendingTimers[index]?.cancel();
      _pendingTimers.remove(index);

      final revertList = List<RelayItem>.from(state.relays);
      revertList[index] = targetRelay.copyWith(isPending: false);
      state = state.copyWith(
        relays: revertList,
        errorMessage: 'Failed to send command for Relay ${index + 1}: $e',
      );
    }
  }

  /// Sends ALL ON or ALL OFF master command with 2-second confirmation timeout.
  Future<void> setAllRelays(bool turnOn) async {
    if (!state.isConnected) {
      state = state.copyWith(
        errorMessage: 'Cannot switch all relays: Not connected to ESP32.',
      );
      return;
    }

    // 1. Mark all as pending
    final updatedList = state.relays.map((r) => r.copyWith(isPending: true)).toList();
    state = state.copyWith(relays: updatedList, clearError: true);

    // 2. Start master timeout timer
    _pendingTimers[BleConstants.allRelaysTarget]?.cancel();
    _pendingTimers[BleConstants.allRelaysTarget] = Timer(BleConstants.commandTimeout, () {
      _handleAllCommandTimeout();
    });

    // 3. Dispatch BLE command
    try {
      await _repository.sendAllRelaysCommand(turnOn);
    } catch (e) {
      _pendingTimers[BleConstants.allRelaysTarget]?.cancel();
      _pendingTimers.remove(BleConstants.allRelaysTarget);

      final revertList = state.relays.map((r) => r.copyWith(isPending: false)).toList();
      state = state.copyWith(
        relays: revertList,
        errorMessage: 'Failed to send ALL ${turnOn ? "ON" : "OFF"} command: $e',
      );
    }
  }

  void _handleCommandTimeout(int index) {
    _pendingTimers.remove(index);
    if (index >= 0 && index < state.relays.length) {
      final item = state.relays[index];
      if (item.isPending) {
        final updatedList = List<RelayItem>.from(state.relays);
        updatedList[index] = item.copyWith(isPending: false);
        state = state.copyWith(
          relays: updatedList,
          errorMessage: 'Relay ${index + 1} did not receive hardware confirmation within 2 seconds. Reverted.',
        );
      }
    }
  }

  void _handleAllCommandTimeout() {
    _pendingTimers.remove(BleConstants.allRelaysTarget);
    final updatedList = state.relays.map((r) => r.copyWith(isPending: false)).toList();
    state = state.copyWith(
      relays: updatedList,
      errorMessage: 'ALL command timed out without hardware confirmation. Reverted.',
    );
  }

  void _clearAllPendingTimers() {
    for (final timer in _pendingTimers.values) {
      timer.cancel();
    }
    _pendingTimers.clear();
  }

  /// Renames a relay and persists it
  Future<void> renameRelay(int index, String newName) async {
    if (index < 0 || index >= state.relays.length) return;
    await _storage.setRelayName(index, newName);

    final updated = List<RelayItem>.from(state.relays);
    updated[index] = updated[index].copyWith(name: newName);
    state = state.copyWith(relays: updated);
  }

  /// Sets an icon for a relay and persists it
  Future<void> setRelayIcon(int index, String iconKey) async {
    if (index < 0 || index >= state.relays.length) return;
    await _storage.setRelayIcon(index, iconKey);

    final updated = List<RelayItem>.from(state.relays);
    updated[index] = updated[index].copyWith(iconKey: iconKey);
    state = state.copyWith(relays: updated);
  }

  Future<void> connect(String deviceId) async {
    state = state.copyWith(clearError: true);
    try {
      await _repository.connect(deviceId);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Connection error: $e');
    }
  }

  Future<void> disconnect() async {
    _clearAllPendingTimers();
    try {
      await _repository.disconnect();
    } catch (e) {
      state = state.copyWith(errorMessage: 'Disconnect error: $e');
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final relayControllerProvider =
    NotifierProvider<RelayController, RelayDashboardState>(RelayController.new);
