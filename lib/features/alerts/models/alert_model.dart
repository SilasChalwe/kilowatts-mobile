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
      case 'BRANCH_LIMIT_EXCEEDED':
        return AlertCategory.branchLimit;
      case 'MAIN_LIMIT':
      case 'MAIN_LIMIT_EXCEEDED':
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

  String get displayTitle {
    switch (this) {
      case AlertCategory.lowBattery:
        return 'Battery reserve too low';
      case AlertCategory.criticalBattery:
        return 'Battery reserve critical';
      case AlertCategory.branchLimit:
        return 'Branch current limit reached';
      case AlertCategory.mainLimit:
        return 'Main current limit reached';
      case AlertCategory.batteryCurrentLimit:
        return 'Battery current limit reached';
      case AlertCategory.nodeOffline:
        return 'Device offline';
      case AlertCategory.sensorFault:
        return 'Battery sensor problem';
      case AlertCategory.relayFailure:
        return 'Load switching problem';
      case AlertCategory.mqttConnection:
        return 'System connection problem';
      case AlertCategory.systemProtection:
        return 'System protection active';
      case AlertCategory.scheduleExecuted:
        return 'Scheduled action completed';
      case AlertCategory.other:
        return 'System notification';
    }
  }

  String get defaultExplanation {
    switch (this) {
      case AlertCategory.lowBattery:
        return 'The battery state of charge is below the configured safe reserve. Kilowatts is limiting additional load demand until the battery recovers.';
      case AlertCategory.criticalBattery:
        return 'The battery has reached the protected minimum reserve. Kilowatts may switch off eligible loads to protect the battery.';
      case AlertCategory.branchLimit:
        return 'Turning on more load on this branch would exceed its configured current limit, so the request was blocked.';
      case AlertCategory.mainLimit:
        return 'The total installation current would exceed the configured main limit, so additional load demand was blocked.';
      case AlertCategory.batteryCurrentLimit:
        return 'The requested load would push battery discharge current above the configured safe limit, so it was not allowed.';
      case AlertCategory.nodeOffline:
        return 'A device stopped reporting to Central. Check that it is powered and within communication range.';
      case AlertCategory.sensorFault:
        return 'Kilowatts cannot rely on the battery sensor reading. Check the INA219 wiring and configuration.';
      case AlertCategory.relayFailure:
        return 'Kilowatts could not complete the requested load switching operation. Check the relay channel and node connection.';
      case AlertCategory.mqttConnection:
        return 'The app cannot currently exchange live data with Central through the configured MQTT connection.';
      case AlertCategory.systemProtection:
        return 'Kilowatts blocked an operation because a configured electrical or battery safety limit would be exceeded.';
      case AlertCategory.scheduleExecuted:
        return 'A configured load schedule has been applied.';
      case AlertCategory.other:
        return 'Kilowatts reported a system event.';
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'severity': severity.name,
    'category': _categoryWireValue(category),
    'title': title,
    'message': message,
    'timestamp': timestamp.toIso8601String(),
    if (nodeMac != null) 'node_mac': nodeMac,
    if (loadId != null) 'load_id': loadId,
    'acknowledged': acknowledged,
  };

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
    final categoryWire = json.stringOrNull('category') ?? eventType;
    final detail = json.stringOrNull('detail');
    final parsedCategory = AlertCategory.fromWire(categoryWire);
    final detailCategory = AlertCategory.fromWire(detail);
    final effectiveCategory = detailCategory != AlertCategory.other
        ? detailCategory
        : parsedCategory;
    final rawTitle = json.stringOrNull('title');
    final rawMessage = json.stringOrNull('message') ?? detail ?? '';
    final timestamp =
        json.dateTimeOrNull('timestamp') ??
        json.dateTimeOrNull('timestampEpochSeconds') ??
        DateTime.now();

    final title = effectiveCategory == AlertCategory.other
        ? (rawTitle ?? _titleForEvent(eventType))
        : effectiveCategory.displayTitle;
    final message = _isMachineCode(rawMessage) || rawMessage.trim().isEmpty
        ? effectiveCategory.defaultExplanation
        : rawMessage.trim();

    return AlertModel(
      id:
          json.stringOrNull('id') ??
          '$categoryWire-${timestamp.millisecondsSinceEpoch}',
      severity: AlertSeverity.fromWire(
        json.stringOrNull('severity') ?? _severityForEvent(eventType),
      ),
      category: effectiveCategory,
      title: title,
      message: message,
      timestamp: timestamp,
      nodeMac: json.stringOrNull('node_mac') ?? json.stringOrNull('target'),
      loadId: json.stringOrNull('load_id'),
      acknowledged: json.boolOrNull('acknowledged') ?? false,
    );
  }

  static bool _isMachineCode(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;
    return RegExp(r'^[A-Z0-9_]+$').hasMatch(trimmed);
  }

  static String _categoryWireValue(AlertCategory category) {
    switch (category) {
      case AlertCategory.lowBattery:
        return 'LOW_BATTERY';
      case AlertCategory.criticalBattery:
        return 'CRITICAL_BATTERY';
      case AlertCategory.branchLimit:
        return 'BRANCH_LIMIT';
      case AlertCategory.mainLimit:
        return 'MAIN_LIMIT';
      case AlertCategory.batteryCurrentLimit:
        return 'BATTERY_CURRENT_LIMIT';
      case AlertCategory.nodeOffline:
        return 'NODE_OFFLINE';
      case AlertCategory.sensorFault:
        return 'SENSOR_FAULT';
      case AlertCategory.relayFailure:
        return 'RELAY_FAILURE';
      case AlertCategory.mqttConnection:
        return 'MQTT_CONNECTION';
      case AlertCategory.systemProtection:
        return 'SYSTEM_PROTECTION';
      case AlertCategory.scheduleExecuted:
        return 'SCHEDULE_EXECUTED';
      case AlertCategory.other:
        return 'OTHER';
    }
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
    if (eventType == null || eventType.isEmpty) return 'System notification';
    return eventType
        .toLowerCase()
        .split('_')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
