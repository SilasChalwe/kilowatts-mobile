import 'package:flutter/material.dart';

import '../models/telemetry_point.dart';
import '../theme/app_colors.dart';

class TelemetryLineChart extends StatelessWidget {
  const TelemetryLineChart({
    required this.points,
    required this.unit,
    super.key,
    this.height = 220,
    this.minimumY,
    this.maximumY,
  });

  final List<TelemetryPoint> points;
  final String unit;
  final double height;
  final double? minimumY;
  final double? maximumY;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _TelemetryLinePainter(
          points: points,
          unit: unit,
          minimumY: minimumY,
          maximumY: maximumY,
        ),
      ),
    );
  }
}

class _TelemetryLinePainter extends CustomPainter {
  _TelemetryLinePainter({
    required this.points,
    required this.unit,
    required this.minimumY,
    required this.maximumY,
  });

  final List<TelemetryPoint> points;
  final String unit;
  final double? minimumY;
  final double? maximumY;

  static const _leftInset = 52.0;
  static const _rightInset = 12.0;
  static const _topInset = 12.0;
  static const _bottomInset = 30.0;
  static const _yTicks = 4;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 ||
        size.width <= _leftInset + _rightInset ||
        size.height <= _topInset + _bottomInset) {
      return;
    }

    final ordered = [...points]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final values = ordered.map((point) => point.value).toList();
    final observedMin = values.reduce((a, b) => a < b ? a : b);
    final observedMax = values.reduce((a, b) => a > b ? a : b);

    var minY = minimumY ?? observedMin;
    var maxY = maximumY ?? observedMax;
    if (minimumY == null && observedMin >= 0) minY = 0;
    if ((maxY - minY).abs() < 1e-9) {
      final padding = maxY.abs() < 1 ? 1.0 : maxY.abs() * 0.1;
      minY -= padding;
      maxY += padding;
    } else if (maximumY == null) {
      maxY += (maxY - minY) * 0.08;
    }

    final plot = Rect.fromLTRB(
      _leftInset,
      _topInset,
      size.width - _rightInset,
      size.height - _bottomInset,
    );

    final firstTime = ordered.first.timestamp.millisecondsSinceEpoch.toDouble();
    var lastTime = ordered.last.timestamp.millisecondsSinceEpoch.toDouble();
    if ((lastTime - firstTime).abs() < 1) lastTime = firstTime + 1000;

    final gridPaint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    final axisPaint = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = 1;

    for (var index = 0; index <= _yTicks; index++) {
      final ratio = index / _yTicks;
      final y = plot.bottom - plot.height * ratio;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      final tickValue = minY + (maxY - minY) * ratio;
      _paintText(
        canvas,
        _formatValue(tickValue),
        Offset(plot.left - 8, y),
        alignRight: true,
        centerVertically: true,
      );
    }

    for (var index = 0; index <= 2; index++) {
      final ratio = index / 2;
      final x = plot.left + plot.width * ratio;
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom), gridPaint);
      final millis = firstTime + (lastTime - firstTime) * ratio;
      final label = _formatTime(
        DateTime.fromMillisecondsSinceEpoch(millis.round()),
        Duration(milliseconds: (lastTime - firstTime).round()),
      );
      _paintText(
        canvas,
        label,
        Offset(x, plot.bottom + 8),
        alignRight: index == 2,
        centered: index == 1,
      );
    }

    canvas.drawLine(
      Offset(plot.left, plot.bottom),
      Offset(plot.right, plot.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(plot.left, plot.top),
      Offset(plot.left, plot.bottom),
      axisPaint,
    );

    Offset positionFor(TelemetryPoint point) {
      final time = point.timestamp.millisecondsSinceEpoch.toDouble();
      final xRatio = ((time - firstTime) / (lastTime - firstTime))
          .clamp(0.0, 1.0)
          .toDouble();
      final yRatio = ((point.value - minY) / (maxY - minY))
          .clamp(0.0, 1.0)
          .toDouble();
      return Offset(
        plot.left + plot.width * xRatio,
        plot.bottom - plot.height * yRatio,
      );
    }

    final positions = ordered.map(positionFor).toList(growable: false);
    final path = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (final point in positions.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    if (positions.length <= 30) {
      final markerPaint = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.55);
      for (final point in positions.take(positions.length - 1)) {
        canvas.drawCircle(point, 2.2, markerPaint);
      }
    }

    final first = positions.first;
    canvas.drawCircle(
      first,
      3,
      Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      first,
      3,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final latest = positions.last;
    canvas.drawCircle(latest, 6, Paint()..color = AppColors.primarySoft);
    canvas.drawCircle(latest, 3.5, Paint()..color = AppColors.primary);
  }

  String _formatValue(double value) {
    final abs = value.abs();
    final decimals = abs >= 100
        ? 0
        : abs >= 10
        ? 1
        : 2;
    final text = value.toStringAsFixed(decimals);
    return unit.isEmpty ? text : '$text $unit';
  }

  String _formatTime(DateTime value, Duration span) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    if (span.inHours < 24) return '$hour:$minute';
    return '${local.day} ${_month(local.month)} $hour:$minute';
  }

  String _month(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool alignRight = false,
    bool centered = false,
    bool centerVertically = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    var dx = anchor.dx;
    var dy = anchor.dy;
    if (alignRight) dx -= painter.width;
    if (centered) dx -= painter.width / 2;
    if (centerVertically) dy -= painter.height / 2;
    painter.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(covariant _TelemetryLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.unit != unit ||
        oldDelegate.minimumY != minimumY ||
        oldDelegate.maximumY != maximumY;
  }
}
