#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h>

// Custom UUIDs
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define COMMAND_UUID        "12345678-1234-5678-1234-56789abcdef1"
#define TELEMETRY_UUID      "12345678-1234-5678-1234-56789abcdef2"

// --- PIN DEFINITIONS ---
#define S0 16
#define S1 5
#define S2 18
#define S3 19
#define MUX_SIG 34

// Motor Pins
const int AIN1 = 13, AIN2 = 14, PWMA = 26;
const int BIN1 = 12, BIN2 = 27, PWMB = 25;
const int STBY = 33;

// Button Pins
const int BTN_TOGGLE = 4;    // Mode Toggle (ON/OFF)
const int BTN_CALIBRATE = 15; // Calibration trigger

// Global variables
bool deviceConnected = false;
BLECharacteristic* pTelemetryCharacteristic = NULL;

// --- CONSTANTS & VARIABLES ---
int THRESHOLD = 2000;
int SENSOR_COUNT = 12;
int BASE_SPEED = 150;
int thresholds[12];
bool isRunning = false; // Toggle state
bool isAutoMode = true; // true = autonomous line follower, false = manual mode

// PID Parameters
float error = 0, P = 0, I = 0, D = 0, prevError = 0;
float kp = 35.0, ki = 0.0, kd = 12.0;

// Telemetry vars
unsigned long lastTelemetry = 0;
const unsigned long TELEMETRY_INTERVAL = 100; // ms

// Simple callback without complex string handling
class CommandCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic* pCharacteristic) {
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
            
            // Parse and execute command
            handleBLECommand(value);
        } else {
            Serial.println("Received empty write");
        }
    }
};

void setup() {
    Serial.begin(115200);
    Serial.println("Starting BLE...");
    
    // IR & Mux
    pinMode(S0, OUTPUT); pinMode(S1, OUTPUT);
    pinMode(S2, OUTPUT); pinMode(S3, OUTPUT);

    // Motors
    pinMode(AIN1, OUTPUT); pinMode(AIN2, OUTPUT); pinMode(PWMA, OUTPUT);
    pinMode(BIN1, OUTPUT); pinMode(BIN2, OUTPUT); pinMode(PWMB, OUTPUT);
    pinMode(STBY, OUTPUT);

    // Buttons (using internal pullup - assumes button connects to GND)
    pinMode(BTN_TOGGLE, INPUT_PULLUP);
    pinMode(BTN_CALIBRATE, INPUT_PULLUP);

    digitalWrite(STBY, HIGH);
    
    // Default thresholds in case user forgets to calibrate
    for(int i=0; i<12; i++) thresholds[i] = 2000;
    
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
    Serial.println("System Ready. Use BLE app to control.");
}

void loop() {
    checkButtons();

    if (isRunning && isAutoMode) {
        readIRSensors();
        int correction = calculatePID();
        moveRobo(correction);
    } else if (!isRunning) {
        stopMotors();
    }
    
    // Send telemetry periodically
    if (millis() - lastTelemetry >= TELEMETRY_INTERVAL) {
        sendTelemetry();
        lastTelemetry = millis();
    }
    
    delay(10);
}

// --- COMMAND HANDLER ---
void handleBLECommand(String cmd) {
    if (cmd.startsWith("PID:")) {
        // Parse: PID:kp,ki,kd
        int idx1 = cmd.indexOf(',');
        int idx2 = cmd.indexOf(',', idx1 + 1);
        if (idx1 > 0 && idx2 > 0) {
            kp = cmd.substring(4, idx1).toFloat();
            ki = cmd.substring(idx1 + 1, idx2).toFloat();
            kd = cmd.substring(idx2 + 1).toFloat();
            Serial.print("PID Updated: kp="); Serial.print(kp);
            Serial.print(" ki="); Serial.print(ki);
            Serial.print(" kd="); Serial.println(kd);
        }
    } 
    else if (cmd.startsWith("SPEED:")) {
        // Parse: SPEED:value (0-255 sets BASE_SPEED)
        int speed = cmd.substring(6).toInt();
        BASE_SPEED = constrain(speed, 0, 255);
        Serial.print("Speed set to: "); Serial.println(BASE_SPEED);
    } 
    else if (cmd.startsWith("MODE:")) {
        // Parse: MODE:AUTO or MODE:MANUAL or MODE:STOP
        String mode = cmd.substring(5);
        if (mode == "AUTO") {
            isAutoMode = true;
            isRunning = true;
            Serial.println("Mode: AUTO (Line Follower)");
        } else if (mode == "MANUAL") {
            isAutoMode = false;
            isRunning = true;
            Serial.println("Mode: MANUAL");
        } else if (mode == "STOP") {
            isRunning = false;
            Serial.println("Mode: STOP");
        }
    }
}

// --- TELEMETRY SENDER ---
void sendTelemetry() {
    if (pTelemetryCharacteristic != NULL && deviceConnected) {
        // Format: TELEM:currentSpeed,targetSpeed,lateralError,lineDetected
        String telemetry = "TELEM:";
        telemetry += String((int)abs(error), 10);
        telemetry += ",";
        telemetry += String(BASE_SPEED, 10);
        telemetry += ",";
        telemetry += String(error, 1);
        telemetry += ",";
        telemetry += String(isRunning ? 1 : 0);
        
        pTelemetryCharacteristic->setValue(telemetry.c_str());
        pTelemetryCharacteristic->notify();
    }
}

// --- CORE FUNCTIONS ---

void checkButtons() {
    // Toggle Run/Stop
    if (digitalRead(BTN_TOGGLE) == LOW) {
        delay(200); // Simple debounce
        isRunning = !isRunning;
        if (isRunning) Serial.println("LF MODE: ON");
        else Serial.println("LF MODE: OFF");
        while(digitalRead(BTN_TOGGLE) == LOW); // Wait for release
    }

    // Trigger Calibration
    if (digitalRead(BTN_CALIBRATE) == LOW) {
        delay(200);
        calibrate();
        while(digitalRead(BTN_CALIBRATE) == LOW); 
    }
}

void calibrate() {
    Serial.println("Starting Calibration... Spinning for 4 seconds.");
    int sMin[12], sMax[12];
    for (int i = 0; i < 12; i++) { sMin[i] = 4095; sMax[i] = 0; }

    unsigned long startTime = millis();
    while (millis() - startTime < 4000) {
        setMotor(120, -120); // Spin in place
        for (int ch = 0; ch < 12; ch++) {
            selectChannel(ch);
            int val = analogRead(MUX_SIG);
            if (val < sMin[ch]) sMin[ch] = val;
            if (val > sMax[ch]) sMax[ch] = val;
        }
    }
    stopMotors();

    for (int i = 0; i < 12; i++) {
        thresholds[i] = (sMin[i] + sMax[i]) / 2;
    }
    Serial.println("Calibration Complete.");
}

void readIRSensors() {
    long average = 0;
    int count = 0;

    for (int ch = 0; ch < SENSOR_COUNT; ch++) {
        selectChannel(ch);
        int val = analogRead(MUX_SIG);
        
        if (val > thresholds[ch]) { // Detecting black line
            average += (ch - 5.5) * 1000;
            count++;
        }
    }

    if (count > 0) {
        error = average / count;
    } else {
        // If line lost, steer hard in direction of last known error
        error = (prevError > 0) ? 6000 : -6000;
    }
}

int calculatePID() {
    P = error;
    I += error;
    I = constrain(I, -1000, 1000); // Prevent integral windup
    D = error - prevError;
    prevError = error;

    return (int)(kp * P + ki * I + kd * D);
}

void moveRobo(int correction) {
    int leftSpeed = BASE_SPEED + (correction / 10); // Divisor scales PID output
    int rightSpeed = BASE_SPEED - (correction / 10);

    setMotor(constrain(leftSpeed, -255, 255), constrain(rightSpeed, -255, 255));
}

void setMotor(int left, int right) {
    // Left Motor
    digitalWrite(AIN1, left >= 0 ? HIGH : LOW);
    digitalWrite(AIN2, left >= 0 ? LOW : HIGH);
    analogWrite(PWMA, abs(left));

    // Right Motor
    digitalWrite(BIN1, right >= 0 ? HIGH : LOW);
    digitalWrite(BIN2, right >= 0 ? LOW : HIGH);
    analogWrite(PWMB, abs(right));
}

void stopMotors() {
    analogWrite(PWMA, 0);
    analogWrite(PWMB, 0);
}

void selectChannel(int ch) {
    digitalWrite(S0, ch & 1);
    digitalWrite(S1, (ch >> 1) & 1);
    digitalWrite(S2, (ch >> 2) & 1);
    digitalWrite(S3, (ch >> 3) & 1);
    delayMicroseconds(10); // Settling time for MUX
}
