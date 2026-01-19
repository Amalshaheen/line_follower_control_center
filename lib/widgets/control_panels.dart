import 'package:flutter/material.dart';
import '../models/control_models.dart';

/// PID Control Panel Widget with sliders for P, I, D values
class PIDControlPanel extends StatefulWidget {
  final PIDParameters initialValues;
  final Function(PIDParameters) onPIDChanged;
  final VoidCallback? onSend;
  final bool enabled;

  const PIDControlPanel({
    super.key,
    required this.initialValues,
    required this.onPIDChanged,
    this.onSend,
    this.enabled = true,
  });

  @override
  State<PIDControlPanel> createState() => _PIDControlPanelState();
}

class _PIDControlPanelState extends State<PIDControlPanel> {
  late double _kp;
  late double _ki;
  late double _kd;

  @override
  void initState() {
    super.initState();
    _kp = widget.initialValues.kp;
    _ki = widget.initialValues.ki;
    _kd = widget.initialValues.kd;
  }

  void _updatePID() {
    final params = PIDParameters(kp: _kp, ki: _ki, kd: _kd);
    widget.onPIDChanged(params);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'PID Tuning',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (widget.onSend != null)
                  FilledButton.icon(
                    onPressed: widget.enabled ? widget.onSend : null,
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Send'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label: 'P (Proportional)',
              value: _kp,
              min: 0.0,
              max: 10.0,
              divisions: 100,
              color: Colors.blue,
              onChanged: widget.enabled
                  ? (value) {
                      setState(() => _kp = value);
                      _updatePID();
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            _buildSlider(
              label: 'I (Integral)',
              value: _ki,
              min: 0.0,
              max: 5.0,
              divisions: 100,
              color: Colors.green,
              onChanged: widget.enabled
                  ? (value) {
                      setState(() => _ki = value);
                      _updatePID();
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            _buildSlider(
              label: 'D (Derivative)',
              value: _kd,
              min: 0.0,
              max: 5.0,
              divisions: 100,
              color: Colors.orange,
              onChanged: widget.enabled
                  ? (value) {
                      setState(() => _kd = value);
                      _updatePID();
                    }
                  : null,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildValueDisplay('P', _kp, Colors.blue),
                  _buildValueDisplay('I', _ki, Colors.green),
                  _buildValueDisplay('D', _kd, Colors.orange),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required Color color,
    required ValueChanged<double>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  inactiveTrackColor: color.withOpacity(0.3),
                  thumbColor: color,
                  overlayColor: color.withOpacity(0.2),
                  valueIndicatorColor: color,
                  valueIndicatorTextStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  label: value.toStringAsFixed(2),
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 50,
              child: Text(
                value.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildValueDisplay(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toStringAsFixed(2),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

/// Speed Control Panel Widget with slider and start/stop buttons
class SpeedControlPanel extends StatefulWidget {
  final SpeedControl initialValue;
  final Function(int) onSpeedChanged;
  final VoidCallback? onStart;
  final VoidCallback? onStop;
  final bool enabled;

  const SpeedControlPanel({
    super.key,
    required this.initialValue,
    required this.onSpeedChanged,
    this.onStart,
    this.onStop,
    this.enabled = true,
  });

  @override
  State<SpeedControlPanel> createState() => _SpeedControlPanelState();
}

class _SpeedControlPanelState extends State<SpeedControlPanel> {
  late double _speed;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _speed = widget.initialValue.speed.toDouble();
    _isRunning = widget.initialValue.isRunning;
  }

  @override
  void didUpdateWidget(SpeedControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue.isRunning != widget.initialValue.isRunning) {
      setState(() {
        _isRunning = widget.initialValue.isRunning;
      });
    }
  }

  void _handleSpeedChange(double value) {
    setState(() => _speed = value);
    widget.onSpeedChanged(value.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speedPercent = (_speed / 255.0 * 100.0).toStringAsFixed(0);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: theme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Speed Control',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Speed',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: theme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: _isRunning
                              ? Colors.green
                              : theme.primaryColor,
                          inactiveTrackColor: theme.primaryColor.withOpacity(
                            0.3,
                          ),
                          thumbColor: _isRunning
                              ? Colors.green
                              : theme.primaryColor,
                          overlayColor:
                              (_isRunning ? Colors.green : theme.primaryColor)
                                  .withOpacity(0.2),
                          valueIndicatorColor: _isRunning
                              ? Colors.green
                              : theme.primaryColor,
                          valueIndicatorTextStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          trackHeight: 6,
                        ),
                        child: Slider(
                          value: _speed,
                          min: 0,
                          max: 255,
                          divisions: 51,
                          label: '$speedPercent%',
                          onChanged: widget.enabled ? _handleSpeedChange : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Speed',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _speed.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '/ 255',
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$speedPercent%',
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (_isRunning)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'RUNNING',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.enabled && !_isRunning
                        ? widget.onStart
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('START'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.enabled && _isRunning
                        ? widget.onStop
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.stop),
                    label: const Text('STOP'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Control Mode Selector Widget
class ControlModeSelector extends StatelessWidget {
  final ControlMode selectedMode;
  final Function(ControlMode) onModeChanged;
  final bool enabled;

  const ControlModeSelector({
    super.key,
    required this.selectedMode,
    required this.onModeChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_remote, color: theme.primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Control Mode',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<ControlMode>(
              segments: const [
                ButtonSegment<ControlMode>(
                  value: ControlMode.manual,
                  label: Text('MANUAL'),
                  icon: Icon(Icons.touch_app),
                ),
                ButtonSegment<ControlMode>(
                  value: ControlMode.auto,
                  label: Text('AUTO'),
                  icon: Icon(Icons.auto_mode),
                ),
                ButtonSegment<ControlMode>(
                  value: ControlMode.stopped,
                  label: Text('STOP'),
                  icon: Icon(Icons.stop_circle),
                ),
              ],
              selected: {selectedMode},
              onSelectionChanged: enabled
                  ? (Set<ControlMode> newSelection) {
                      onModeChanged(newSelection.first);
                    }
                  : null,
              style: ButtonStyle(visualDensity: VisualDensity.comfortable),
            ),
          ],
        ),
      ),
    );
  }
}
