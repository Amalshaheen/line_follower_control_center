import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/ble_provider.dart';
import '../models/ble_device_model.dart';
import 'device_detail_screen.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({super.key});

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    // Request Bluetooth permissions
    if (await Permission.bluetoothScan.isDenied) {
      await Permission.bluetoothScan.request();
    }
    if (await Permission.bluetoothConnect.isDenied) {
      await Permission.bluetoothConnect.request();
    }
    if (await Permission.locationWhenInUse.isDenied) {
      await Permission.locationWhenInUse.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showInfoDialog(context),
          ),
        ],
      ),
      body: Consumer<BleProvider>(
        builder: (context, bleProvider, child) {
          // Show Bluetooth status
          if (!bleProvider.isBluetoothOn) {
            return _buildBluetoothOffView(bleProvider);
          }

          // Show error if any
          if (bleProvider.errorMessage != null) {
            return _buildErrorView(bleProvider);
          }

          return Column(
            children: [
              _buildScanControls(bleProvider),
              Expanded(
                child: bleProvider.scannedDevices.isEmpty
                    ? _buildEmptyView(bleProvider)
                    : _buildDeviceList(bleProvider),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBluetoothOffView(BleProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bluetooth_disabled, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Bluetooth is OFF',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Please turn on Bluetooth to scan for devices'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => provider.turnOnBluetooth(),
            icon: const Icon(Icons.bluetooth),
            label: const Text('Turn On Bluetooth'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BleProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red[700]),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              provider.errorMessage!,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => provider.clearError(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Widget _buildScanControls(BleProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Expanded(
            child: Text(
              provider.isScanning
                  ? 'Scanning... (${provider.scannedDevices.length} devices found)'
                  : 'Found ${provider.scannedDevices.length} devices',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          FilledButton.icon(
            onPressed: provider.isScanning
                ? () => provider.stopScan()
                : () => provider.startScan(),
            icon: Icon(provider.isScanning ? Icons.stop : Icons.search),
            label: Text(provider.isScanning ? 'Stop' : 'Scan'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(BleProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 80,
            color: provider.isScanning ? Theme.of(context).primaryColor : Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            provider.isScanning ? 'Searching for devices...' : 'No devices found',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          if (!provider.isScanning)
            const Text('Tap the Scan button to start searching'),
        ],
      ),
    );
  }

  Widget _buildDeviceList(BleProvider provider) {
    return RefreshIndicator(
      onRefresh: () => provider.startScan(),
      child: ListView.builder(
        itemCount: provider.scannedDevices.length,
        itemBuilder: (context, index) {
          final device = provider.scannedDevices[index];
          return _buildDeviceListItem(device, provider);
        },
      ),
    );
  }

  Widget _buildDeviceListItem(BleDeviceModel device, BleProvider provider) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getSignalColor(device.rssi),
          child: Icon(
            _getDeviceIcon(device),
            color: Colors.white,
          ),
        ),
        title: Text(
          device.name ?? 'Unknown Device',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${device.deviceId}'),
            Row(
              children: [
                Icon(Icons.signal_cellular_alt, size: 16, color: _getSignalColor(device.rssi)),
                const SizedBox(width: 4),
                Text('${device.rssi} dBm'),
                const SizedBox(width: 16),
                if (!device.isConnectable)
                  const Chip(
                    label: Text('Not Connectable', style: TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
        trailing: device.isConnectable
            ? IconButton(
                icon: const Icon(Icons.arrow_forward_ios),
                onPressed: () => _connectToDevice(device, provider),
              )
            : null,
        onTap: device.isConnectable ? () => _connectToDevice(device, provider) : null,
      ),
    );
  }

  IconData _getDeviceIcon(BleDeviceModel device) {
    final name = device.name?.toLowerCase() ?? '';
    if (name.contains('esp32') || name.contains('arduino')) {
      return Icons.memory;
    } else if (name.contains('phone') || name.contains('mobile')) {
      return Icons.phone_android;
    } else if (name.contains('watch')) {
      return Icons.watch;
    } else if (name.contains('sensor')) {
      return Icons.sensors;
    }
    return Icons.bluetooth;
  }

  Color _getSignalColor(int rssi) {
    if (rssi > -50) return Colors.green;
    if (rssi > -70) return Colors.orange;
    return Colors.red;
  }

  Future<void> _connectToDevice(BleDeviceModel device, BleProvider provider) async {
    // Stop scanning first
    if (provider.isScanning) {
      await provider.stopScan();
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Connecting...'),
          ],
        ),
      ),
    );

    // Attempt to connect
    final success = await provider.connectToDevice(device);

    // Close loading dialog
    if (mounted) Navigator.of(context).pop();

    if (success && mounted) {
      // Navigate to device detail screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DeviceDetailScreen(),
        ),
      );
    } else if (mounted) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to connect'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About BLE Scanner'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('This app allows you to:'),
              SizedBox(height: 8),
              Text('• Scan for nearby Bluetooth LE devices'),
              Text('• Connect to ESP32 and other BLE devices'),
              Text('• Discover services and characteristics'),
              Text('• Read and write data'),
              Text('• Subscribe to notifications'),
              SizedBox(height: 16),
              Text('Signal Strength:'),
              SizedBox(height: 4),
              Text('🟢 > -50 dBm: Excellent'),
              Text('🟠 > -70 dBm: Good'),
              Text('🔴 < -70 dBm: Weak'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
