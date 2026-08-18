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
  String? _movingId;
  int _exitDistance = 0;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        )..addStatusListener((status) {
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
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();
    final board = provider.board;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = math.min(
          constraints.maxHeight,
          width * board.rows / board.cols,
        );
        final boardSize = Size(width, height);

        return Center(
          child: SizedBox.fromSize(
            size: boardSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: provider.status == GameStatus.playing
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
                  final progress = Curves.easeInCubic.transform(
                    _controller.value,
                  );
                  return CustomPaint(
                    painter: _ArrowBoardPainter(
                      board: board,
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
    required this.movingId,
    required this.movingProgress,
    required this.exitDistance,
    required this.rejectedId,
  });

  final Board board;
  final String? movingId;
  final double movingProgress;
  final int exitDistance;
  final String? rejectedId;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = _BoardMetrics(size, board);

    for (final arrow in board.arrows.values) {
      final points = arrow.id == movingId
          ? _ropePointsAtProgress(
              arrow,
              metrics,
              movingProgress,
              exitDistance,
            )
          : arrow.points.map(metrics.offsetFor).toList();
      _drawArrow(canvas, points, arrow.direction, metrics, arrow.id == rejectedId);
    }
  }

  List<Offset> _ropePointsAtProgress(
    Arrow arrow,
    _BoardMetrics metrics,
    double progress,
    int exitDistance,
  ) {
    final totalSteps = exitDistance * progress;
    final completedSteps = totalSteps.floor();
    final fraction = totalSteps - completedSteps;
    final fromPoints = arrow.pointsAtStep(completedSteps);
    final toPoints = arrow.pointsAtStep(completedSteps + 1);

    return [
      for (var index = 0; index < fromPoints.length; index++)
        Offset.lerp(
          metrics.offsetFor(fromPoints[index]),
          metrics.offsetFor(toPoints[index]),
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
    if (points.isEmpty) return;

    final color = rejected ? const Color(0xFFB5483A) : const Color(0xFF66584B);
    final lineWidth = math.max(2.3, metrics.cellSize * 0.105);
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
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final head = points.last;
    final directionOffset = Offset(
      direction.dCol.toDouble(),
      direction.dRow.toDouble(),
    );
    final normal = Offset(-directionOffset.dy, directionOffset.dx);
    final tip = head + directionOffset * metrics.cellSize * 0.34;
    final base = head - directionOffset * metrics.cellSize * 0.12;
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
