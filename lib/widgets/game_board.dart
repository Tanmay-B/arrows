import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/arrow.dart';
import '../models/board.dart';
import '../models/direction.dart';
import '../providers/game_provider.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final TransformationController _transformController =
      TransformationController();
  String? _movingId;
  int _exitDistance = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          context.read<GameProvider>().completePendingMove();
          setState(() {
            _movingId = null;
            _exitDistance = 0;
          });
          _controller.reset();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _tapArrow(String arrowId) {
    final provider = context.read<GameProvider>();
    final result = provider.tapArrow(arrowId);

    if (result == null) {
      HapticFeedback.mediumImpact();
      Future<void>.delayed(const Duration(milliseconds: 260), () {
        if (mounted) provider.clearRejected();
      });
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _movingId = arrowId;
      _exitDistance = result.exitDistance;
    });
    _controller.duration = Duration(
      milliseconds: 90 + result.exitDistance * 28,
    );
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final board = provider.board;
    final shapeCells = provider.level.shapeCells;
    final showShapeBackground = provider.showShapeBackground;

    return LayoutBuilder(
      builder: (context, constraints) {
        const cellSize = 28.0;
        final boardSize = Size(
          board.cols * cellSize,
          board.rows * cellSize,
        );
        final fitScale = math.min(
          constraints.maxWidth / boardSize.width,
          constraints.maxHeight / boardSize.height,
        );

        return ClipRect(
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: InteractiveViewer(
              key: ValueKey(provider.levelIndex),
              transformationController: _transformController,
              constrained: false,
              minScale: fitScale * 0.8,
              maxScale: math.max(4.0, 1 / fitScale * 2),
              panEnabled: true,
              scaleEnabled: true,
              boundaryMargin: const EdgeInsets.all(120),
              clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: boardSize.width,
              height: boardSize.height,
              child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp:
                  provider.status == GameStatus.playing && _movingId == null
                  ? (details) {
                      final id = _hitTest(
                        details.localPosition,
                        boardSize,
                        board,
                      );
                      if (id != null) _tapArrow(id);
                    }
                  : null,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final progress = _controller.value;
                  return CustomPaint(
                    painter: _ArrowBoardPainter(
                      board: board,
                      shapeCells: shapeCells,
                      showShapeBackground: showShapeBackground,
                      movingId: _movingId,
                      movingProgress: progress,
                      exitDistance: _exitDistance,
                      rejectedId: provider.lastRejectedId,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
      },
    );
  }

  String? _hitTest(Offset tap, Size size, Board board) {
    final metrics = _BoardMetrics(size, board);
    final threshold = metrics.cellSize * 0.42;
    String? closestId;
    var closestDistance = double.infinity;

    for (final arrow in board.arrows.values) {
      for (var index = 1; index < arrow.points.length; index++) {
        final start = metrics.offsetFor(arrow.points[index - 1]);
        final end = metrics.offsetFor(arrow.points[index]);
        final distance = _distanceToSegment(tap, start, end);
        if (distance < threshold && distance < closestDistance) {
          closestDistance = distance;
          closestId = arrow.id;
        }
      }
    }
    return closestId;
  }

  double _distanceToSegment(Offset point, Offset start, Offset end) {
    final segment = end - start;
    final lengthSquared = segment.dx * segment.dx + segment.dy * segment.dy;
    if (lengthSquared == 0) return (point - start).distance;
    final projection =
        ((point - start).dx * segment.dx + (point - start).dy * segment.dy) /
        lengthSquared;
    final t = projection.clamp(0.0, 1.0);
    return (point - (start + segment * t)).distance;
  }
}

class _ArrowBoardPainter extends CustomPainter {
  _ArrowBoardPainter({
    required this.board,
    required this.shapeCells,
    required this.showShapeBackground,
    required this.movingId,
    required this.movingProgress,
    required this.exitDistance,
    required this.rejectedId,
  });

  final Board board;
  final Set<GridPoint> shapeCells;
  final bool showShapeBackground;
  final String? movingId;
  final double movingProgress;
  final int exitDistance;
  final String? rejectedId;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = _BoardMetrics(size, board);
    if (showShapeBackground) {
      _drawShape(canvas, metrics);
    }

    for (final arrow in board.arrows.values) {
      final points = arrow.id == movingId
          ? _ropePointsAtProgress(
              arrow,
              metrics,
              movingProgress,
              exitDistance,
            )
          : arrow.points.map(metrics.offsetFor).toList();
      _drawArrow(
        canvas,
        points,
        arrow.direction,
        metrics,
        arrow.id == rejectedId,
      );
    }
  }

  void _drawShape(Canvas canvas, _BoardMetrics metrics) {
    if (shapeCells.isEmpty) return;

    final fill = Path();
    for (final cell in shapeCells) {
      final center = metrics.offsetFor(cell);
      fill.addRect(
        Rect.fromCenter(
          center: center,
          width: metrics.cellSize * 0.92,
          height: metrics.cellSize * 0.92,
        ),
      );
    }

    canvas.drawPath(
      fill,
      Paint()
        ..color = const Color(0xFFEDE4D8)
        ..style = PaintingStyle.fill,
    );

    final outline = Path();
    for (final cell in shapeCells) {
      final center = metrics.offsetFor(cell);
      outline.addRect(
        Rect.fromCenter(
          center: center,
          width: metrics.cellSize * 0.92,
          height: metrics.cellSize * 0.92,
        ),
      );
    }
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFFD8CBB8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, metrics.cellSize * 0.04),
    );
  }

  List<Offset> _ropePointsAtProgress(
    Arrow arrow,
    _BoardMetrics metrics,
    double progress,
    int exitDistance,
  ) {
    if (progress <= 0) {
      return arrow.points.map(metrics.offsetFor).toList();
    }

    final totalSteps = exitDistance * progress;
    final completedSteps = totalSteps.floor().clamp(0, exitDistance);
    final fraction = totalSteps - completedSteps;
    if (fraction <= 0 || completedSteps >= exitDistance) {
      return arrow
          .pointsAtStep(completedSteps.clamp(0, exitDistance))
          .map(metrics.offsetFor)
          .toList();
    }

    final current = arrow.pointsAtStep(completedSteps);
    final next = arrow.pointsAtStep(completedSteps + 1);
    final length = current.length;

    // Each segment follows the one ahead, keeping bends orthogonal.
    return [
      for (var index = 0; index < length; index++)
        Offset.lerp(
          metrics.offsetFor(current[index]),
          metrics.offsetFor(
            index == length - 1 ? next[index] : current[index + 1],
          ),
          fraction,
        )!,
    ];
  }

  void _drawArrow(
    Canvas canvas,
    List<Offset> points,
    Direction direction,
    _BoardMetrics metrics,
    bool rejected,
  ) {
    if (points.length < 2) return;

    final color = rejected ? const Color(0xFFB5483A) : const Color(0xFF66584B);
    final lineWidth = math.max(3.0, metrics.cellSize * 0.14);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = lineWidth
        ..strokeCap = StrokeCap.butt
        ..strokeJoin = StrokeJoin.miter,
    );

    final head = points.last;
    final beforeHead = points[points.length - 2];
    final delta = head - beforeHead;
    final headDirection = delta.distance == 0
        ? Offset(direction.dCol.toDouble(), direction.dRow.toDouble())
        : Offset(delta.dx / delta.distance, delta.dy / delta.distance);
    final normal = Offset(-headDirection.dy, headDirection.dx);
    final tip = head + headDirection * metrics.cellSize * 0.34;
    final base = head - headDirection * metrics.cellSize * 0.12;
    final halfWidth = metrics.cellSize * 0.20;

    final arrowHead = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((base + normal * halfWidth).dx, (base + normal * halfWidth).dy)
      ..lineTo((base - normal * halfWidth).dx, (base - normal * halfWidth).dy)
      ..close();

    canvas.drawPath(arrowHead, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ArrowBoardPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.shapeCells != shapeCells ||
        oldDelegate.showShapeBackground != showShapeBackground ||
        oldDelegate.movingId != movingId ||
        oldDelegate.movingProgress != movingProgress ||
        oldDelegate.exitDistance != exitDistance ||
        oldDelegate.rejectedId != rejectedId;
  }
}

class _BoardMetrics {
  _BoardMetrics(Size size, Board board)
    : cellSize = math.min(size.width / board.cols, size.height / board.rows),
      origin = Offset(
        (size.width -
                math.min(size.width / board.cols, size.height / board.rows) *
                    board.cols) /
            2,
        (size.height -
                math.min(size.width / board.cols, size.height / board.rows) *
                    board.rows) /
            2,
      );

  final double cellSize;
  final Offset origin;

  Offset offsetFor(GridPoint point) {
    return origin +
        Offset((point.col + 0.5) * cellSize, (point.row + 0.5) * cellSize);
  }
}
