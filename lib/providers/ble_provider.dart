import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../models/ble_device_model.dart';
import '../models/control_models.dart';
import '../services/ble_service.dart';

/// Provider for managing BLE state across the app
class BleProvider with ChangeNotifier {
  final BleService _bleService = BleService();

  // State variables
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _isScanning = false;
  final List<BleDeviceModel> _scannedDevices = [];
  BleDeviceModel? _connectedDevice;
  List<ServiceData> _services = [];
  String? _errorMessage;
  final Map<String, StreamSubscription> _characteristicSubscriptions = {};

  // Getters
  BluetoothAdapterState get adapterState => _adapterState;
  bool get isScanning => _isScanning;
  List<BleDeviceModel> get scannedDevices => _scannedDevices;
  BleDeviceModel? get connectedDevice => _connectedDevice;
  List<ServiceData> get services => _services;
  String? get errorMessage => _errorMessage;
  bool get isBluetoothOn => _adapterState == BluetoothAdapterState.on;

  StreamSubscription? _adapterStateSubscription;
  StreamSubscription? _scanResultsSubscription;
  StreamSubscription? _isScanningSubscription;

  BleProvider() {
    _initialize();
  }

  /// Initialize the provider
  Future<void> _initialize() async {
    // Check Bluetooth support
    final isSupported = await _bleService.isBluetoothSupported();
    if (!isSupported) {
      _errorMessage = 'Bluetooth is not supported on this device';
      notifyListeners();
      return;
    }

    // Listen to adapter state changes
    _adapterStateSubscription = _bleService.adapterState.listen((state) {
      _adapterState = state;
      notifyListeners();
    });

    // Listen to scanning state
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      _isScanning = scanning;
      notifyListeners();
    });

    // Listen to scan results
    _scanResultsSubscription = _bleService.scanResults.listen((results) {
      _updateScannedDevices(results);
    });
  }

  /// Update scanned devices list
  void _updateScannedDevices(List<ScanResult> results) {
    for (var result in results) {
      final newDevice = BleDeviceModel.fromScanResult(result);
      final index = _scannedDevices.indexWhere(
        (d) => d.deviceId == newDevice.deviceId,
      );

      if (index != -1) {
        // Update existing device
        _scannedDevices[index] = newDevice;
      } else {
        // Add new device
        _scannedDevices.add(newDevice);
      }
    }
    notifyListeners();
  }

  /// Turn on Bluetooth (Android only)
  Future<void> turnOnBluetooth() async {
    try {
      await _bleService.turnOnBluetooth();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Start scanning for devices
  Future<void> startScan({List<Guid>? withServices, Duration? timeout}) async {
    try {
      _scannedDevices.clear();
      _errorMessage = null;
      notifyListeners();

      await _bleService.startScan(
        withServices: withServices,
        timeout: timeout ?? const Duration(seconds: 15),
      );
    } catch (e) {
      _errorMessage = 'Failed to start scan: $e';
      notifyListeners();
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await _bleService.stopScan();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to stop scan: $e';
    }
    notifyListeners();
  }

  /// Connect to a device
  Future<bool> connectToDevice(BleDeviceModel deviceModel) async {
    try {
      _errorMessage = null;
      notifyListeners();

      await _bleService.connect(deviceModel.device);

      // Wait a bit for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));

      // Discover services
      final services = await _bleService.discoverServices(deviceModel.device);

      _connectedDevice = deviceModel.copyWith(
        connectionState: BluetoothConnectionState.connected,
        services: services,
      );

      _services = services.map((s) => ServiceData.fromService(s)).toList();

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to connect: $e';
      _connectedDevice = null;
      notifyListeners();
      return false;
    }
  }

  /// Disconnect from the connected device
  Future<void> disconnect() async {
    if (_connectedDevice == null) return;

    try {
      // Cancel all characteristic subscriptions
      for (var subscription in _characteristicSubscriptions.values) {
        await subscription.cancel();
      }
      _characteristicSubscriptions.clear();

      await _bleService.disconnect(_connectedDevice!.device);
      _connectedDevice = null;
      _services.clear();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to disconnect: $e';
    }
    notifyListeners();
  }

  /// Read from a characteristic
  Future<List<int>?> readCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    try {
      final value = await _bleService.readCharacteristic(characteristic);
      _errorMessage = null;
      notifyListeners();
      return value;
    } catch (e) {
      _errorMessage = 'Failed to read: $e';
      notifyListeners();
      return null;
    }
  }

  /// Write to a characteristic
  Future<bool> writeCharacteristic(
    BluetoothCharacteristic characteristic,
    List<int> value, {
    bool withoutResponse = false,
  }) async {
    try {
      debugPrint('BLE write -> ${characteristic.uuid} (${characteristic.remoteId}) value=${utf8.decode(value, allowMalformed: true)} len=${value.length} withoutResponse=$withoutResponse');
      await _bleService.writeCharacteristic(
        characteristic,
        value,
        withoutResponse: withoutResponse,
      );
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to write: $e';
      notifyListeners();
      return false;
    }
  }

  /// Subscribe to characteristic notifications
  Future<bool> subscribeToCharacteristic(
    BluetoothCharacteristic characteristic,
    void Function(List<int>) onData,
  ) async {
    try {
      final subscription = await _bleService.subscribeToCharacteristic(
        characteristic,
        onData,
      );
      _characteristicSubscriptions[characteristic.uuid.toString()] =
          subscription;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to subscribe: $e';
      notifyListeners();
      return false;
    }
  }

  /// Unsubscribe from characteristic notifications
  Future<bool> unsubscribeFromCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    final uuid = characteristic.uuid.toString();
    final subscription = _characteristicSubscriptions[uuid];

    if (subscription == null) return false;

    try {
      await _bleService.unsubscribeFromCharacteristic(
        characteristic,
        subscription,
      );
      _characteristicSubscriptions.remove(uuid);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to unsubscribe: $e';
      notifyListeners();
      return false;
    }
  }

  /// Read RSSI (signal strength)
  Future<int?> readRssi() async {
    if (_connectedDevice == null) return null;

    try {
      final rssi = await _bleService.readRssi(_connectedDevice!.device);
      _connectedDevice = _connectedDevice!.copyWith(rssi: rssi);
      notifyListeners();
      return rssi;
    } catch (e) {
      _errorMessage = 'Failed to read RSSI: $e';
      notifyListeners();
      return null;
    }
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ========== Control Methods for Line Follower Robot ==========

  /// Send PID parameters to robot
  Future<bool> sendPIDParameters(
    PIDParameters params,
    BluetoothCharacteristic characteristic,
  ) async {
    try {
      final command = params.toCommand();
      final data = utf8.encode(command);
      await _bleService.writeCharacteristic(characteristic, data);
      debugPrint('Sent PID: $command');
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send PID: $e';
      debugPrint('Error sending PID: $e');
      notifyListeners();
      return false;
    }
  }

  /// Send speed command to robot
  Future<bool> sendSpeed(
    int speed,
    BluetoothCharacteristic characteristic,
  ) async {
    try {
      final command = 'SPEED:$speed';
      final data = utf8.encode(command);
      await _bleService.writeCharacteristic(characteristic, data);
      debugPrint('Sent speed: $command');
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send speed: $e';
      debugPrint('Error sending speed: $e');
      notifyListeners();
      return false;
    }
  }

  /// Send control mode to robot
  Future<bool> sendControlMode(
    ControlMode mode,
    BluetoothCharacteristic characteristic,
  ) async {
    try {
      final command = mode.toCommand();
      final data = utf8.encode(command);
      await _bleService.writeCharacteristic(characteristic, data);
      debugPrint('Sent mode: $command');
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send mode: $e';
      debugPrint('Error sending mode: $e');
      notifyListeners();
      return false;
    }
  }

  /// Send stop command to robot
  Future<bool> sendStopCommand(BluetoothCharacteristic characteristic) async {
    try {
      final command = 'SPEED:0';
      final data = utf8.encode(command);
      await _bleService.writeCharacteristic(characteristic, data);
      debugPrint('Sent stop command');
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send stop: $e';
      debugPrint('Error sending stop: $e');
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _isScanningSubscription?.cancel();

    for (var subscription in _characteristicSubscriptions.values) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();

    _bleService.dispose();
    super.dispose();
  }
}
