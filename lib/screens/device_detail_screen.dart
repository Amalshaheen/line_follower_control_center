import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../providers/ble_provider.dart';
import '../models/ble_device_model.dart';
import '../models/control_models.dart';
import '../widgets/control_panels.dart';

class DeviceDetailScreen extends StatefulWidget {
  const DeviceDetailScreen({super.key});

  @override
  State<DeviceDetailScreen> createState() => _DeviceDetailScreenState();
}

class _DeviceDetailScreenState extends State<DeviceDetailScreen> {
  // Known service/characteristics for the ESP32 sketch
  static const String _serviceUuid = '12345678-1234-5678-1234-56789abcdef0';
  static const String _commandUuid = '12345678-1234-5678-1234-56789abcdef1';
  static const String _telemetryUuid = '12345678-1234-5678-1234-56789abcdef2';

  final TextEditingController _sendController = TextEditingController();
  final List<String> _receivedMessages = [];
  BluetoothCharacteristic? _selectedCharacteristic;
  BluetoothCharacteristic? _commandCharacteristic;
  BluetoothCharacteristic? _telemetryCharacteristic;
  bool _telemetryListening = false;
  bool _isHexMode = false;

  // Control state
  PIDParameters _pidParams = PIDParameters(kp: 2.0, ki: 0.5, kd: 1.0);
  SpeedControl _speedControl = SpeedControl(speed: 0);
  ControlMode _controlMode = ControlMode.stopped;

  BluetoothCharacteristic? get _commandTarget {
    // Prefer the known command characteristic; otherwise allow a manually
    // selected characteristic only if it supports write.
    if (_commandCharacteristic != null) return _commandCharacteristic;
    if (_selectedCharacteristic != null &&
        (_selectedCharacteristic!.properties.write ||
            _selectedCharacteristic!.properties.writeWithoutResponse)) {
      return _selectedCharacteristic;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    // Try to auto-bind the known command/telemetry characteristics once the UI is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindKnownCharacteristics());
  }

  @override
  void dispose() {
    final provider = Provider.of<BleProvider>(context, listen: false);
    if (_telemetryCharacteristic != null && _telemetryListening) {
      provider.unsubscribeFromCharacteristic(_telemetryCharacteristic!);
    }
    _sendController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Line Follower Control'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshRssi),
          IconButton(icon: const Icon(Icons.close), onPressed: _disconnect),
        ],
      ),
      body: Consumer<BleProvider>(
        builder: (context, bleProvider, child) {
          if (bleProvider.connectedDevice == null) {
            return const Center(child: Text('No device connected'));
          }

          final commandChar = _commandCharacteristic ?? _selectedCharacteristic;
          final canSendCommands = commandChar != null &&
              (commandChar.properties.write ||
                  commandChar.properties.writeWithoutResponse);

          // If we already discovered services but haven't latched onto the expected
          // command/telemetry characteristics yet, try again in the next frame.
          if ((commandChar == null || (!_telemetryListening &&
                  _telemetryCharacteristic == null)) &&
              bleProvider.services.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _bindKnownCharacteristics());
          }

          return ListView(
            children: [
              _buildDeviceInfo(bleProvider),

              // Control Mode Selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ControlModeSelector(
                  selectedMode: _controlMode,
                  enabled: canSendCommands,
                  onModeChanged: (mode) {
                    _onModeChanged(mode, bleProvider);
                  },
                ),
              ),

              // PID Control Panel
              PIDControlPanel(
                initialValues: _pidParams,
                onPIDChanged: (params) {
                  setState(() => _pidParams = params);
                },
                onSend: canSendCommands
                    ? () => _sendPIDParameters(bleProvider)
                    : null,
              ),

              // Speed Control Panel
              SpeedControlPanel(
                initialValue: _speedControl,
                onSpeedChanged: (speed) {
                  setState(() {
                    _speedControl = SpeedControl(
                      speed: speed,
                      isRunning: _speedControl.isRunning,
                    );
                  });
                },
                onStart: canSendCommands
                    ? () => _startMotor(bleProvider)
                    : null,
                onStop: canSendCommands ? () => _stopMotor(bleProvider) : null,
              ),

              const Divider(thickness: 2, height: 32),

              // Characteristic Selector
              _buildCharacteristicSelector(bleProvider),

              // Communication Area
              SizedBox(height: 300, child: _buildCommunicationArea()),

              // Send Controls
              _buildSendControls(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeviceInfo(BleProvider provider) {
    final device = provider.connectedDevice!;
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bluetooth_connected, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name ?? 'Unknown Device',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        device.deviceId,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.signal_cellular_alt,
                          size: 16,
                          color: _getSignalColor(device.rssi),
                        ),
                        const SizedBox(width: 4),
                        Text('${device.rssi} dBm'),
                      ],
                    ),
                    Text(
                      '${provider.services.length} services',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacteristicSelector(BleProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: ExpansionTile(
        title: const Text('Services & Characteristics'),
        subtitle: Text(
          _selectedCharacteristic != null
              ? 'Selected: ${_selectedCharacteristic!.uuid}'
              : 'Tap to select a characteristic',
        ),
        children: provider.services.map((service) {
          return ExpansionTile(
            title: Text(
              _getServiceName(service.uuid),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(service.uuid, style: const TextStyle(fontSize: 11)),
            children: service.characteristics.map((char) {
              final isSelected =
                  _selectedCharacteristic?.uuid.toString() == char.uuid;
              return ListTile(
                selected: isSelected,
                leading: Icon(
                  _getCharacteristicIcon(char),
                  color: isSelected ? Theme.of(context).primaryColor : null,
                ),
                title: Text(char.uuid),
                subtitle: Wrap(
                  spacing: 4,
                  children: [
                    if (char.canRead) _buildPropertyChip('READ', Colors.blue),
                    if (char.canWrite)
                      _buildPropertyChip('WRITE', Colors.green),
                    if (char.canNotify)
                      _buildPropertyChip('NOTIFY', Colors.orange),
                    if (char.canIndicate)
                      _buildPropertyChip('INDICATE', Colors.purple),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (char.canRead)
                      IconButton(
                        icon: const Icon(Icons.download, size: 20),
                        onPressed: () =>
                            _readCharacteristic(char.characteristic, provider),
                      ),
                    if (char.canNotify || char.canIndicate)
                      IconButton(
                        icon: Icon(
                          char.isNotifying
                              ? Icons.notifications_active
                              : Icons.notifications,
                          size: 20,
                        ),
                        onPressed: () =>
                            _toggleNotifications(char.characteristic, provider),
                      ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    _selectedCharacteristic = char.characteristic;
                    if (char.uuid.toLowerCase() == _commandUuid &&
                        char.canWrite) {
                      _commandCharacteristic = char.characteristic;
                    }
                    if (char.uuid.toLowerCase() == _telemetryUuid &&
                        (char.canNotify || char.canIndicate)) {
                      _telemetryCharacteristic = char.characteristic;
                    }
                  });
                },
              );
            }).toList(),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPropertyChip(String label, Color color) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 9)),
      backgroundColor: color.withOpacity(0.2),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCommunicationArea() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Messages',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: _isHexMode,
                  onChanged: (value) => setState(() => _isHexMode = value),
                ),
                const Text('HEX'),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _receivedMessages.clear()),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _receivedMessages.isEmpty
                ? const Center(
                    child: Text(
                      'No messages yet\nSend or receive data to see it here',
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(8),
                    itemCount: _receivedMessages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(
                        _receivedMessages[_receivedMessages.length - 1 - index],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String message) {
    final isReceived = message.startsWith('◄');
    return Align(
      alignment: isReceived ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isReceived
              ? Colors.grey[300]
              : Theme.of(context).primaryColor.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(message, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildSendControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _sendController,
              decoration: InputDecoration(
                hintText: _isHexMode
                    ? 'Enter hex (e.g., 0A1B2C)'
                    : 'Enter text message',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              enabled: _commandTarget != null,
            ),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            onPressed: _commandTarget != null ? _sendData : null,
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }

  String _getServiceName(String uuid) {
    final commonServices = {
      '0000180a-0000-1000-8000-00805f9b34fb': 'Device Information',
      '0000180f-0000-1000-8000-00805f9b34fb': 'Battery Service',
      '00001800-0000-1000-8000-00805f9b34fb': 'Generic Access',
      '00001801-0000-1000-8000-00805f9b34fb': 'Generic Attribute',
    };
    return commonServices[uuid] ?? 'Custom Service';
  }

  IconData _getCharacteristicIcon(CharacteristicData char) {
    if (char.canNotify || char.canIndicate) return Icons.notifications;
    if (char.canWrite) return Icons.edit;
    if (char.canRead) return Icons.visibility;
    return Icons.help_outline;
  }

  Color _getSignalColor(int rssi) {
    if (rssi > -50) return Colors.green;
    if (rssi > -70) return Colors.orange;
    return Colors.red;
  }

  Future<void> _readCharacteristic(
    BluetoothCharacteristic characteristic,
    BleProvider provider,
  ) async {
    final value = await provider.readCharacteristic(characteristic);
    if (value != null && mounted) {
      final message = _isHexMode
          ? '◄ RX: ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase()}'
          : '◄ RX: ${String.fromCharCodes(value)}';
      setState(() {
        _receivedMessages.add(message);
      });
    }
  }

  Future<void> _toggleNotifications(
    BluetoothCharacteristic characteristic,
    BleProvider provider,
  ) async {
    final isNotifying = characteristic.isNotifying;

    if (isNotifying) {
      await provider.unsubscribeFromCharacteristic(characteristic);
      if (mounted) {
        if (_telemetryCharacteristic?.uuid == characteristic.uuid) {
          setState(() => _telemetryListening = false);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notifications disabled')));
      }
    } else {
      final success = await provider.subscribeToCharacteristic(characteristic, (
        value,
      ) {
        if (mounted) {
          final message = _isHexMode
              ? '◄ NOTIF: ${value.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase()}'
              : '◄ NOTIF: ${String.fromCharCodes(value)}';
          setState(() {
            _receivedMessages.add(message);
          });
        }
      });

      if (success && mounted) {
        if (_telemetryCharacteristic?.uuid == characteristic.uuid) {
          setState(() => _telemetryListening = true);
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Notifications enabled')));
      }
    }
  }

  Future<void> _sendData() async {
    final target = _commandTarget;
    if (target == null || _sendController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a writable command characteristic first')),
        );
      }
      return;
    }

    final provider = Provider.of<BleProvider>(context, listen: false);
    List<int> data;

    try {
      if (_isHexMode) {
        final hexString = _sendController.text.replaceAll(' ', '');
        data = [];
        for (int i = 0; i < hexString.length; i += 2) {
          final hex = hexString.substring(i, i + 2);
          data.add(int.parse(hex, radix: 16));
        }
      } else {
        data = utf8.encode(_sendController.text);
      }
      debugPrint('Manual send to ${target.uuid}: ${_sendController.text}');

      final success = await provider.writeCharacteristic(
        target,
        data,
      );

      if (success && mounted) {
        final message = _isHexMode
            ? '► TX: ${data.map((e) => e.toRadixString(16).padLeft(2, '0')).join(' ').toUpperCase()}'
            : '► TX: ${_sendController.text}';
        setState(() {
          _receivedMessages.add(message);
          _sendController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _refreshRssi() async {
    final provider = Provider.of<BleProvider>(context, listen: false);
    await provider.readRssi();
  }

  Future<void> _disconnect() async {
    final provider = Provider.of<BleProvider>(context, listen: false);
    await provider.disconnect();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  // Control Command Methods

  void _onModeChanged(ControlMode mode, BleProvider provider) {
    final target = _commandTarget;
    if (target == null) {
      _showMissingCommandChar();
      return;
    }

    debugPrint('Sending MODE to ${target.uuid}: ${mode.toCommand()}');
    provider.sendControlMode(mode, target).then((success) {
      if (success && mounted) {
        setState(() {
          _controlMode = mode;
          if (mode == ControlMode.stopped) {
            _speedControl = SpeedControl(speed: 0);
          }
          _receivedMessages.add('► MODE: ${mode.toCommand()}');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mode: ${mode.name.toUpperCase()}')),
        );
      }
    });
  }

  void _sendPIDParameters(BleProvider provider) {
    final target = _commandTarget;
    if (target == null) {
      _showMissingCommandChar();
      return;
    }

    debugPrint('Sending PID to ${target.uuid}: ${_pidParams.toCommand()}');
    provider.sendPIDParameters(_pidParams, target).then((
      success,
    ) {
      if (success && mounted) {
        setState(() {
          _receivedMessages.add('► ${_pidParams.toCommand()}');
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('PID parameters sent')));
      }
    });
  }

  void _startMotor(BleProvider provider) {
    if (_speedControl.speed == 0) return;

    final target = _commandTarget;
    if (target == null) {
      _showMissingCommandChar();
      return;
    }

    debugPrint('Sending SPEED to ${target.uuid}: ${_speedControl.speed}');
    provider.sendSpeed(_speedControl.speed, target).then((
      success,
    ) {
      if (success && mounted) {
        setState(() {
          _speedControl = SpeedControl(
            speed: _speedControl.speed,
            isRunning: true,
          );
          _receivedMessages.add('► SPEED:${_speedControl.speed}');
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Motor started at speed ${_speedControl.speed}'),
          ),
        );
      }
    });
  }

  void _stopMotor(BleProvider provider) {
    final target = _commandTarget;
    if (target == null) {
      _showMissingCommandChar();
      return;
    }

    debugPrint('Sending STOP to ${target.uuid}');
    provider.sendStopCommand(target).then((success) {
      if (success && mounted) {
        setState(() {
          _speedControl = SpeedControl(speed: 0);
          _receivedMessages.add('► SPEED:0');
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Motor stopped')));
      }
    });
  }

  Future<void> _bindKnownCharacteristics() async {
    final provider = Provider.of<BleProvider>(context, listen: false);
    if (!mounted || provider.services.isEmpty) return;

    BluetoothCharacteristic? commandChar = _commandCharacteristic;
    BluetoothCharacteristic? telemetryChar = _telemetryCharacteristic;
    BluetoothCharacteristic? fallbackWritable;

    for (final service in provider.services) {
      if (service.uuid.toLowerCase() != _serviceUuid) continue;
      for (final char in service.characteristics) {
        final uuid = char.uuid.toLowerCase();
        if (uuid == _commandUuid && char.canWrite) {
          commandChar = char.characteristic;
        }
        if (uuid == _telemetryUuid &&
            (char.canNotify || char.canIndicate)) {
          telemetryChar = char.characteristic;
        }
        if (fallbackWritable == null && char.canWrite) {
          fallbackWritable = char.characteristic;
        }
      }
    }

    // If the explicit command UUID was not found but there is a writable
    // characteristic in the same service, use it as a fallback so commands
    // still route somewhere meaningful.
    commandChar ??= fallbackWritable;

    if (mounted && commandChar != null &&
        (_commandCharacteristic != commandChar ||
            _selectedCharacteristic == null)) {
      setState(() {
        _commandCharacteristic = commandChar;
        _selectedCharacteristic ??= commandChar;
      });
    }

    if (telemetryChar != null && !_telemetryListening) {
      final subscribed = await provider.subscribeToCharacteristic(
        telemetryChar,
        _handleTelemetryData,
      );

      if (subscribed && mounted) {
        setState(() {
          _telemetryCharacteristic = telemetryChar;
          _telemetryListening = true;
          _receivedMessages.add('◄ Telemetry notifications enabled');
        });
      }
    }
  }

  void _handleTelemetryData(List<int> value) {
    if (!mounted) return;

    final text = String.fromCharCodes(value);
    String message;

    try {
      if (text.startsWith('TELEM:')) {
        final telemetry = RobotTelemetry.fromCommand(text);
        message =
            '◄ Telemetry | speed ${telemetry.currentSpeed}/${telemetry.targetSpeed}, err ${telemetry.lateralError.toStringAsFixed(2)}, line ${telemetry.lineDetected ? '1' : '0'}';
      } else {
        message = '◄ NOTIF: $text';
      }
    } catch (_) {
      message = '◄ NOTIF: $text';
    }

    setState(() {
      _receivedMessages.add(message);
    });
  }

  void _showMissingCommandChar() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Command characteristic not found. Tap the writable char or refresh.')),
    );
  }
}
