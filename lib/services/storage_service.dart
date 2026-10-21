import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles persistence of user customizations and connection preferences.
class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static const String _keyPrefixRelayName = 'relay_name_';
  static const String _keyPrefixRelayIcon = 'relay_icon_';
  static const String _keyLastDeviceId = 'last_device_id';
  static const String _keyLastDeviceName = 'last_device_name';
  static const String _keyThemeMode = 'app_theme_mode';
  static const String _keyAutoReconnect = 'auto_reconnect';
  static const String _keyDemoMode = 'demo_mode_enabled';

  /// Factory constructor to initialize with SharedPreferences instance
  static Future<StorageService> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // --- Relay Names ---

  String getRelayName(int index, {String fallback = ''}) {
    return _prefs.getString('$_keyPrefixRelayName$index') ?? fallback;
  }

  Future<bool> setRelayName(int index, String name) {
    return _prefs.setString('$_keyPrefixRelayName$index', name.trim());
  }

  // --- Relay Icons ---

  String getRelayIcon(int index, {String fallback = 'power'}) {
    return _prefs.getString('$_keyPrefixRelayIcon$index') ?? fallback;
  }

  Future<bool> setRelayIcon(int index, String iconKey) {
    return _prefs.setString('$_keyPrefixRelayIcon$index', iconKey);
  }

  // --- Last Connected Device ---

  String? getLastDeviceId() {
    return _prefs.getString(_keyLastDeviceId);
  }

  String? getLastDeviceName() {
    return _prefs.getString(_keyLastDeviceName);
  }

  Future<void> saveLastDevice({required String id, required String name}) async {
    await _prefs.setString(_keyLastDeviceId, id);
    await _prefs.setString(_keyLastDeviceName, name);
  }

  Future<void> clearLastDevice() async {
    await _prefs.remove(_keyLastDeviceId);
    await _prefs.remove(_keyLastDeviceName);
  }

  // --- Theme Mode ---

  ThemeMode getThemeMode() {
    final saved = _prefs.getString(_keyThemeMode);
    switch (saved) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<bool> setThemeMode(ThemeMode mode) {
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
    }
    return _prefs.setString(_keyThemeMode, value);
  }

  // --- Auto Reconnect ---

  bool getAutoReconnect() {
    return _prefs.getBool(_keyAutoReconnect) ?? true;
  }

  Future<bool> setAutoReconnect(bool enabled) {
    return _prefs.setBool(_keyAutoReconnect, enabled);
  }

  // --- Demo / Mock Mode ---

  bool getDemoMode() {
    return _prefs.getBool(_keyDemoMode) ?? false;
  }

  Future<bool> setDemoMode(bool enabled) {
    return _prefs.setBool(_keyDemoMode, enabled);
  }
}
