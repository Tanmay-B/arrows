import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_engine.dart';
import '../models/board.dart';
import '../models/level.dart';
import 'arrow_board_painter.dart';

/// Faded background demo that auto-solves a puzzle loop on the home screen.
class HomePuzzleAutoplay extends StatefulWidget {
  const HomePuzzleAutoplay({super.key, this.levelIndex = 2});

  final int levelIndex;

  @override
  State<HomePuzzleAutoplay> createState() => _HomePuzzleAutoplayState();
}

class _HomePuzzleAutoplayState extends State<HomePuzzleAutoplay>
    with SingleTickerProviderStateMixin {
  static const _cellSize = 28.0;
  static const _engine = GameEngine();
  static const _exitBaseMs = 180;
  static const _msPerExitStep = 52;
  static const _pauseBeforeMoveMs = 420;
  static const _pauseAfterMoveMs = 360;

  late final AnimationController _moveController;

  LevelDef? _level;
  Board? _board;
  List<String> _solution = [];
  int _solutionIndex = 0;
  String? _movingId;
  int _exitDistance = 0;
  Board? _pendingBoard;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _completeMove();
        }
      });
    _loadDemoLevel();
  }

  @override
  void dispose() {
    _moveController.dispose();
    super.dispose();
  }

  Future<void> _loadDemoLevel() async {
    setState(() => _loading = true);
    final level = await LevelCatalog.byIndexAsync(widget.levelIndex);
    if (!mounted) return;

    setState(() {
      _level = level;
      _board = Board.fromLevel(level);
      _solution = List<String>.from(level.solution);
      _solutionIndex = 0;
      _movingId = null;
      _exitDistance = 0;
      _pendingBoard = null;
      _loading = false;
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleNextMove();
    });
  }

  void _scheduleNextMove({Duration? delay}) {
    Future<void>.delayed(
      delay ?? const Duration(milliseconds: _pauseBeforeMoveMs),
      () {
        if (!mounted || _loading) return;
        _playNextMove();
      },
    );
  }

  void _playNextMove() {
    final board = _board;
    if (board == null) return;

    if (board.isWon) {
      _loadDemoLevel();
      return;
    }

    if (_movingId != null) return;

    while (_solutionIndex < _solution.length &&
        !board.arrows.containsKey(_solution[_solutionIndex])) {
      _solutionIndex++;
    }

    MoveSuccess? success;
    if (_solutionIndex < _solution.length) {
      final result = _engine.tryMove(board, _solution[_solutionIndex]);
      if (result is MoveSuccess) {
        success = result;
      } else {
        _solutionIndex++;
        _playNextMove();
        return;
      }
    } else {
      final movable = _engine.getMovableIds(board);
      if (movable.isEmpty) {
        _loadDemoLevel();
        return;
      }
      final result = _engine.tryMove(board, movable.first);
      if (result is! MoveSuccess) {
        _loadDemoLevel();
        return;
      }
      success = result;
    }

    _pendingBoard = success.board;
    setState(() {
      _movingId = success!.arrowId;
      _exitDistance = success.exitDistance;
    });
    _moveController.duration = Duration(
      milliseconds: _exitBaseMs + success.exitDistance * _msPerExitStep,
    );
    _moveController.forward(from: 0);
  }

  void _completeMove() {
    if (_pendingBoard == null) return;

    setState(() {
      _board = _pendingBoard;
      _pendingBoard = null;
      _movingId = null;
      _exitDistance = 0;
      _solutionIndex++;
    });
    _moveController.reset();
    _scheduleNextMove(
      delay: const Duration(milliseconds: _pauseAfterMoveMs),
    );
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
    final level = _level;

    if (_loading || board == null || level == null) {
      return const SizedBox.expand();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final boardSize = Size(
          board.cols * _cellSize,
          board.rows * _cellSize,
        );
        final scaleX = viewport.width / boardSize.width;
        final scaleY = viewport.height / boardSize.height;
        final scale = math.max(scaleX, scaleY);

        return Center(
          child: Transform.scale(
            scale: scale,
            child: SizedBox(
              width: boardSize.width,
              height: boardSize.height,
              child: AnimatedBuilder(
                animation: _moveController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: ArrowBoardPainter(
                      board: board,
                      shapeCells: level.shapeCells,
                      showShapeBackground: true,
                      movingId: _movingId,
                      movingProgress: _moveController.value,
                      exitDistance: _exitDistance,
                      hintedId: _movingId,
                      fade: 0.62,
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
}
