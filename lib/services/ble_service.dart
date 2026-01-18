import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Service to manage Bluetooth Low Energy operations
class BleService {
  // Singleton pattern
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // Streams and controllers
  final _scanResultsController = StreamController<List<ScanResult>>.broadcast();
  final _connectionStateController = StreamController<Map<String, BluetoothConnectionState>>.broadcast();
  
  Stream<List<ScanResult>> get scanResults => _scanResultsController.stream;
  Stream<Map<String, BluetoothConnectionState>> get connectionStates => _connectionStateController.stream;

  final Map<String, BluetoothConnectionState> _deviceConnectionStates = {};
  final Map<String, StreamSubscription> _connectionSubscriptions = {};
  
  /// Check if Bluetooth is supported on this device
  Future<bool> isBluetoothSupported() async {
    return await FlutterBluePlus.isSupported;
  }

  /// Get current Bluetooth adapter state
  Stream<BluetoothAdapterState> get adapterState => FlutterBluePlus.adapterState;

  /// Turn on Bluetooth (Android only)
  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      throw Exception('Failed to turn on Bluetooth: $e');
    }
  }

  /// Start scanning for BLE devices
  Future<void> startScan({
    List<Guid>? withServices,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        _scanResultsController.add(results);
      });

      // Start scanning
      await FlutterBluePlus.startScan(
        withServices: withServices ?? [],
        timeout: timeout,
        androidUsesFineLocation: false,
      );

      // Wait for scan to complete
      await FlutterBluePlus.isScanning.where((scanning) => !scanning).first;
    } catch (e) {
      throw Exception('Failed to start scan: $e');
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      throw Exception('Failed to stop scan: $e');
    }
  }

  /// Get last scan results
  List<ScanResult> getLastScanResults() {
    return FlutterBluePlus.lastScanResults;
  }

  /// Connect to a device
  Future<void> connect(BluetoothDevice device, {Duration timeout = const Duration(seconds: 35)}) async {
    try {
      // Setup connection state listener
      _connectionSubscriptions[device.remoteId.toString()] = 
        device.connectionState.listen((state) {
          _deviceConnectionStates[device.remoteId.toString()] = state;
          _connectionStateController.add(_deviceConnectionStates);
          
          if (state == BluetoothConnectionState.disconnected) {
            print('Device ${device.platformName} disconnected');
            if (device.disconnectReason != null) {
              print('Reason: ${device.disconnectReason?.code} - ${device.disconnectReason?.description}');
            }
          }
        });

      // Cancel subscription when disconnected
      device.cancelWhenDisconnected(_connectionSubscriptions[device.remoteId.toString()]!, delayed: true, next: true);

      // Connect to device
      await device.connect(
        timeout: timeout,
        mtu: null, // Let the OS handle MTU negotiation
      );
      
      print('Connected to ${device.platformName}');
    } catch (e) {
      throw Exception('Failed to connect: $e');
    }
  }

  /// Disconnect from a device
  Future<void> disconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
      _connectionSubscriptions[device.remoteId.toString()]?.cancel();
      _connectionSubscriptions.remove(device.remoteId.toString());
    } catch (e) {
      throw Exception('Failed to disconnect: $e');
    }
  }

  /// Discover services on a connected device
  Future<List<BluetoothService>> discoverServices(BluetoothDevice device) async {
    try {
      return await device.discoverServices();
    } catch (e) {
      throw Exception('Failed to discover services: $e');
    }
  }

  /// Read from a characteristic
  Future<List<int>> readCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      return await characteristic.read();
    } catch (e) {
      throw Exception('Failed to read characteristic: $e');
    }
  }

  /// Write to a characteristic
  Future<void> writeCharacteristic(
    BluetoothCharacteristic characteristic,
    List<int> value, {
    bool withoutResponse = false,
  }) async {
    try {
      // Debug hook: log the write target and size to help diagnose silent writes.
      print('BleService write -> ${characteristic.uuid} len=${value.length} withoutResponse=$withoutResponse');
      await characteristic.write(value, withoutResponse: withoutResponse);
    } catch (e) {
      throw Exception('Failed to write characteristic: $e');
    }
  }

  /// Subscribe to characteristic notifications
  Future<StreamSubscription<List<int>>> subscribeToCharacteristic(
    BluetoothCharacteristic characteristic,
    void Function(List<int>) onData,
  ) async {
    try {
      // Enable notifications
      await characteristic.setNotifyValue(true);
      
      // Listen to notifications
      return characteristic.onValueReceived.listen(onData);
    } catch (e) {
      throw Exception('Failed to subscribe to characteristic: $e');
    }
  }

  /// Unsubscribe from characteristic notifications
  Future<void> unsubscribeFromCharacteristic(
    BluetoothCharacteristic characteristic,
    StreamSubscription subscription,
  ) async {
    try {
      await subscription.cancel();
      await characteristic.setNotifyValue(false);
    } catch (e) {
      throw Exception('Failed to unsubscribe from characteristic: $e');
    }
  }

  /// Read RSSI (signal strength)
  Future<int> readRssi(BluetoothDevice device) async {
    try {
      return await device.readRssi();
    } catch (e) {
      throw Exception('Failed to read RSSI: $e');
    }
  }

  /// Request MTU change
  Future<int> requestMtu(BluetoothDevice device, int mtu) async {
    try {
      return await device.requestMtu(mtu);
    } catch (e) {
      throw Exception('Failed to request MTU: $e');
    }
  }

  /// Get connected devices
  List<BluetoothDevice> getConnectedDevices() {
    return FlutterBluePlus.connectedDevices;
  }

  /// Dispose resources
  void dispose() {
    _scanResultsController.close();
    _connectionStateController.close();
    for (var subscription in _connectionSubscriptions.values) {
      subscription.cancel();
    }
    _connectionSubscriptions.clear();
  }
}
