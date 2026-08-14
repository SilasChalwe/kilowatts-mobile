import '../../../core/utils/json_parsing.dart';

enum AlertSeverity {
  critical,
  warning,
  info;

  static AlertSeverity fromWire(String? value) {
    switch (value?.toLowerCase()) {
      case 'critical':
        return AlertSeverity.critical;
      case 'warning':
        return AlertSeverity.warning;
      default:
        return AlertSeverity.info;
    }
  }
}

enum AlertCategory {
  lowBattery,
  criticalBattery,
  branchLimit,
  mainLimit,
  batteryCurrentLimit,
  nodeOffline,
  sensorFault,
  relayFailure,
  mqttConnection,
  systemProtection,
  scheduleExecuted,
  other;

  static AlertCategory fromWire(String? value) {
    switch (value) {
      case 'LOW_BATTERY':
        return AlertCategory.lowBattery;
      case 'CRITICAL_BATTERY':
        return AlertCategory.criticalBattery;
      case 'BRANCH_LIMIT':
        return AlertCategory.branchLimit;
      case 'MAIN_LIMIT':
        return AlertCategory.mainLimit;
      case 'BATTERY_CURRENT_LIMIT':
        return AlertCategory.batteryCurrentLimit;
      case 'NODE_OFFLINE':
        return AlertCategory.nodeOffline;
      case 'SENSOR_FAULT':
        return AlertCategory.sensorFault;
      case 'RELAY_FAILURE':
        return AlertCategory.relayFailure;
      case 'MQTT_CONNECTION':
        return AlertCategory.mqttConnection;
      case 'SYSTEM_PROTECTION':
        return AlertCategory.systemProtection;
      case 'SCHEDULE_EXECUTED':
        return AlertCategory.scheduleExecuted;
      default:
        return AlertCategory.other;
    }
  }
}

class AlertModel {
  const AlertModel({
    required this.id,
    required this.severity,
    required this.category,
    required this.title,
    required this.message,
    required this.timestamp,
    this.nodeMac,
    this.loadId,
    this.acknowledged = false,
  });

  final String id;
  final AlertSeverity severity;
  final AlertCategory category;
  final String title;
  final String message;
  final DateTime timestamp;
  final String? nodeMac;
  final String? loadId;
  final bool acknowledged;

  AlertModel copyWith({bool? acknowledged}) {
    return AlertModel(
      id: id,
      severity: severity,
      category: category,
      title: title,
      message: message,
      timestamp: timestamp,
      nodeMac: nodeMac,
      loadId: loadId,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }

  factory AlertModel.fromJson(Map<String, dynamic> json) {
    return AlertModel(
      id:
          json.stringOrNull('id') ??
          '${json.stringOrNull('category')}-${json.dateTimeOrNull('timestamp')?.millisecondsSinceEpoch}',
      severity: AlertSeverity.fromWire(json.stringOrNull('severity')),
      category: AlertCategory.fromWire(json.stringOrNull('category')),
      title: json.stringOrNull('title') ?? 'System Event',
      message: json.stringOrNull('message') ?? '',
      timestamp: json.dateTimeOrNull('timestamp') ?? DateTime.now(),
      nodeMac: json.stringOrNull('node_mac'),
      loadId: json.stringOrNull('load_id'),
      acknowledged: json.boolOrNull('acknowledged') ?? false,
    );
  }
}
