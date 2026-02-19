class RunData {
  final String id;
  final int timeMs;
  final double kp;
  final double ki;
  final double kd;
  final int baseSpeed;
  final DateTime timestamp;

  RunData({
    required this.id,
    required this.timeMs,
    required this.kp,
    required this.ki,
    required this.kd,
    required this.baseSpeed,
    required this.timestamp,
  });

  String get formattedTime {
    final seconds = (timeMs / 1000).toStringAsFixed(2);
    return "${seconds}s";
  }

  String get formattedDate {
    return "${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}";
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timeMs': timeMs,
      'kp': kp,
      'ki': ki,
      'kd': kd,
      'baseSpeed': baseSpeed,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory RunData.fromJson(Map<String, dynamic> json) {
    return RunData(
      id: json['id'] as String,
      timeMs: json['timeMs'] as int,
      kp: (json['kp'] as num).toDouble(),
      ki: (json['ki'] as num).toDouble(),
      kd: (json['kd'] as num).toDouble(),
      baseSpeed: json['baseSpeed'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
