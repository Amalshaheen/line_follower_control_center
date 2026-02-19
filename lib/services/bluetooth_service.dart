import 'dart:convert';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  BluetoothConnection? _connection;
  void Function(String message)? onDataReceived;
  void Function(bool isConnected)? onConnectionStateChanged;
  bool _isDisposed = false;

  bool get isConnected => _connection?.isConnected ?? false;

  Future<void> connect(BluetoothDevice device) async {
    if (_isDisposed) return;
    
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      
      // Notify that connection is established
      if (!_isDisposed) {
        onConnectionStateChanged?.call(true);
      }

      _connection!.input!.listen(
        (data) {
          if (!_isDisposed) {
            final message = utf8.decode(data);
            onDataReceived?.call(message);
          }
        },
        onError: (error) {
          if (!_isDisposed) {
            print('Bluetooth stream error: $error');
            onConnectionStateChanged?.call(false);
          }
        },
        onDone: () {
          if (!_isDisposed) {
            print('Bluetooth stream closed');
            onConnectionStateChanged?.call(false);
          }
        },
      );
    } catch (e) {
      print('Failed to connect: $e');
      if (!_isDisposed) {
        onConnectionStateChanged?.call(false);
      }
      rethrow;
    }
  }

  void send(String message) {
    if (_connection != null && _connection!.isConnected && !_isDisposed) {
      _connection!.output.add(utf8.encode("$message\n"));
    }
  }

  void disconnect() {
    _connection?.dispose();
    _connection = null;
    if (!_isDisposed) {
      onConnectionStateChanged?.call(false);
    }
  }

  void dispose() {
    _isDisposed = true;
    _connection?.dispose();
    _connection = null;
    onDataReceived = null;
    onConnectionStateChanged = null;
  }
}
