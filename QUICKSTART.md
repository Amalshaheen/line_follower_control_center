# Flutter BLE App - Quick Start Guide

## What's Been Built

A complete Flutter BLE application with:
- **Device Scanner**: Scan and discover nearby BLE devices
- **Connection Manager**: Connect/disconnect from devices
- **Data Communication**: Read, write, and subscribe to characteristics
- **UI**: Material Design 3 with light/dark theme support

## File Structure

```
lib/
├── main.dart                       # App entry with Provider setup
├── models/
│   └── ble_device_model.dart       # Device, Service, Characteristic models
├── providers/
│   └── ble_provider.dart           # State management with ChangeNotifier
├── screens/
│   ├── device_scan_screen.dart     # Scan & list devices
│   └── device_detail_screen.dart   # Communicate with connected device
└── services/
    └── ble_service.dart            # BLE operations wrapper
```

## Key Features Implemented

### 1. BLE Service Layer (`services/ble_service.dart`)
- Singleton pattern for BLE operations
- Scan management with timeout
- Connection/disconnection handling
- Service discovery
- Read/Write characteristics
- Subscribe/Unsubscribe to notifications
- RSSI reading
- Error handling

### 2. State Management (`providers/ble_provider.dart`)
- Global BLE state using Provider
- Adapter state monitoring
- Scan results management
- Connection state tracking
- Characteristic subscriptions
- Error state handling

### 3. UI Screens

#### Device Scan Screen
- Bluetooth status indicator
- Scan controls (start/stop)
- Device list with:
  - Device name & ID
  - Signal strength (color-coded)
  - Connection status
- Permission handling
- Pull-to-refresh

#### Device Detail Screen
- Device info card
- Service & characteristic explorer
- Property indicators (READ, WRITE, NOTIFY, INDICATE)
- Message communication area
- Text/HEX mode toggle
- Send/receive functionality
- Notification subscriptions

## How to Use

### 1. First Run
```bash
cd "/home/amal-shaheen/Documents/flutter/line follow app/line_follower_control_center"
flutter pub get
flutter run
```

### 2. Testing with ESP32

Use this minimal ESP32 code:

```cpp
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLECharacteristic *pCharacteristic;

void setup() {
  Serial.begin(115200);
  BLEDevice::init("ESP32-LineFollower");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService(SERVICE_UUID);
  
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ |
    BLECharacteristic::PROPERTY_WRITE |
    BLECharacteristic::PROPERTY_NOTIFY
  );
  
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();
  BLEDevice::getAdvertising()->start();
  Serial.println("BLE Started!");
}

void loop() {
  delay(1000);
}
```

### 3. Communication Protocol

The app supports:
- **Text messages**: UTF-8 encoded strings
- **HEX data**: Byte arrays for custom protocols
- **Notifications**: Real-time data streaming

Example data formats:
```
Text: "SPEED:100"
Hex:  53 50 45 45 44 3A 31 30 30
```

## Next Steps

### For Line Follower Robot:

1. **Define your BLE protocol**:
```cpp
// Example protocol
// Command format: CMD:VALUE\n
// Commands:
// - SPEED:0-255
// - PID:P,I,D
// - MODE:AUTO/MANUAL
// - STATUS? (query)
```

2. **Implement ESP32 handlers**:
```cpp
void onWrite(BLECharacteristic *pCharacteristic) {
  String cmd = pCharacteristic->getValue().c_str();
  if (cmd.startsWith("SPEED:")) {
    int speed = cmd.substring(6).toInt();
    setMotorSpeed(speed);
  }
}
```

3. **Send telemetry**:
```cpp
void loop() {
  String data = String(currentSpeed) + "," + 
                String(sensorValue) + "\n";
  pCharacteristic->setValue(data.c_str());
  pCharacteristic->notify();
  delay(100);
}
```

### For Flutter App Extensions:

1. **Add custom screens** for your robot:
   - Control panel (speed, direction)
   - PID tuning interface
   - Sensor visualization
   - Path tracking

2. **Extend BleProvider**:
```dart
// Add robot-specific methods
Future<void> setSpeed(int speed) async {
  String cmd = "SPEED:$speed";
  await writeCharacteristic(
    selectedCharacteristic!,
    utf8.encode(cmd),
  );
}
```

3. **Parse telemetry data**:
```dart
void _parseTelemetry(List<int> data) {
  String message = String.fromCharCodes(data);
  List<String> values = message.split(',');
  // Update UI with parsed values
}
```

## Permissions

All required permissions are configured:

**Android** (`AndroidManifest.xml`):
- ✅ BLUETOOTH_SCAN (Android 12+)
- ✅ BLUETOOTH_CONNECT (Android 12+)
- ✅ ACCESS_FINE_LOCATION (legacy)

**iOS** (`Info.plist`):
- ✅ NSBluetoothAlwaysUsageDescription

## Testing Checklist

- [ ] App builds without errors
- [ ] Bluetooth permissions granted
- [ ] Can scan for devices
- [ ] Can connect to ESP32
- [ ] Services discovered correctly
- [ ] Can read characteristics
- [ ] Can write characteristics
- [ ] Notifications working
- [ ] Disconnection handled properly

## Common Issues

### "No devices found"
- Ensure ESP32 is advertising
- Check Bluetooth is ON
- Grant location permissions (Android)

### "Connection failed"
- ESP32 may be connected elsewhere
- Restart ESP32
- Move closer to device

### "Cannot write"
- Verify characteristic has WRITE property
- Check connection is active
- Validate data format

## Resources

- Full README: See `README.md` in project root
- Flutter Blue Plus docs: https://github.com/chipweinberger/flutter_blue_plus
- ESP32 BLE examples: https://github.com/nkolban/ESP32_BLE_Arduino

---

**Status**: ✅ All files created, no compilation errors, ready to run!
