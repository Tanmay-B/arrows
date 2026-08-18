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

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  late final AnimationController _moveController;
  AnimationController? _previewController;
  final TransformationController _transformController =
      TransformationController();

  String? _movingId;
  int _exitDistance = 0;
  int? _previewBoardSession;
  int _previewGeneration = 0;
  bool _previewActive = false;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          context.read<GameProvider>().completePendingMove();
          setState(() {
            _movingId = null;
            _exitDistance = 0;
          });
          _moveController.reset();
        }
      });
  }

  @override
  void dispose() {
    _moveController.dispose();
    _previewController?.dispose();
    _transformController.dispose();
    super.dispose();
  }

  Matrix4 _matrixForScale(double scale, Size viewport, Size boardSize) {
    final dx = (viewport.width - boardSize.width * scale) / 2;
    final dy = (viewport.height - boardSize.height * scale) / 2;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  bool _hasValidViewport(Size viewport, Size boardSize) {
    return viewport.width > 0 &&
        viewport.height > 0 &&
        boardSize.width > 0 &&
        boardSize.height > 0;
  }

  ({double fitScale, double minScale, double maxScale})? _zoomLimits(
    Size viewport,
    Size boardSize,
  ) {
    if (!_hasValidViewport(viewport, boardSize)) return null;

    final fitScale = math.min(
      viewport.width / boardSize.width,
      viewport.height / boardSize.height,
    );
    if (!fitScale.isFinite || fitScale <= 0) return null;

    final minScale = math.max(0.01, fitScale * 0.8);
    final maxScale = math.max(
      minScale * 2,
      math.max(4.0, 2 / fitScale),
    );
    return (fitScale: fitScale, minScale: minScale, maxScale: maxScale);
  }

  void _startLevelPreview({
    required int boardSession,
    required Size viewport,
    required Size boardSize,
    required double minScale,
    required double maxScale,
    required double fitScale,
  }) {
    if (_previewBoardSession == boardSession) return;
    if (!_hasValidViewport(viewport, boardSize)) return;
    if (minScale <= 0 || maxScale <= minScale) return;

    _previewBoardSession = boardSession;

    final generation = ++_previewGeneration;
    _previewController?.dispose();
    _previewController = null;

    final zoomOutScale = minScale;
    final defaultScale = math
        .min(1.0, fitScale * 2.2)
        .clamp(minScale * 1.15, maxScale * 0.85);

    _transformController.value = _matrixForScale(
      zoomOutScale,
      viewport,
      boardSize,
    );
    setState(() => _previewActive = true);

    Future<void>.delayed(const Duration(seconds: 2), () async {
      if (!mounted || generation != _previewGeneration) return;

      _previewController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 750),
      );

      final animation = CurvedAnimation(
        parent: _previewController!,
        curve: Curves.easeInOutCubic,
      );

      animation.addListener(() {
        final scale =
            zoomOutScale + (defaultScale - zoomOutScale) * animation.value;
        _transformController.value = _matrixForScale(
          scale,
          viewport,
          boardSize,
        );
      });

      _previewController!.addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _previewActive = false);
        }
      });

      await _previewController!.forward();
    });
  }

  void _tapArrow(String arrowId) {
    if (_previewActive) return;

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
    _moveController.duration = Duration(
      milliseconds: 90 + result.exitDistance * 28,
    );
    _moveController.forward(from: 0);
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
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final zoom = _zoomLimits(viewport, boardSize);
        if (zoom == null) {
          return const SizedBox.shrink();
        }

        if (_previewBoardSession != provider.boardSession) {
          _transformController.value = _matrixForScale(
            zoom.minScale,
            viewport,
            boardSize,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _startLevelPreview(
              boardSession: provider.boardSession,
              viewport: viewport,
              boardSize: boardSize,
              minScale: zoom.minScale,
              maxScale: zoom.maxScale,
              fitScale: zoom.fitScale,
            );
          });
        }

        return ClipRect(
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: InteractiveViewer(
              transformationController: _transformController,
              constrained: false,
              minScale: zoom.minScale,
              maxScale: zoom.maxScale,
              panEnabled: !_previewActive,
              scaleEnabled: !_previewActive,
              boundaryMargin: const EdgeInsets.all(120),
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: boardSize.width,
                height: boardSize.height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp:
                      !_previewActive &&
                          provider.status == GameStatus.playing &&
                          _movingId == null
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
                    animation: _moveController,
                    builder: (context, _) {
                      final progress = _moveController.value;
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
