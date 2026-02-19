import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:async';
import 'package:uuid/uuid.dart';

import '../services/bluetooth_service.dart';
import '../services/run_data_service.dart';
import '../models/run_data.dart';
import '../widgets/big_run_button.dart';
import '../widgets/param_slider.dart';
import '../widgets/log_console.dart';
import '../widgets/saved_runs_list.dart';
import 'device_selection_screen.dart';

class ControlScreen extends StatefulWidget {
  final BluetoothDevice? device;

  const ControlScreen({super.key, this.device});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  final BluetoothService _bt = BluetoothService();
  final RunDataService _runDataService = RunDataService();

  bool isRunning = false;
  double kp = 30;
  double ki = 0;
  double kd = 0;
  double baseSpeed = 150;
  final List<String> logs = [];
  bool isConnected = false;
  
  // Run tracking variables
  List<RunData> savedRuns = [];
  bool _loadingSavedRuns = false;
  int? _pendingRunTime;

  @override
  void initState() {
    super.initState();
    _loadSavedRuns();
    
    _bt.onDataReceived = (msg) {
      if (mounted) {
        final trimmedMsg = msg.trim();
        setState(() {
          logs.add(trimmedMsg);
          
          // Listen for robot state messages from Arduino
          if (trimmedMsg == "Robot Started") {
            isRunning = true;
          } else if (trimmedMsg == "Robot Stopped") {
            isRunning = false;
            // Request the actual runtime from Arduino
            _bt.send("TIME?");
          } else if (trimmedMsg.startsWith("TIME=")) {
            // Parse the runtime from Arduino
            final timeStr = trimmedMsg.substring(5);
            final runTime = int.tryParse(timeStr);
            
            // runTime > 0: Bot auto-completed (finish line detected)
            // runTime == 0: Manual stop by user (ignored)
            // runTime < 120000: Ensure reasonable completion time (< 2 minutes)
            if (runTime != null && runTime > 0 && runTime < 120000) {
              _pendingRunTime = runTime;
              _saveRunData();
            }
          }
        });
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

  void calibrateBlack() {
    _bt.send("CAL=BLACK");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Black calibration started...'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void calibrateWhite() {
    _bt.send("CAL=WHITE");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('White calibration started...'),
        duration: Duration(seconds: 3),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Future<void> _loadSavedRuns() async {
    if (mounted) {
      setState(() => _loadingSavedRuns = true);
    }
    savedRuns = await _runDataService.getAllRuns();
    if (mounted) {
      setState(() => _loadingSavedRuns = false);
    }
  }

  Future<void> _saveRunData() async {
    // Only save if we have a valid runtime from Arduino (bot auto-completed)
    if (_pendingRunTime == null || _pendingRunTime == 0) {
      return;
    }

    final run = RunData(
      id: const Uuid().v4().substring(0, 8),
      timeMs: _pendingRunTime!,
      kp: kp,
      ki: ki,
      kd: kd,
      baseSpeed: baseSpeed.toInt(),
      timestamp: DateTime.now(),
    );
    
    await _runDataService.saveRun(run);
    await _loadSavedRuns();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Run saved! Time: ${run.formattedTime}'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
    
    _pendingRunTime = null;
  }

  void _loadRunConfiguration(RunData run) {
    setState(() {
      kp = run.kp;
      ki = run.ki;
      kd = run.kd;
      baseSpeed = run.baseSpeed.toDouble();
    });
    
    // Send to device
    sendParam("KP", kp);
    sendParam("KI", ki);
    sendParam("KD", kd);
    sendParam("BASE", baseSpeed);
  }

  Future<void> _deleteRun(String id) async {
    await _runDataService.deleteRun(id);
    await _loadSavedRuns();
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
                // Calibration Section
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Calibration",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF06B6D4),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: calibrateBlack,
                              child: const Text(
                                "Calibrate Black",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF7C3AED),
                                foregroundColor: Colors.white,
                                elevation: 4,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: calibrateWhite,
                              child: const Text(
                                "Calibrate White",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Parameters Section
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
                const SizedBox(height: 24),
                // Saved Runs Section
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Saved Runs",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF06B6D4),
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (savedRuns.isNotEmpty)
                        TextButton.icon(
                          onPressed: () async {
                            await _runDataService.clearAllRuns();
                            await _loadSavedRuns();
                          },
                          icon: const Icon(Icons.delete_sweep, size: 18),
                          label: const Text("Clear All"),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 250,
                  child: SavedRunsList(
                    runs: savedRuns,
                    onRunSelected: _loadRunConfiguration,
                    onRunDeleted: _deleteRun,
                    isLoading: _loadingSavedRuns,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
