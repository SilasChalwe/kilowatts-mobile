class TelemetryPoint {
  const TelemetryPoint({required this.timestamp, required this.value});

  final DateTime timestamp;
  final double value;

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'value': value,
  };

  factory TelemetryPoint.fromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.tryParse(json['timestamp']?.toString() ?? '');
    final rawValue = json['value'];
    if (timestamp == null || rawValue is! num) {
      throw const FormatException('Invalid telemetry point.');
    }
    return TelemetryPoint(timestamp: timestamp, value: rawValue.toDouble());
  }
}
