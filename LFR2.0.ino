#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

// Custom UUIDs
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define COMMAND_UUID        "12345678-1234-5678-1234-56789abcdef1"
#define TELEMETRY_UUID      "12345678-1234-5678-1234-56789abcdef2"

// Global variables
bool deviceConnected = false;
BLECharacteristic* pTelemetryCharacteristic = NULL;

// Simple callback without complex string handling
class CommandCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
        // Direct C-style string handling
        // ArduinoBLE returns String; ESP32 BLE returns std::string. Using String keeps it portable here.
        String value = pCharacteristic->getValue();
        if (value.length() > 0) {
            Serial.print("Received (len=");
            Serial.print(value.length());
            Serial.print(") : ");
            Serial.println(value.c_str());
            Serial.print("HEX: ");
            for (size_t i = 0; i < value.length(); i++) {
                char hexByte[4];
                sprintf(hexByte, "%02X ", static_cast<uint8_t>(value[i]));
                Serial.print(hexByte);
            }
            Serial.println();
        } else {
            Serial.println("Received empty write");
        }
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("Starting BLE...");
    
    BLEDevice::init("ESP32_Simple");
    
    BLEServer* pServer = BLEDevice::createServer();
    
    BLEService* pService = pServer->createService(SERVICE_UUID);
    
    // Command characteristic
    BLECharacteristic* pCommandChar = pService->createCharacteristic(
        COMMAND_UUID,
        BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
    );
    pCommandChar->setCallbacks(new CommandCallbacks());
    pCommandChar->addDescriptor(new BLE2902());
    
    // Telemetry characteristic
    pTelemetryCharacteristic = pService->createCharacteristic(
        TELEMETRY_UUID,
        BLECharacteristic::PROPERTY_NOTIFY
    );
    pTelemetryCharacteristic->addDescriptor(new BLE2902());
    
    pService->start();
    
    BLEAdvertising* pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->start();
    
    Serial.println("BLE ready!");
}

void loop() {
    // Just keep running
    delay(1000);
}