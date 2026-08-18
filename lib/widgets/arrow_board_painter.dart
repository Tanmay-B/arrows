import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/arrow.dart';
import '../models/board.dart';
import '../models/direction.dart';

class ArrowBoardPainter extends CustomPainter {
  ArrowBoardPainter({
    required this.board,
    required this.shapeCells,
    required this.showShapeBackground,
    required this.movingId,
    required this.movingProgress,
    required this.exitDistance,
    this.rejectedId,
    this.hintedId,
    this.fade = 1,
  });

  final Board board;
  final Set<GridPoint> shapeCells;
  final bool showShapeBackground;
  final String? movingId;
  final double movingProgress;
  final int exitDistance;
  final String? rejectedId;
  final String? hintedId;
  final double fade;

  @override
  void paint(Canvas canvas, Size size) {
    final metrics = BoardMetrics(size, board);
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
        rejected: arrow.id == rejectedId,
        hinted: arrow.id == hintedId,
      );
    }
  }

  void _drawShape(Canvas canvas, BoardMetrics metrics) {
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
        ..color = Color.lerp(
          const Color(0xFFEDE4D8),
          Colors.white,
          1 - fade,
        )!
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
        ..color = Color.lerp(
          const Color(0xFFD8CBB8),
          Colors.white,
          1 - fade,
        )!
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, metrics.cellSize * 0.04),
    );
  }

  List<Offset> _ropePointsAtProgress(
    Arrow arrow,
    BoardMetrics metrics,
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
    BoardMetrics metrics, {
    required bool rejected,
    required bool hinted,
  }) {
    if (points.length < 2) return;

    final baseColor = rejected
        ? const Color(0xFFB5483A)
        : hinted
        ? const Color(0xFF2E9B6A)
        : const Color(0xFF66584B);
    final color = Color.lerp(baseColor, Colors.white, 1 - fade)!;
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
  bool shouldRepaint(covariant ArrowBoardPainter oldDelegate) {
    return oldDelegate.board != board ||
        oldDelegate.shapeCells != shapeCells ||
        oldDelegate.showShapeBackground != showShapeBackground ||
        oldDelegate.movingId != movingId ||
        oldDelegate.movingProgress != movingProgress ||
        oldDelegate.exitDistance != exitDistance ||
        oldDelegate.rejectedId != rejectedId ||
        oldDelegate.hintedId != hintedId ||
        oldDelegate.fade != fade;
  }
}

class BoardMetrics {
  BoardMetrics(Size size, Board board)
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
