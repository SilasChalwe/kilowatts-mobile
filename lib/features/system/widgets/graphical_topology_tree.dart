import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../loads/models/load_model.dart';
import '../models/node_model.dart';
import '../models/topology_model.dart';

/// Renders the installation as a top-down box-and-arrow diagram — Central
/// at the root, Smart Nodes and the DC Loads they own as children, exactly
/// mirroring the physical distribution board layout an installer already
/// thinks in. This is a different visual from a generic indented tree list:
/// every node is a fixed-size box, boxes at the same generation share one
/// row, and a single downward arrow connects each parent to each child.
///
/// Communication topology (ESP-NOW hops to Central) and electrical topology
/// (which branches a node owns) are still two different relationships
/// under the hood (see [TopologyModel]) - a Smart Node's owned DC Loads and
/// its communication-child Smart Nodes are just drawn as siblings one row
/// below it, loads first, matching how an installer reads a physical board.
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

  static const double _boxWidth = 168;
  static const double _boxHeight = 56;
  static const double _hGap = 28;
  static const double _vGap = 48;

  LoadModel? _loadFor(String nodeMac, int relayPin) {
    for (final load in loads) {
      if (load.owningNodeMac == nodeMac && load.relayPin == relayPin) {
        return load;
      }
    }
    return null;
  }

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
          CustomPaint(
            size: Size(width, height),
            painter: _ConnectorPainter(root),
          ),
          ..._buildBoxes(root),
        ],
      ),
    );

    // A SingleChildScrollView left-aligns a child narrower than its
    // viewport by default, which pins the whole diagram (Central included)
    // to the left edge on any installation small enough not to need
    // scrolling. Forcing the scrollable content to be at least as wide as
    // the viewport and centering inside that keeps Central centered on
    // screen when it fits, while still scrolling normally once the real
    // tree grows wider than the viewport.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Center(child: diagram),
            ),
          ),
        );
      },
    );
  }

  /// Assigns every leaf the next free horizontal slot in left-to-right
  /// order, then centres each parent over the midpoint of its own
  /// children's slots - the same layout rule every simple top-down org
  /// chart uses.
  _LaidOutNode _layoutNode(NodeModel node, {required int depth, required _Cell nextSlot}) {
    final childNodes = <_LaidOutNode>[];

    for (final branch in topology.branchesOf(node.mac)) {
      final load = _loadFor(branch.owningNodeMac, branch.relayPin);
      childNodes.add(
        _LaidOutNode(
          titleLine1: 'DC Load',
          titleLine2: load?.name ?? branch.name ?? 'Pin ${branch.relayPin}',
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
      final first = childNodes.first.slot;
      final last = childNodes.last.slot;
      slot = (first + last) / 2;
    }

    return _LaidOutNode(
      titleLine1: node.role == NodeRole.central ? 'Distribution Board' : 'Smart Node',
      titleLine2: node.role == NodeRole.central ? 'Central ESP32' : (node.name ?? node.mac),
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
    final isLoad = node.load != null || node.node == null;

    return Positioned(
      left: left,
      top: top.toDouble(),
      width: _boxWidth,
      height: _boxHeight,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: node.node != null
            ? (onNodeTap == null ? null : () => onNodeTap!(node.node!))
            : (node.load == null || onLoadTap == null
                  ? null
                  : () => onLoadTap!(node.load!)),
        child: Container(
          decoration: BoxDecoration(
            color: isLoad ? AppColors.surface : AppColors.surfaceMuted,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                node.titleLine1,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                node.titleLine2,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mutable counter threaded through the recursive layout so every leaf
/// across the whole tree gets a unique, ever-increasing horizontal slot.
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
      ..color = AppColors.border
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final arrowPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.fill;

    void drawNode(_LaidOutNode node) {
      final start = _bottomCenter(node);
      for (final child in node.children) {
        final end = _topCenter(child);
        final midY = (start.dy + end.dy) / 2;
        final path = Path()
          ..moveTo(start.dx, start.dy)
          ..cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy - 6);
        canvas.drawPath(path, linePaint);

        const arrowSize = 5.0;
        final arrowPath = Path()
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - arrowSize, end.dy - 6 - arrowSize)
          ..lineTo(end.dx + arrowSize, end.dy - 6 - arrowSize)
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
