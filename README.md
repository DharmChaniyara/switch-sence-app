# Switch Sense - ESP32 BLE 8-Channel Relay Controller

A production-grade, direct Bluetooth Low Energy (BLE) smart switch solution for controlling an 8-channel relay board from iOS and Android devices without requiring Wi-Fi, local network routers, or internet connectivity.

---

## 1. System Overview & Architecture

```
┌─────────────────────────────────┐                 ┌─────────────────────────────────┐
│     Flutter Mobile App          │                 │        ESP32 DevKit V1          │
│   (Android 5.0+ & iOS 12.0+)    │                 │   (GATT Server, 115200 Baud)    │
├─────────────────────────────────┤                 ├─────────────────────────────────┤
│ • Presentation: Material 3 UI   │                 │ • BLE GATT Peripheral Stack     │
│   - Responsive Grid (2-4 cols)  │   Write Cmd     │ • Active-LOW GPIO Driver        │
│   - Relay Cards + Custom Names  │ ──────────────> │ • Boot Safety Preset (OFF)      │
│   - Master ALL ON / ALL OFF     │  [Index, State] │ • In-Memory Bitmask State       │
│ • State: Riverpod 3 Notifiers   │                 │ • Configurable Failsafe         │
│ • Data: BleRelayRepository      │ <────────────── │ • Non-blocking loop pacing      │
│ • Persistence: SharedPreferences│   Notify State  │ • Strapping Pin Guard (GPIO 12) │
│ • Demo Mode: MockRelayRepository│  [1-byte mask]  │                                 │
└─────────────────────────────────┘                 └─────────────────────────────────┘
                                                                     │
                                                      8 GPIO Lines   │ (Active-LOW)
                                                      (13,12,14,27,  │
                                                       26,25,33,32)  ▼
                                                    ┌─────────────────────────────────┐
                                                    │   8-Channel Relay Module        │
                                                    │   - Optocoupler Isolation       │
                                                    │   - External 5V Coil Supply     │
                                                    │   - Common Ground Link          │
                                                    └─────────────────────────────────┘
```

---

## 2. BLE GATT Protocol Specification

The app and firmware communicate over a single custom 128-bit GATT Service using two characteristics:

| Parameter / Entity | Value | Properties | Description |
| :--- | :--- | :--- | :--- |
| **Service UUID** | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` | Primary Service | Filtered by app during BLE scanning. |
| **Command Characteristic** | `beb5483e-36e1-4688-b7f5-ea07361b26a8` | `WRITE`, `WRITE_NR` | App dispatches 2-byte binary control payloads. |
| **State Characteristic** | `1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e` | `READ`, `NOTIFY` | Read on connect; notifies after every change. Attached to BLE2902 descriptor. |
| **Advertised Name** | `ESP32-Relay-8` | Complete Local Name | Included in BLE advertising packets along with service UUID. |

### Command Payload Format (App ➔ ESP32)
Commands are compact, 2-byte binary arrays: `[Byte 0: target, Byte 1: action]`

- **Byte 0 (Target Index)**:
  - `0x00`: Relay 1 (GPIO 13)
  - `0x01`: Relay 2 (GPIO 12)
  - `0x02`: Relay 3 (GPIO 14)
  - `0x03`: Relay 4 (GPIO 27)
  - `0x04`: Relay 5 (GPIO 26)
  - `0x05`: Relay 6 (GPIO 25)
  - `0x06`: Relay 7 (GPIO 33)
  - `0x07`: Relay 8 (GPIO 32)
  - `0xFF`: Master Command (ALL 8 Relays)
- **Byte 1 (Action)**:
  - `0x00`: Turn OFF (De-energize coil, relay contact open)
  - `0x01`: Turn ON (Energize coil, relay contact closed)

*Fallback ASCII Support:* For manual terminal debugging (e.g. Serial Bluetooth terminal / nRF Connect), ASCII strings `R1:1`, `R1:0`, `ALL:1`, `ALL:0` are accepted and strictly validated without crashing.

### State Bitmask Format (ESP32 ➔ App)
The state of all 8 relays is packed into a **single 1-byte bitmask** notified after every change and readable immediately upon connection:

```
Bit 7: Relay 8 (GPIO 32) -> 1 = ON, 0 = OFF
Bit 6: Relay 7 (GPIO 33) -> 1 = ON, 0 = OFF
Bit 5: Relay 6 (GPIO 25) -> 1 = ON, 0 = OFF
Bit 4: Relay 5 (GPIO 26) -> 1 = ON, 0 = OFF
Bit 3: Relay 4 (GPIO 27) -> 1 = ON, 0 = OFF
Bit 2: Relay 3 (GPIO 14) -> 1 = ON, 0 = OFF
Bit 1: Relay 2 (GPIO 12) -> 1 = ON, 0 = OFF
Bit 0: Relay 1 (GPIO 13) -> 1 = ON, 0 = OFF
```

*Example:* `0x05` (`0b00000101`) indicates Relay 1 and Relay 3 are ON; all others are OFF.

---

## 3. Hardware Wiring, Power & Safety Notes

### GPIO Pin Mapping
| Relay Channel | ESP32 GPIO | Logic Level for ON | Logic Level for OFF | Hardware Boot Note |
| :---: | :---: | :---: | :---: | :--- |
| **Relay 1** | **GPIO 13** | LOW (0V) | HIGH (3.3V) | Safe general purpose I/O |
| **Relay 2** | **GPIO 12** | LOW (0V) | HIGH (3.3V) | **⚠️ Strapping pin (MTDI)** - see below |
| **Relay 3** | **GPIO 14** | LOW (0V) | HIGH (3.3V) | Safe general purpose I/O |
| **Relay 4** | **GPIO 27** | LOW (0V) | HIGH (3.3V) | Safe general purpose I/O |
| **Relay 5** | **GPIO 26** | LOW (0V) | HIGH (3.3V) | Safe general purpose I/O |
| **Relay 6** | **GPIO 25** | LOW (0V) | HIGH (3.3V) | Safe general purpose I/O |
| **Relay 7** | **GPIO 33** | LOW (0V) | HIGH (3.3V) | Safe general purpose I/O |
| **Relay 8** | **GPIO 32** | LOW (0V) | HIGH (3.3V) | Safe general purpose I/O |

### ⚠️ Critical Strapping Pin Warning (GPIO 12 / MTDI)
- **The Issue**: GPIO 12 is an internal strapping pin on the ESP32. At boot/reset, the ESP32 samples GPIO 12 to determine the flash memory voltage (VDD_SDIO). If GPIO 12 is pulled **HIGH** at boot, the ESP32 selects **1.8V** flash voltage instead of standard **3.3V**, resulting in a boot-loop crash (`flash read err, 1000`).
- **The Cause**: Many active-LOW relay modules have an on-board pull-up resistor or optocoupler circuit that pulls input pins HIGH when inactive.
- **Recommended Actions**:
  1. **Option A (Safe Wiring)**: Ensure the relay module input does not hold GPIO 12 high during boot, or use an external pull-down resistor (10kΩ to GND).
  2. **Option B (Permanent eFuse fix)**: Permanently lock the ESP32 internal flash voltage to 3.3V using the official Espressif tool:
     ```bash
     espefuse.py --port COMx set_flash_voltage 3.3V
     ```
  3. **Option C (Alternative Pin)**: If boot issues occur on your specific relay board, remap Relay 2 to **GPIO 16** or **GPIO 17** in `RELAY_PINS` in `esp32_relay_ble.ino` and `ble_constants.dart`.

### Relay Power Supply & Optocoupler Isolation
- **Coil Power Requirements**: Energizing 8 mechanical relays simultaneously draws approximately **500mA - 600mA at 5V** (approx. 70mA per coil).
- **CRITICAL**: **DO NOT** power the relay coils directly from the ESP32's 3.3V pin or VIN pin when powered solely by a USB port. Inrush current and inductive kickback will cause brownout resets.
- **Wiring with Optocoupler Jumper (VCC - JD-VCC)**:
  1. Remove the yellow jumper between `VCC` and `JD-VCC` on the 8-channel relay board.
  2. Connect a dedicated **5V 2A external DC power adapter** to `JD-VCC` (+) and `GND` (-) of the relay board.
  3. Connect the ESP32 `3.3V` (or `VIN`) to the relay board `VCC` pin (powers the optocoupler LEDs).
  4. Connect the ESP32 `GND` to the relay board `GND` (common reference).
  5. Connect ESP32 GPIOs 13, 12, 14, 27, 26, 25, 33, 32 to Relay IN1 through IN8.

### Boot Safety (Active-LOW Glitch Prevention)
The firmware executes safe initialization in `setup()`:
```cpp
for (uint8_t i = 0; i < NUM_RELAYS; i++) {
  uint8_t pin = RELAY_PINS[i];
  digitalWrite(pin, HIGH); // Preset HIGH BEFORE setting pinMode
  pinMode(pin, OUTPUT);
  digitalWrite(pin, HIGH); // Confirm HIGH
}
```
This guarantees relays never glitch or momentarily energize during controller boot or reset.

### Disconnect Failsafe
Defined in firmware via `#define FAILSAFE_OFF_ON_DISCONNECT false`:
- **`false` (Default)**: Relays maintain their active states if the phone disconnects or moves out of range (appliances/lights stay ON).
- **`true`**: Automatically de-energizes all relays to OFF immediately upon client disconnect.

---

## 4. Setup & Flashing Instructions

### Flashing the ESP32 Firmware
1. Open the Arduino IDE (v2.x recommended).
2. Install the **ESP32 by Espressif Systems** board package:
   - Go to `Settings` -> `Additional Boards Manager URLs` -> add `https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json`.
   - Go to `Tools` -> `Board` -> `Boards Manager` -> search `esp32` -> click **Install**.
3. Open `firmware/esp32_relay_ble/esp32_relay_ble.ino`.
4. In `Tools` menu:
   - **Board**: `DOIT ESP32 DEVKIT V1` (or `ESP32 Dev Module`).
   - **Upload Speed**: `921600` (or `115200`).
   - **Port**: Select the COM port of your connected ESP32.
5. Click **Upload**.
6. Open the Serial Monitor at **115200 baud** to verify initial boot output:
   ```
   ========================================================
       Switch Sense - ESP32 8-Channel Relay BLE Controller 
   ========================================================
   [BOOT] Initializing Relay GPIOs in SAFE OFF state...
   [BOOT] Relay #1 on GPIO 13 -> Initialized OFF
   ...
   [BLE] Advertising started as: ESP32-Relay-8
   [READY] System initialized and waiting for BLE connection.
   ```

---

## 5. Mobile App Setup & Execution

### Prerequisites
- Flutter SDK (v3.13+ or higher)
- Android SDK (minSdk 21+) or Xcode (for iOS)

### Installation & Run
```bash
# 1. Clone or navigate to the project directory
cd "switch sence app"

# 2. Fetch dependencies
flutter pub get

# 3. Analyze codebase (verified clean: 0 warnings, 0 errors)
flutter analyze

# 4. Run automated test suite (14/14 tests passing)
flutter test

# 5. Run on connected phone or emulator
flutter run

# 6. Build production APK
flutter build apk --release
```

---

## 6. Testing & Quality Verification

### Test Suite Execution Results
The automated test suite verifies all codecs, state machines, and widget interactions:

```powershell
flutter test
```
**Output:**
```
00:00 +0: BLE Protocol Codec Unit Tests: encodeRelayCommand generates exact 2-byte payload
00:00 +1: BLE Protocol Codec Unit Tests: encodeAllCommand generates exact 2-byte master payload
00:00 +2: BLE Protocol Codec Unit Tests: decodeStateBitmask correctly maps 1-byte bitmask
00:00 +3: BLE Protocol Codec Unit Tests: State bitmask round-trip preserves all 256 combinations
00:00 +4: MockRelayRepository Lifecycle: Initial state is disconnected
00:00 +5: MockRelayRepository Lifecycle: startScan emits mock peripherals
00:00 +6: MockRelayRepository Lifecycle: connect sets status and emits initial safe state
00:00 +7: MockRelayRepository Lifecycle: sendRelayCommand fires GATT notification stream
00:00 +8: MockRelayRepository Lifecycle: sendAllRelaysCommand updates all 8 channels
00:00 +9: MockRelayRepository Lifecycle: disconnect resets status
00:00 +10: ControlScreen Widget Tests: Renders all 8 relay channels with correct GPIO mappings
00:01 +11: ScanScreen Widget Tests: Scans and discovers ESP32-Relay-8 with Connect button
00:01 +12: ControlScreen Widget Tests: Tapping ALL ON opens safety confirmation dialog
00:01 +13: ControlScreen Widget Tests: Tapping single relay switch sends command and updates UI
00:01 +14: All tests passed!
```

### Static Analysis Results
```powershell
flutter analyze
```
**Output:**
```
Analyzing switch sence app...
No issues found! (ran in 9.8s)
```

---

## 7. Interactive Demo Mode

For testing the complete UI and state lifecycle without physical ESP32 hardware:
1. Open the app and tap **Continue in Demo Mode (Without Hardware)** on the splash screen, or enable **Demo / Simulation Mode** in Settings.
2. The app swaps the BLE service with `MockRelayRepository`, simulating:
   - Discovery of `ESP32-Relay-8`
   - GATT connection lifecycle
   - State notifications
   - Debounce and round-trip toggling for all 8 relays
   - Master ALL ON / ALL OFF

---

## 8. Physical Hardware Verification Checklist

Use this checklist when testing against real hardware:
- [ ] **Power-Up Check**: ESP32 red power LED is on; Relay board coils powered from 5V external adapter.
- [ ] **Boot State**: Verify all 8 relay indicator LEDs remain OFF when ESP32 powers on or resets (no click sounds).
- [ ] **Scan & Discovery**: Open Switch Sense app; verify `ESP32-Relay-8` appears in list with RSSI value.
- [ ] **Connection**: Tap "Connect"; verify Serial Monitor logs `[BLE] Client connected successfully` and app opens the control dashboard.
- [ ] **Initial State Sync**: Verify all 8 cards reflect "OFF" in the app matching physical relay contacts.
- [ ] **Individual Channel Test**:
  - Tap Relay 1 -> Physical relay 1 clicks, LED turns ON; app card illuminates "ON" upon notification.
  - Test channels 2 through 8 in sequence.
- [ ] **Master ALL ON**: Tap "ALL ON" -> Confirmation dialog appears -> Confirm -> All 8 relays click ON simultaneously.
- [ ] **Master ALL OFF**: Tap "ALL OFF" -> All 8 relays click OFF simultaneously.
- [ ] **Customization**: Tap edit icon on Relay 1 -> Change name to "Living Room AC" and pick the AC icon -> Verify change persists across app restarts.
- [ ] **Disconnect & Auto-Reconnect**:
  - Close app or tap Disconnect.
  - Re-open app -> App automatically connects to the saved ESP32 board and syncs current relay states.
- [ ] **Out-of-Range Recovery**: Walk out of BLE range; verify app displays "ESP32 disconnected" banner without crashing, and reconnects once back in range.

---

## 9. Security & Production Hardening

- **Current Scope**: Open BLE GATT connection with unique 128-bit service UUID and recognized local name.
- **Recommended Next Steps for Production Deployment**:
  1. **BLE Bonding & Pairing**: Configure `BLESecurity` with passkey (PIN) authentication (`ESP_LE_AUTH_REQ_SC_MITM_BOND`).
  2. **Encrypted Characteristics**: Add `BLECharacteristic::PROPERTY_WRITE_ENC` to require authenticated pairing before dispatching relay toggles.
