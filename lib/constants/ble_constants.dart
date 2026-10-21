/// BLE protocol constants and codecs for Switch Sense ESP32 8-Channel Relay Controller.
class BleConstants {
  BleConstants._();

  /// 128-bit Custom GATT Service UUID (matches ESP32 firmware)
  static const String serviceUuid = '6e8f0001-b5a3-f393-e0a9-e50e24dcca9e';

  /// Characteristic for App -> ESP32 Commands (Write / Write Without Response)
  static const String commandCharUuid = '6e8f0002-b5a3-f393-e0a9-e50e24dcca9e';

  /// Characteristic for ESP32 -> App Relay State (Read + Notify)
  static const String stateCharUuid = '6e8f0003-b5a3-f393-e0a9-e50e24dcca9e';

  /// Default advertised device name
  static const String defaultDeviceName = 'ESP32-Relay-8';

  /// Total number of relays on hardware
  static const int totalRelays = 8;

  /// Hardware GPIO pin mapping in order of Relay 1 through 8
  static const List<int> relayGpioPins = [13, 12, 14, 27, 26, 25, 33, 32];

  /// Special target index indicating ALL relays
  static const int allRelaysTarget = 0xFF;

  /// Protocol command actions
  static const int actionOff = 0x00;
  static const int actionOn = 0x01;

  /// Time after which an unconfirmed command reverts and signals a timeout error
  static const Duration commandTimeout = Duration(seconds: 2);

  /// Scan duration
  static const Duration scanTimeout = Duration(seconds: 10);

  /// Connection timeout
  static const Duration connectTimeout = Duration(seconds: 15);

  /// Encodes a single relay command into the 2-byte binary payload: `[relayIndex, action]`.
  /// [relayIndex] must be between 0 and 7.
  static List<int> encodeRelayCommand(int relayIndex, bool turnOn) {
    assert(relayIndex >= 0 && relayIndex < totalRelays, 'Relay index must be 0-7');
    return [relayIndex, turnOn ? actionOn : actionOff];
  }

  /// Encodes an ALL-relay command into the 2-byte binary payload: `[0xFF, action]`.
  static List<int> encodeAllCommand(bool turnOn) {
    return [allRelaysTarget, turnOn ? actionOn : actionOff];
  }

  /// Decodes a 1-byte bitmask into an 8-element `List<bool>`.
  /// Bit i (0-7) represents Relay (i + 1), where 1 = ON, 0 = OFF.
  static List<bool> decodeStateBitmask(int bitmask) {
    final states = List<bool>.filled(totalRelays, false);
    for (int i = 0; i < totalRelays; i++) {
      states[i] = (bitmask & (1 << i)) != 0;
    }
    return states;
  }

  /// Encodes an 8-element `List<bool>` into a 1-byte bitmask.
  static int encodeStateBitmask(List<bool> states) {
    int mask = 0;
    for (int i = 0; i < states.length && i < totalRelays; i++) {
      if (states[i]) {
        mask |= (1 << i);
      }
    }
    return mask;
  }
}
