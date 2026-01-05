import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Model representing a BLE device and its state
class BleDeviceModel {
  final BluetoothDevice device;
  final String deviceId;
  final String? name;
  final int rssi;
  final bool isConnectable;
  BluetoothConnectionState connectionState;
  List<BluetoothService>? services;

  BleDeviceModel({
    required this.device,
    required this.deviceId,
    this.name,
    required this.rssi,
    this.isConnectable = true,
    this.connectionState = BluetoothConnectionState.disconnected,
    this.services,
  });

  /// Create from ScanResult
  factory BleDeviceModel.fromScanResult(ScanResult result) {
    return BleDeviceModel(
      device: result.device,
      deviceId: result.device.remoteId.toString(),
      name: result.device.platformName.isNotEmpty 
          ? result.device.platformName 
          : result.advertisementData.advName.isNotEmpty
              ? result.advertisementData.advName
              : 'Unknown Device',
      rssi: result.rssi,
      isConnectable: result.advertisementData.connectable,
      connectionState: BluetoothConnectionState.disconnected,
    );
  }

  /// Update connection state
  BleDeviceModel copyWith({
    BluetoothConnectionState? connectionState,
    List<BluetoothService>? services,
    int? rssi,
  }) {
    return BleDeviceModel(
      device: device,
      deviceId: deviceId,
      name: name,
      rssi: rssi ?? this.rssi,
      isConnectable: isConnectable,
      connectionState: connectionState ?? this.connectionState,
      services: services ?? this.services,
    );
  }

  bool get isConnected => connectionState == BluetoothConnectionState.connected;
  bool get isConnecting => connectionState == BluetoothConnectionState.connecting;
  bool get isDisconnected => connectionState == BluetoothConnectionState.disconnected;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleDeviceModel &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() {
    return 'BleDeviceModel{name: $name, id: $deviceId, rssi: $rssi, connected: $isConnected}';
  }
}

/// Model for characteristic data
class CharacteristicData {
  final BluetoothCharacteristic characteristic;
  final String uuid;
  final List<int> lastValue;
  final bool canRead;
  final bool canWrite;
  final bool canNotify;
  final bool canIndicate;
  final bool isNotifying;

  CharacteristicData({
    required this.characteristic,
    required this.uuid,
    this.lastValue = const [],
    required this.canRead,
    required this.canWrite,
    required this.canNotify,
    required this.canIndicate,
    this.isNotifying = false,
  });

  factory CharacteristicData.fromCharacteristic(BluetoothCharacteristic characteristic) {
    return CharacteristicData(
      characteristic: characteristic,
      uuid: characteristic.uuid.toString(),
      lastValue: characteristic.lastValue,
      canRead: characteristic.properties.read,
      canWrite: characteristic.properties.write || characteristic.properties.writeWithoutResponse,
      canNotify: characteristic.properties.notify,
      canIndicate: characteristic.properties.indicate,
      isNotifying: characteristic.isNotifying,
    );
  }

  CharacteristicData copyWith({
    List<int>? lastValue,
    bool? isNotifying,
  }) {
    return CharacteristicData(
      characteristic: characteristic,
      uuid: uuid,
      lastValue: lastValue ?? this.lastValue,
      canRead: canRead,
      canWrite: canWrite,
      canNotify: canNotify,
      canIndicate: canIndicate,
      isNotifying: isNotifying ?? this.isNotifying,
    );
  }
}

/// Model for service data
class ServiceData {
  final BluetoothService service;
  final String uuid;
  final List<CharacteristicData> characteristics;
  final bool isPrimary;

  ServiceData({
    required this.service,
    required this.uuid,
    required this.characteristics,
    required this.isPrimary,
  });

  factory ServiceData.fromService(BluetoothService service) {
    return ServiceData(
      service: service,
      uuid: service.uuid.toString(),
      characteristics: service.characteristics
          .map((c) => CharacteristicData.fromCharacteristic(c))
          .toList(),
      isPrimary: service.isPrimary,
    );
  }
}
