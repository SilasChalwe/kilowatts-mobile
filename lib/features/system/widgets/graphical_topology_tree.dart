import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../loads/models/load_model.dart';
import '../models/node_model.dart';
import '../models/topology_model.dart';

/// Top-down installation map. The diagram keeps communication and electrical
/// ownership readable without pretending to be a physical wiring schematic.
class GraphicalTopologyTree extends StatelessWidget {
  const GraphicalTopologyTree({
    required this.topology,
    required this.loads,
    super.key,
    this.onNodeTap,
    this.onLoadTap,
  });

  final TopologyModel topology;
  final List<LoadModel> loads;
  final ValueChanged<NodeModel>? onNodeTap;
  final ValueChanged<LoadModel>? onLoadTap;

  static const double _boxWidth = 196;
  static const double _boxHeight = 74;
  static const double _hGap = 30;
  static const double _vGap = 56;

  List<LoadModel> _loadsOwnedBy(String nodeMac) =>
      loads.where((load) => load.owningNodeMac == nodeMac).toList();

  @override
  Widget build(BuildContext context) {
    final central = topology.central;
    if (central == null) return const SizedBox.shrink();

    final root = _layoutNode(central, depth: 0, nextSlot: _Cell(0));
    final width = (root.maxSlot + 1) * (_boxWidth + _hGap) - _hGap;
    final height = (root.maxDepth + 1) * (_boxHeight + _vGap) - _vGap;

    final diagram = SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          CustomPaint(size: Size(width, height), painter: _ConnectorPainter(root)),
          ..._buildBoxes(root),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Center(child: diagram),
              ),
            ),
          ),
        );
      },
    );
  }

  _LaidOutNode _layoutNode(
    NodeModel node, {
    required int depth,
    required _Cell nextSlot,
  }) {
    final childNodes = <_LaidOutNode>[];

    for (final load in _loadsOwnedBy(node.mac)) {
      childNodes.add(
        _LaidOutNode(
          titleLine1: 'Load',
          titleLine2: load.name,
          slot: nextSlot.value.toDouble(),
          depth: depth + 1,
          load: load,
        ),
      );
      nextSlot.value += 1;
    }

    for (final child in topology.childrenOf(node.mac)) {
      childNodes.add(_layoutNode(child, depth: depth + 1, nextSlot: nextSlot));
    }

    final double slot;
    if (childNodes.isEmpty) {
      slot = nextSlot.value.toDouble();
      nextSlot.value += 1;
    } else {
      slot = (childNodes.first.slot + childNodes.last.slot) / 2;
    }

    return _LaidOutNode(
      titleLine1: node.role == NodeRole.central ? 'Central node' : 'Smart node',
      titleLine2: node.role == NodeRole.central
          ? (node.name ?? 'Central ESP32')
          : (node.name ?? node.mac),
      slot: slot,
      depth: depth,
      node: node,
      children: childNodes,
    );
  }

  List<Widget> _buildBoxes(_LaidOutNode node) {
    final widgets = <Widget>[_buildBox(node)];
    for (final child in node.children) {
      widgets.addAll(_buildBoxes(child));
    }
    return widgets;
  }

  Widget _buildBox(_LaidOutNode node) {
    final left = node.slot * (_boxWidth + _hGap);
    final top = node.depth * (_boxHeight + _vGap);
    final load = node.load;
    final physicalNode = node.node;
    final isLoad = load != null || physicalNode == null;
    final online = physicalNode?.online;
    final loadOn = load?.displayState == true;
    final accent = isLoad
        ? (loadOn ? AppColors.success : AppColors.primary)
        : (online == false ? AppColors.error : AppColors.primary);

    final VoidCallback? onTap = physicalNode != null
        ? (onNodeTap == null ? null : () => onNodeTap!(physicalNode))
        : (load == null || onLoadTap == null ? null : () => onLoadTap!(load));

    return Positioned(
      left: left,
      top: top.toDouble(),
      width: _boxWidth,
      height: _boxHeight,
      child: Material(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: accent.withValues(alpha: isLoad ? 0.20 : 0.26),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          mouseCursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
          hoverColor: accent.withValues(alpha: 0.045),
          focusColor: accent.withValues(alpha: 0.07),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    isLoad
                        ? (loadOn
                            ? Icons.flash_on_rounded
                            : Icons.electrical_services_outlined)
                        : (physicalNode?.role == NodeRole.central
                            ? Icons.memory_rounded
                            : Icons.developer_board_outlined),
                    size: 19,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        node.titleLine1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        node.titleLine2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label,
                      ),
                    ],
                  ),
                ),
                if (physicalNode != null)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: physicalNode.online ? AppColors.success : AppColors.error,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Cell {
  _Cell(this.value);
  int value;
}

class _LaidOutNode {
  _LaidOutNode({
    required this.titleLine1,
    required this.titleLine2,
    required this.slot,
    required this.depth,
    this.node,
    this.load,
    this.children = const [],
  });

  final String titleLine1;
  final String titleLine2;
  final double slot;
  final int depth;
  final NodeModel? node;
  final LoadModel? load;
  final List<_LaidOutNode> children;

  double get maxSlot {
    var result = slot;
    for (final child in children) {
      final childMax = child.maxSlot;
      if (childMax > result) result = childMax;
    }
    return result;
  }

  int get maxDepth {
    var result = depth;
    for (final child in children) {
      final childMax = child.maxDepth;
      if (childMax > result) result = childMax;
    }
    return result;
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter(this.root);

  final _LaidOutNode root;

  static const double _boxWidth = GraphicalTopologyTree._boxWidth;
  static const double _boxHeight = GraphicalTopologyTree._boxHeight;
  static const double _hGap = GraphicalTopologyTree._hGap;
  static const double _vGap = GraphicalTopologyTree._vGap;

  Offset _bottomCenter(_LaidOutNode node) => Offset(
        node.slot * (_boxWidth + _hGap) + _boxWidth / 2,
        node.depth * (_boxHeight + _vGap) + _boxHeight,
      );

  Offset _topCenter(_LaidOutNode node) => Offset(
        node.slot * (_boxWidth + _hGap) + _boxWidth / 2,
        node.depth * (_boxHeight + _vGap),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final arrowPaint = Paint()
      ..color = AppColors.borderStrong
      ..style = PaintingStyle.fill;

    void drawNode(_LaidOutNode node) {
      final start = _bottomCenter(node);
      for (final child in node.children) {
        final end = _topCenter(child);
        final midY = (start.dy + end.dy) / 2;
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy - 7);
        canvas.drawPath(path, linePaint);

        const arrowSize = 4.5;
        final arrowPath = Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - arrowSize, end.dy - 7 - arrowSize)
          ..lineTo(end.dx + arrowSize, end.dy - 7 - arrowSize)
          ..close();
        canvas.drawPath(arrowPath, arrowPaint);

        drawNode(child);
      }
    }

    drawNode(root);
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) => true;
}
