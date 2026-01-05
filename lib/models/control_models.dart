/// Models for robot control parameters

/// PID (Proportional-Integral-Derivative) controller parameters
class PIDParameters {
  final double kp; // Proportional gain
  final double ki; // Integral gain
  final double kd; // Derivative gain

  const PIDParameters({required this.kp, required this.ki, required this.kd});

  /// Default PID values
  factory PIDParameters.defaultValues() {
    return const PIDParameters(kp: 1.0, ki: 0.0, kd: 0.0);
  }

  /// Create from command string (e.g., "PID:1.0,0.5,0.2")
  factory PIDParameters.fromCommand(String command) {
    final parts = command.split(':');
    if (parts.length != 2 || parts[0] != 'PID') {
      throw FormatException('Invalid PID command format');
    }

    final values = parts[1].split(',');
    if (values.length != 3) {
      throw FormatException('PID requires 3 values');
    }

    return PIDParameters(
      kp: double.parse(values[0]),
      ki: double.parse(values[1]),
      kd: double.parse(values[2]),
    );
  }

  /// Convert to command string
  String toCommand() {
    return 'PID:${kp.toStringAsFixed(2)},${ki.toStringAsFixed(2)},${kd.toStringAsFixed(2)}';
  }

  PIDParameters copyWith({double? kp, double? ki, double? kd}) {
    return PIDParameters(
      kp: kp ?? this.kp,
      ki: ki ?? this.ki,
      kd: kd ?? this.kd,
    );
  }

  @override
  String toString() => 'PID(kp: $kp, ki: $ki, kd: $kd)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PIDParameters &&
          runtimeType == other.runtimeType &&
          kp == other.kp &&
          ki == other.ki &&
          kd == other.kd;

  @override
  int get hashCode => Object.hash(kp, ki, kd);
}

/// Speed control parameters
class SpeedControl {
  final int speed; // Speed value (0-255)
  final bool isRunning;

  const SpeedControl({required this.speed, this.isRunning = false});

  /// Default speed value
  factory SpeedControl.defaultValue() {
    return const SpeedControl(speed: 0, isRunning: false);
  }

  /// Create from command string (e.g., "SPEED:150")
  factory SpeedControl.fromCommand(String command) {
    final parts = command.split(':');
    if (parts.length != 2 || parts[0] != 'SPEED') {
      throw FormatException('Invalid SPEED command format');
    }

    return SpeedControl(speed: int.parse(parts[1]), isRunning: true);
  }

  /// Convert to command string
  String toCommand() {
    return 'SPEED:$speed';
  }

  /// Stop command
  String toStopCommand() {
    return 'SPEED:0';
  }

  SpeedControl copyWith({int? speed, bool? isRunning}) {
    return SpeedControl(
      speed: speed ?? this.speed,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  /// Get speed as percentage (0-100%)
  double get speedPercent => (speed / 255.0 * 100.0).clamp(0.0, 100.0);

  @override
  String toString() => 'Speed: $speed (${speedPercent.toStringAsFixed(0)}%)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SpeedControl &&
          runtimeType == other.runtimeType &&
          speed == other.speed &&
          isRunning == other.isRunning;

  @override
  int get hashCode => Object.hash(speed, isRunning);
}

/// Robot control mode
enum ControlMode {
  manual,
  auto,
  stopped;

  String toCommand() {
    switch (this) {
      case ControlMode.manual:
        return 'MODE:MANUAL';
      case ControlMode.auto:
        return 'MODE:AUTO';
      case ControlMode.stopped:
        return 'MODE:STOP';
    }
  }

  static ControlMode fromString(String mode) {
    switch (mode.toUpperCase()) {
      case 'MANUAL':
        return ControlMode.manual;
      case 'AUTO':
        return ControlMode.auto;
      case 'STOP':
      case 'STOPPED':
        return ControlMode.stopped;
      default:
        return ControlMode.stopped;
    }
  }
}

/// Telemetry data from robot
class RobotTelemetry {
  final int currentSpeed;
  final int targetSpeed;
  final double lateralError;
  final bool lineDetected;
  final DateTime timestamp;

  const RobotTelemetry({
    required this.currentSpeed,
    required this.targetSpeed,
    required this.lateralError,
    required this.lineDetected,
    required this.timestamp,
  });

  /// Parse from telemetry string (e.g., "TELEM:100,120,0.5,1")
  factory RobotTelemetry.fromCommand(String command) {
    final parts = command.split(':');
    if (parts.length != 2 || parts[0] != 'TELEM') {
      throw FormatException('Invalid TELEM command format');
    }

    final values = parts[1].split(',');
    if (values.length < 4) {
      throw FormatException('TELEM requires at least 4 values');
    }

    return RobotTelemetry(
      currentSpeed: int.parse(values[0]),
      targetSpeed: int.parse(values[1]),
      lateralError: double.parse(values[2]),
      lineDetected: values[3] == '1',
      timestamp: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'Telemetry(speed: $currentSpeed/$targetSpeed, error: $lateralError, line: $lineDetected)';
  }
}
