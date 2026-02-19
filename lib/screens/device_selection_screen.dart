import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

import 'control_screen.dart';

class DeviceSelectionScreen extends StatefulWidget {
  const DeviceSelectionScreen({super.key});

  @override
  State<DeviceSelectionScreen> createState() => _DeviceSelectionScreenState();
}

class _DeviceSelectionScreenState extends State<DeviceSelectionScreen> {
  List<BluetoothDevice> pairedDevices = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPairedDevices();
  }

  Future<void> _loadPairedDevices() async {
    setState(() => isLoading = true);

    // Request Bluetooth permissions
    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every((status) => status.isGranted);

    if (!allGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bluetooth permissions are required'),
          duration: Duration(seconds: 3),
        ),
      );
      setState(() => isLoading = false);
      return;
    }

    try {
      final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
      setState(() {
        pairedDevices = devices.toList();
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading devices: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      setState(() => isLoading = false);
    }
  }

  void _selectDevice(BluetoothDevice device) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ControlScreen(device: device),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Bluetooth Device"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : pairedDevices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/no_devices.png',
                        width: 100,
                        height: 100,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.bluetooth_disabled,
                              size: 100, color: Colors.grey);
                        },
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No paired devices found',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Pair your ESP32 with your phone first',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loadPairedDevices,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: pairedDevices.length,
                  itemBuilder: (context, index) {
                    final device = pairedDevices[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(device.name ?? 'Unknown Device'),
                        subtitle: Text(device.address),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () => _selectDevice(device),
                      ),
                    );
                  },
                ),
      floatingActionButton: pairedDevices.isNotEmpty
          ? FloatingActionButton(
              onPressed: _loadPairedDevices,
              tooltip: 'Refresh devices',
              child: const Icon(Icons.refresh),
            )
          : null,
    );
  }
}
