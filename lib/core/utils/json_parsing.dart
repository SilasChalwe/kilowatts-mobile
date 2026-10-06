/// Defensive JSON field access for MQTT/embedded payloads.
///
/// Firmware payload fields may be missing, renamed, or of an unexpected
/// type as the wire contract evolves. Every accessor here returns `null`
/// instead of throwing so a partially-known payload still renders the
/// fields it does have.
extension JsonMapX on Map<String, dynamic> {
  String? stringOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    return value.toString();
  }

  double? doubleOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? intOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  bool? boolOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is bool) return value;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    if (value is num) return value != 0;
    return null;
  }

  /// Accepts epoch seconds, epoch milliseconds, or an ISO-8601 string.
  DateTime? dateTimeOrNull(String key) {
    final value = this[key];
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    if (value is num) {
      final asInt = value.toInt();
      // Values below this are almost certainly epoch seconds, not millis.
      final isSeconds = asInt < 20000000000;
      return DateTime.fromMillisecondsSinceEpoch(
        isSeconds ? asInt * 1000 : asInt,
        isUtc: true,
      ).toLocal();
    }
    return null;
  }

  List<Map<String, dynamic>> listOfMaps(String key) {
    final value = this[key];
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  Map<String, dynamic>? mapOrNull(String key) {
    final value = this[key];
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }
}
