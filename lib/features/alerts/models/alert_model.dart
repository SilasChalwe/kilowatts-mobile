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
    final eventType = json.stringOrNull('eventType');
    final category = json.stringOrNull('category') ?? eventType;
    final detail = json.stringOrNull('detail');
    final timestamp =
        json.dateTimeOrNull('timestamp') ??
        json.dateTimeOrNull('timestampEpochSeconds') ??
        DateTime.now();
    return AlertModel(
      id:
          json.stringOrNull('id') ??
          '$category-${timestamp.millisecondsSinceEpoch}',
      severity: AlertSeverity.fromWire(
        json.stringOrNull('severity') ?? _severityForEvent(eventType),
      ),
      category: AlertCategory.fromWire(category),
      title: json.stringOrNull('title') ?? _titleForEvent(eventType),
      message: json.stringOrNull('message') ?? detail ?? '',
      timestamp: timestamp,
      nodeMac: json.stringOrNull('node_mac') ?? json.stringOrNull('target'),
      loadId: json.stringOrNull('load_id'),
      acknowledged: json.boolOrNull('acknowledged') ?? false,
    );
  }

  static String _severityForEvent(String? eventType) {
    switch (eventType) {
      case 'NODE_OFFLINE':
      case 'RELAY_FAILURE':
      case 'SENSOR_FAULT':
        return 'warning';
      default:
        return 'info';
    }
  }

  static String _titleForEvent(String? eventType) {
    if (eventType == null || eventType.isEmpty) return 'System Event';
    return eventType
        .toLowerCase()
        .split('_')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
