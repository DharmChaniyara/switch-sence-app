/*
 * =========================================================================================
 * Project: Switch Sense - ESP32 8-Channel Relay Controller (BLE GATT Edition)
 * Board:   ESP32 DevKit V1 (30-pin / 36-pin)
 * Author:  Antigravity Senior Embedded & Flutter Engineer
 * 
 * Hardware Configuration:
 *   - 8-Channel Relay Module (Active-LOW: LOW = ON / Energized, HIGH = OFF / De-energized)
 *   - GPIO Pin Map (Relays 1 to 8): 13, 12, 14, 27, 26, 25, 33, 32
 * 
 * BLE Protocol Specification:
 *   - Service UUID:             4fafc201-1fb5-459e-8fcc-c5c9c331914b
 *   - Command Char (Write):     beb5483e-36e1-4688-b7f5-ea07361b26a8
 *   - State Char (Read+Notify): 1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e
 * 
 * Protocol Formats:
 *   1. Command (2 bytes binary):
 *      Byte 0: Relay Index (0x00 - 0x07 for Relays 1-8, 0xFF for ALL)
 *      Byte 1: Action (0x00 = OFF, 0x01 = ON)
 *      (Also supports ASCII fallback: "R1:1", "R1:0", "ALL:1", "ALL:0")
 * 
 *   2. State (1 byte bitmask):
 *      Bit i = Relay (i + 1) state (1 = ON, 0 = OFF)
 *      Bit 0: Relay 1 (GPIO 13)
 *      Bit 1: Relay 2 (GPIO 12)
 *      Bit 2: Relay 3 (GPIO 14)
 *      Bit 3: Relay 4 (GPIO 27)
 *      Bit 4: Relay 5 (GPIO 26)
 *      Bit 5: Relay 6 (GPIO 25)
 *      Bit 6: Relay 7 (GPIO 33)
 *      Bit 7: Relay 8 (GPIO 32)
 * 
 * Safety & Strapping Pin Note:
 *   GPIO 12 (MTDI) is an ESP32 strapping pin. If pulled HIGH externally during boot,
 *   the ESP32 selects 1.8V VDD_SDIO, which can cause boot crashes on standard 3.3V flash.
 *   Ensure the relay board input does not pull GPIO 12 HIGH during reset, or see README
 *   to rewire Relay 2 to GPIO 16/17 if boot failure occurs.
 * =========================================================================================
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// -----------------------------------------------------------------------------
// Compile-time Options & Configuration
// -----------------------------------------------------------------------------
#define DEVICE_NAME                "ESP32-Relay-8"
#define SERVICE_UUID               "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID_CMD    "beb5483e-36e1-4688-b7f5-ea07361b26a8"
#define CHARACTERISTIC_UUID_STATE  "1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e"

// Safety: If true, turns all relays OFF when the BLE client disconnects.
// If false (default), relays maintain their current state when client disconnects.
#define FAILSAFE_OFF_ON_DISCONNECT false

// Number of relays
#define NUM_RELAYS 8

// GPIO Pin Mapping for Relays 1 to 8 (must match hardware)
const uint8_t RELAY_PINS[NUM_RELAYS] = {13, 12, 14, 27, 26, 25, 33, 32};

// Active LOW logic definitions
#define RELAY_ACTIVE_LEVEL   LOW   // LOW energizes relay (ON)
#define RELAY_INACTIVE_LEVEL HIGH  // HIGH de-energizes relay (OFF)

// -----------------------------------------------------------------------------
// Global Variables & State
// -----------------------------------------------------------------------------
BLEServer* pServer = nullptr;
BLECharacteristic* pCmdCharacteristic = nullptr;
BLECharacteristic* pStateCharacteristic = nullptr;

bool deviceConnected = false;
bool oldDeviceConnected = false;

// 1-byte bitmask storing the state of all 8 relays. Bit i = Relay (i+1) ON.
uint8_t relayStateMask = 0x00;

// Mutex / flag to protect state updates during rapid operations
portMUX_TYPE stateMux = portMUX_INITIALIZER_UNLOCKED;

// Forward Declarations
void setRelay(uint8_t index, bool on, bool notifyClient = true);
void setAllRelays(bool on);
void notifyState();

// -----------------------------------------------------------------------------
// BLE Server Callbacks
// -----------------------------------------------------------------------------
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServerInstance) override {
    deviceConnected = true;
    Serial.println(F("[BLE] Client connected successfully."));
  }

  void onDisconnect(BLEServer* pServerInstance) override {
    deviceConnected = false;
    Serial.println(F("[BLE] Client disconnected."));

    #if FAILSAFE_OFF_ON_DISCONNECT
      Serial.println(F("[SAFETY] Failsafe triggered: turning all relays OFF."));
      setAllRelays(false);
    #else
      Serial.println(F("[SAFETY] Relays maintaining current states."));
    #endif

    // Restart advertising so subsequent connections can be made
    pServerInstance->startAdvertising();
    Serial.println(F("[BLE] Restarted advertising."));
  }
};

// -----------------------------------------------------------------------------
// BLE Command Characteristic Callbacks
// -----------------------------------------------------------------------------
class CommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* pCharacteristic) override {
    // In Arduino ESP32 BLE, getValue() returns std::string
    std::string rxValue = pCharacteristic->getValue();
    size_t len = rxValue.length();

    if (len == 0) {
      Serial.println(F("[BLE] Received empty command. Ignored."));
      return;
    }

    const uint8_t* data = reinterpret_cast<const uint8_t*>(rxValue.data());

    // 1. Binary Protocol: 2-byte payload [relayIndex, action]
    if (len == 2) {
      uint8_t target = data[0];
      uint8_t action = data[1];

      // Validate action: must be 0 (OFF) or 1 (ON)
      if (action != 0 && action != 1) {
        Serial.printf("[BLE] Invalid action value: 0x%02X. Ignored.\n", action);
        return;
      }

      bool turnOn = (action == 1);

      if (target == 0xFF) {
        // ALL Relays command
        Serial.printf("[BLE CMD] Master command: ALL %s\n", turnOn ? "ON" : "OFF");
        setAllRelays(turnOn);
      } else if (target < NUM_RELAYS) {
        // Specific Relay command (0 to 7)
        Serial.printf("[BLE CMD] Relay %u set to %s\n", target + 1, turnOn ? "ON" : "OFF");
        setRelay(target, turnOn, true);
      } else {
        Serial.printf("[BLE] Invalid relay index: 0x%02X. Ignored.\n", target);
      }
      return;
    }

    // 2. Fallback ASCII Protocol (e.g. for nRF Connect / Serial BLE terminal)
    // Examples: "R1:1", "R1:0", "ALL:1", "ALL:0"
    String asciiCmd = String(rxValue.c_str());
    asciiCmd.trim();
    asciiCmd.toUpperCase();

    if (asciiCmd.startsWith("ALL:")) {
      char val = asciiCmd.charAt(4);
      if (val == '1') {
        Serial.println(F("[BLE ASCII] Master command: ALL ON"));
        setAllRelays(true);
      } else if (val == '0') {
        Serial.println(F("[BLE ASCII] Master command: ALL OFF"));
        setAllRelays(false);
      }
      return;
    }

    if (asciiCmd.startsWith("R") && asciiCmd.length() >= 4 && asciiCmd.charAt(2) == ':') {
      int rNum = asciiCmd.charAt(1) - '0';
      char val = asciiCmd.charAt(3);
      if (rNum >= 1 && rNum <= NUM_RELAYS && (val == '0' || val == '1')) {
        uint8_t index = (uint8_t)(rNum - 1);
        bool turnOn = (val == '1');
        Serial.printf("[BLE ASCII] Relay %d set to %s\n", rNum, turnOn ? "ON" : "OFF");
        setRelay(index, turnOn, true);
        return;
      }
    }

    Serial.printf("[BLE] Unrecognized command (length %u): %s. Ignored.\n", len, rxValue.c_str());
  }
};

// -----------------------------------------------------------------------------
// Relay Control Implementation
// -----------------------------------------------------------------------------

/**
 * @brief Sets a single relay state and updates bitmask.
 * @param index 0-indexed relay index (0 to 7 for Relays 1 to 8)
 * @param on true to energize relay (ON), false to de-energize (OFF)
 * @param notifyClient whether to trigger BLE GATT notification
 */
void setRelay(uint8_t index, bool on, bool notifyClient) {
  if (index >= NUM_RELAYS) return;

  uint8_t pin = RELAY_PINS[index];

  // Hardware GPIO write (Active LOW: LOW = ON, HIGH = OFF)
  digitalWrite(pin, on ? RELAY_ACTIVE_LEVEL : RELAY_INACTIVE_LEVEL);

  // Update in-memory state bitmask under spinlock
  portENTER_CRITICAL(&stateMux);
  if (on) {
    relayStateMask |= (1 << index);
  } else {
    relayStateMask &= ~(1 << index);
  }
  portEXIT_CRITICAL(&stateMux);

  Serial.printf("[RELAY] Relay #%u (GPIO %u) -> %s | Mask: 0x%02X\n",
                index + 1, pin, on ? "ON (Energized)" : "OFF (Open)", relayStateMask);

  if (notifyClient) {
    notifyState();
  }
}

/**
 * @brief Sets all 8 relays to the specified state in a single operation.
 * @param on true for all ON, false for all OFF
 */
void setAllRelays(bool on) {
  for (uint8_t i = 0; i < NUM_RELAYS; i++) {
    // Write GPIO directly without notifying individually
    digitalWrite(RELAY_PINS[i], on ? RELAY_ACTIVE_LEVEL : RELAY_INACTIVE_LEVEL);
  }

  portENTER_CRITICAL(&stateMux);
  relayStateMask = on ? 0xFF : 0x00;
  portEXIT_CRITICAL(&stateMux);

  Serial.printf("[RELAY] ALL Relays set to %s | Mask: 0x%02X\n",
                on ? "ON" : "OFF", relayStateMask);

  // Notify client with the single updated bitmask byte
  notifyState();
}

/**
 * @brief Sets the State characteristic value and sends BLE notification to connected client.
 */
void notifyState() {
  if (pStateCharacteristic == nullptr) return;

  uint8_t currentMask;
  portENTER_CRITICAL(&stateMux);
  currentMask = relayStateMask;
  portEXIT_CRITICAL(&stateMux);

  pStateCharacteristic->setValue(&currentMask, 1);

  if (deviceConnected) {
    pStateCharacteristic->notify();
    Serial.printf("[BLE] State notified: 0x%02X\n", currentMask);
  }
}

// -----------------------------------------------------------------------------
// Arduino Setup & Loop
// -----------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println(F("\n========================================================"));
  Serial.println(F("    Switch Sense - ESP32 8-Channel Relay BLE Controller "));
  Serial.println(F("========================================================"));

  // 1. Safe boot sequence: All relays must be OFF at boot
  // CRITICAL: Write HIGH before setting pinMode to OUTPUT to prevent momentary clicks
  Serial.println(F("[BOOT] Initializing Relay GPIOs in SAFE OFF state..."));
  for (uint8_t i = 0; i < NUM_RELAYS; i++) {
    uint8_t pin = RELAY_PINS[i];
    digitalWrite(pin, RELAY_INACTIVE_LEVEL); // Preset pin HIGH (inactive)
    pinMode(pin, OUTPUT);                    // Set output mode
    digitalWrite(pin, RELAY_INACTIVE_LEVEL); // Ensure still HIGH
    Serial.printf("[BOOT] Relay #%u on GPIO %u -> Initialized OFF\n", i + 1, pin);
  }
  relayStateMask = 0x00;

  // 2. Initialize BLE Subsystem
  Serial.println(F("[BLE] Initializing BLE stack..."));
  BLEDevice::init(DEVICE_NAME);

  // Create BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  // Create Custom GATT Service
  BLEService* pService = pServer->createService(SERVICE_UUID);

  // Create Command Characteristic (Write & Write Without Response)
  pCmdCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_CMD,
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_WRITE_NR
  );
  pCmdCharacteristic->setCallbacks(new CommandCallbacks());

  // Create State Characteristic (Read & Notify)
  pStateCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID_STATE,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_NOTIFY
  );

  // Attach BLE2902 Client Characteristic Configuration Descriptor for Notifications
  pStateCharacteristic->addDescriptor(new BLE2902());

  // Set initial characteristic value (0x00 = all OFF)
  uint8_t initialVal = 0x00;
  pStateCharacteristic->setValue(&initialVal, 1);

  // Start the GATT Service
  pService->start();
  Serial.println(F("[BLE] GATT Service started."));

  // 3. Configure Advertising
  BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06); // Functions that help with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);

  BLEDevice::startAdvertising();
  Serial.println(F("[BLE] Advertising started as: " DEVICE_NAME));
  Serial.println(F("[READY] System initialized and waiting for BLE connection.\n"));
}

void loop() {
  // Connection state transition handling & watchdog logging
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // Allow BLE stack to finalize
    pServer->startAdvertising();
    Serial.println(F("[BLE] Auto-restarted advertising after disconnect."));
    oldDeviceConnected = deviceConnected;
  }

  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
    // Client connected: make sure current state is synced to characteristic
    notifyState();
  }

  delay(20); // Low-power loop pacing
}
