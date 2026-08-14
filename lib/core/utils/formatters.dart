abstract final class Formatters {
  static const String unavailable = '—';

  static String power(double? watts, {int decimalsForKw = 2}) {
    if (watts == null) return unavailable;
    final absWatts = watts.abs();
    if (absWatts >= 1000) {
      return '${(watts / 1000).toStringAsFixed(decimalsForKw)} kW';
    }
    return '${watts.toStringAsFixed(0)} W';
  }

  static String energy(double? kWh) {
    if (kWh == null) return unavailable;
    return '${kWh.toStringAsFixed(kWh.abs() >= 10 ? 1 : 2)} kWh';
  }

  static String percent(double? value) {
    if (value == null) return unavailable;
    return '${value.round()}%';
  }

  static String voltage(double? volts) {
    if (volts == null) return unavailable;
    return '${volts.toStringAsFixed(1)} V';
  }

  static String current(double? amps) {
    if (amps == null) return unavailable;
    return '${amps.toStringAsFixed(1)} A';
  }

  static String temperatureC(double? celsius) {
    if (celsius == null) return unavailable;
    return '${celsius.toStringAsFixed(0)}°C';
  }

  static String hopCount(int? hops) {
    if (hops == null) return unavailable;
    if (hops == 0) return 'Direct';
    return hops == 1 ? '1 hop' : '$hops hops';
  }

  static String relativeTime(DateTime? time, {DateTime? now}) {
    if (time == null) return unavailable;
    final reference = now ?? DateTime.now();
    final difference = reference.difference(time);

    if (difference.isNegative || difference.inSeconds < 5) {
      return 'Just now';
    }
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    }
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    if (difference.inDays == 1) {
      return 'Yesterday';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    return '${time.day}/${time.month}/${time.year}';
  }

  static String durationHm(Duration? duration) {
    if (duration == null) return unavailable;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '${minutes}m';
    return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
  }

  static String uptime(Duration? duration) {
    if (duration == null) return unavailable;
    final days = duration.inDays;
    final hours = duration.inHours.remainder(24);
    final minutes = duration.inMinutes.remainder(60);
    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    return '${hours}h ${minutes}m';
  }

  static String timeOfDay(int hour, int minute) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }
}
