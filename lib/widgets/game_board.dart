import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/board.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import 'arrow_board_painter.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  static const _rejectFeedbackMs = 420;

  late final AnimationController _moveController;
  late final AnimationController _shakeController;
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
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _rejectFeedbackMs),
    );
  }

  double _shakeOffsetX() {
    final t = _shakeController.value;
    if (t == 0) return 0;
    return math.sin(t * math.pi * 7) * 9 * (1 - t);
  }

  @override
  void dispose() {
    _moveController.dispose();
    _shakeController.dispose();
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

    Future<void>.delayed(const Duration(seconds: 1), () async {
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
    final settings = context.read<SettingsProvider>();
    final result = provider.tapArrow(arrowId);

    if (result == null) {
      if (provider.lastRejectedId == arrowId) {
        if (settings.hapticsEnabled) {
          HapticFeedback.heavyImpact();
        }
        _shakeController.forward(from: 0);
        Future<void>.delayed(
          const Duration(milliseconds: _rejectFeedbackMs),
          () {
            if (mounted) provider.clearRejected();
          },
        );
      }
      return;
    }

    if (settings.hapticsEnabled) {
      HapticFeedback.selectionClick();
    }
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

        return AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeOffsetX(), 0),
              child: child,
            );
          },
          child: ClipRect(
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
                          painter: ArrowBoardPainter(
                            board: board,
                            shapeCells: shapeCells,
                            showShapeBackground: showShapeBackground,
                            movingId: _movingId,
                            movingProgress: progress,
                            exitDistance: _exitDistance,
                            rejectedId: provider.lastRejectedId,
                            hintedId: provider.hintedArrowId,
                          ),
                        );
                      },
                    ),
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
    final metrics = BoardMetrics(size, board);
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
