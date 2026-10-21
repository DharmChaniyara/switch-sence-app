import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// State representation for user settings.
@immutable
class SettingsState {
  final ThemeMode themeMode;
  final bool autoReconnect;
  final bool isDemoMode;
  final String? lastDeviceId;
  final String? lastDeviceName;

  const SettingsState({
    required this.themeMode,
    required this.autoReconnect,
    required this.isDemoMode,
    this.lastDeviceId,
    this.lastDeviceName,
  });

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? autoReconnect,
    bool? isDemoMode,
    String? lastDeviceId,
    String? lastDeviceName,
    bool clearLastDevice = false,
  }) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      isDemoMode: isDemoMode ?? this.isDemoMode,
      lastDeviceId: clearLastDevice ? null : (lastDeviceId ?? this.lastDeviceId),
      lastDeviceName: clearLastDevice ? null : (lastDeviceName ?? this.lastDeviceName),
    );
  }
}

/// Provider for the storage service initialized at app launch.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError('storageServiceProvider must be overridden in ProviderScope');
});

/// Riverpod 3 Notifier for application settings and preferences.
class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final storage = ref.watch(storageServiceProvider);
    return SettingsState(
      themeMode: storage.getThemeMode(),
      autoReconnect: storage.getAutoReconnect(),
      isDemoMode: storage.getDemoMode(),
      lastDeviceId: storage.getLastDeviceId(),
      lastDeviceName: storage.getLastDeviceName(),
    );
  }

  StorageService get _storage => ref.read(storageServiceProvider);

  Future<void> setThemeMode(ThemeMode mode) async {
    await _storage.setThemeMode(mode);
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setAutoReconnect(bool enabled) async {
    await _storage.setAutoReconnect(enabled);
    state = state.copyWith(autoReconnect: enabled);
  }

  Future<void> setDemoMode(bool enabled) async {
    await _storage.setDemoMode(enabled);
    state = state.copyWith(isDemoMode: enabled);
  }

  Future<void> saveLastDevice({required String id, required String name}) async {
    await _storage.saveLastDevice(id: id, name: name);
    state = state.copyWith(lastDeviceId: id, lastDeviceName: name);
  }

  Future<void> forgetLastDevice() async {
    await _storage.clearLastDevice();
    state = state.copyWith(clearLastDevice: true);
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);
