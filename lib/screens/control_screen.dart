import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

import '../services/bluetooth_service.dart';
import '../widgets/big_run_button.dart';
import '../widgets/param_slider.dart';
import '../widgets/log_console.dart';
import 'device_selection_screen.dart';

class ControlScreen extends StatefulWidget {
  final BluetoothDevice? device;

  const ControlScreen({super.key, this.device});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  final BluetoothService _bt = BluetoothService();

  bool isRunning = false;
  double kp = 30;
  double ki = 0;
  double kd = 0;
  double baseSpeed = 150;
  final List<String> logs = [];
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    _bt.onDataReceived = (msg) {
      if (mounted) {
        setState(() => logs.add(msg.trim()));
      }
    };

    // Listen to connection state changes
    _bt.onConnectionStateChanged = (connected) {
      if (mounted) {
        setState(() => isConnected = connected);
      }
    };

    // Auto-connect if device is provided
    if (widget.device != null) {
      _connectToDevice(widget.device!);
    }
  }

  @override
  void dispose() {
    _bt.dispose();
    super.dispose();
  }

  Future<void> connect() async {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const DeviceSelectionScreen(),
      ),
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await _bt.connect(device);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${device.name}'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isConnected = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void toggleRun() {
    isRunning = !isRunning;
    _bt.send("RUN=${isRunning ? 1 : 0}");
    if (mounted) {
      setState(() {});
    }
  }

  void sendParam(String key, double value) {
    _bt.send("$key=${value.toStringAsFixed(2)}");
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusText = isConnected
        ? "Connected to ${widget.device?.name ?? 'Device'}"
        : "Disconnected";
    final statusColor =
        isConnected ? Colors.greenAccent : Colors.redAccent;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Line Follower Controller"),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth),
            onPressed: connect,
          )
        ],
      ),
      body: Column(
        children: [
          BigRunButton(
            isRunning: isRunning,
            onPressed: toggleRun,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                ParamSlider(
                  label: "Kp",
                  value: kp,
                  min: 0,
                  max: 100,
                  onChanged: (v) {
                    kp = v;
                    sendParam("KP", v);
                    setState(() {});
                  },
                ),
                ParamSlider(
                  label: "Ki",
                  value: ki,
                  min: 0,
                  max: 20,
                  onChanged: (v) {
                    ki = v;
                    sendParam("KI", v);
                    setState(() {});
                  },
                ),
                ParamSlider(
                  label: "Kd",
                  value: kd,
                  min: 0,
                  max: 50,
                  onChanged: (v) {
                    kd = v;
                    sendParam("KD", v);
                    setState(() {});
                  },
                ),
                ParamSlider(
                  label: "Base Speed",
                  value: baseSpeed,
                  min: 0,
                  max: 255,
                  onChanged: (v) {
                    baseSpeed = v;
                    sendParam("BASE", v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 20),
                LogConsole(logs: logs),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
