# Line Follower Control Center - BLE App

A Flutter application for connecting to ESP32 and other Bluetooth Low Energy (BLE) devices. This app allows you to scan, connect, and communicate with BLE devices.

## Features

✅ **BLE Device Scanner**
- Scan for nearby Bluetooth LE devices
- Display device name, ID, and signal strength (RSSI)
- Filter devices by signal quality
- Real-time device discovery

✅ **Device Connection**
- Connect to ESP32 and other BLE devices
- Auto-discovery of services and characteristics
- Connection state monitoring
- Signal strength indicator

✅ **Data Communication**
- Read from BLE characteristics
- Write data to characteristics
- Subscribe to notifications/indications
- Support for both text and HEX formats
- Real-time message display

✅ **Service & Characteristic Explorer**
- Browse all available services
- View characteristic properties (READ, WRITE, NOTIFY, INDICATE)
- Interactive UI for characteristic operations

## Prerequisites

- Flutter SDK (3.10.1 or higher)
- Android SDK (for Android development)
- Xcode (for iOS development)
- Physical device (BLE doesn't work well on emulators)

## Dependencies

- `flutter_blue_plus: ^1.19.7` - BLE communication
- `provider: ^6.1.2` - State management
- `permission_handler: ^11.3.1` - Permission handling
- `fl_chart: ^0.68.0` - Charts and visualizations

## Installation

1. **Install dependencies**
```bash
flutter pub get
```

2. **Run the app**
```bash
flutter run
```

## Platform-Specific Setup

### Android

The app requires Bluetooth permissions configured in `android/app/src/main/AndroidManifest.xml`:
- `BLUETOOTH_SCAN` - For Android 12+
- `BLUETOOTH_CONNECT` - For Android 12+
- `ACCESS_FINE_LOCATION` - For older Android versions

### iOS

Bluetooth usage description is configured in `ios/Runner/Info.plist`:
```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Bluetooth is used to connect and control devices.</string>
```

## Usage Guide

### 1. Scanning for Devices
1. Launch the app
2. Grant Bluetooth and location permissions
3. Tap **Scan** to search for devices
4. Devices appear with name, ID, and signal strength

### 2. Connecting to a Device
1. Tap on a device from the list
2. Wait for connection
3. Services and characteristics are automatically discovered

### 3. Communicating
- **Read**: Tap download icon on readable characteristics
- **Write**: Select characteristic, enter text/hex, tap send
- **Notify**: Tap bell icon to subscribe to notifications

### 4. Message Formats
- **Text Mode**: UTF-8 strings
- **HEX Mode**: Hexadecimal bytes (e.g., `0A1B2C`)

## ESP32 Integration

Sample ESP32 BLE code:

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
  
  BLEDevice::init("ESP32-Device");
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
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  BLEDevice::startAdvertising();
  
  Serial.println("BLE ready!");
}

void loop() {
  // Send notifications, handle data
  delay(2000);
}
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── ble_device_model.dart    # Data models
├── providers/
│   └── ble_provider.dart        # State management
├── screens/
│   ├── device_scan_screen.dart  # Scanning UI
│   └── device_detail_screen.dart # Communication UI
└── services/
    └── ble_service.dart         # BLE operations
```

## Troubleshooting

### Bluetooth not working
- Enable Bluetooth on device
- Grant all permissions
- Use physical device

### Cannot find devices
- Ensure ESP32 is advertising
- Enable location services (Android)
- Move closer to device

### Connection fails
- Restart devices
- Unpair from system Bluetooth settings
- Check device availability

## Signal Strength Guide
- 🟢 **> -50 dBm**: Excellent
- 🟠 **> -70 dBm**: Good  
- 🔴 **< -70 dBm**: Weak

## Resources
- [Flutter Blue Plus](https://github.com/chipweinberger/flutter_blue_plus)
- [ESP32 BLE Arduino](https://github.com/nkolban/ESP32_BLE_Arduino)

---

Built with Flutter 💙
	- `flutter pub get`
	- `flutter run`

## Hooking up to a real robot
- The app now scans/ connects via BLE using the Nordic UART Service (NUS) UUIDs (`6E400001-...`). TX= `6E400002-...` (app → robot), RX=`6E400003-...` (robot → app, notifications enabled).
- Commands sent from the app:
	- `PID:p,i,d\n` (floats with 3 decimals)
	- `SPD:value\n`
- Telemetry parsing supports JSON (`{"speed":0.5,"error":0.01,"lineLost":false}`) or CSV (`0.5,0.01,0`).
- Update UUIDs or payload formatting in `BluetoothRobotTransport` if your firmware uses a different protocol.

## Structure
- `lib/main.dart`: UI, view model, and mock transport.
