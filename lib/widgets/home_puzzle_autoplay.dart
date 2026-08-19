import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../game/game_engine.dart';
import '../models/board.dart';
import '../models/level.dart';
import 'arrow_board_painter.dart';

/// Faded background demo that auto-solves a puzzle loop on the home screen.
class HomePuzzleAutoplay extends StatefulWidget {
  const HomePuzzleAutoplay({
    super.key,
    this.levelIndex = 2,
    this.startDelay = Duration.zero,
    this.onReady,
  });

  final int levelIndex;
  final Duration startDelay;
  final VoidCallback? onReady;

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
  bool _readyNotified = false;

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

    if (!_readyNotified) {
      _readyNotified = true;
      widget.onReady?.call();
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scheduleNextMove(delay: widget.startDelay);
      }
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

        return ClipRect(
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: FittedBox(
              fit: BoxFit.cover,
              alignment: Alignment.center,
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
                        fade: 0.9,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Three stacked autoplay boards that cover the home screen background.
class HomePuzzleBackground extends StatelessWidget {
  const HomePuzzleBackground({super.key});

  static const _levelIndices = [2, 7, 14];
  static const _startDelays = [
    Duration.zero,
    Duration(milliseconds: 900),
    Duration(milliseconds: 1800),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < _levelIndices.length; i++)
          Expanded(
            child: _FadingHomePuzzleTile(
              levelIndex: _levelIndices[i],
              startDelay: _startDelays[i],
            ),
          ),
      ],
    );
  }
}

class _FadingHomePuzzleTile extends StatefulWidget {
  const _FadingHomePuzzleTile({
    required this.levelIndex,
    required this.startDelay,
  });

  final int levelIndex;
  final Duration startDelay;

  @override
  State<_FadingHomePuzzleTile> createState() => _FadingHomePuzzleTileState();
}

class _FadingHomePuzzleTileState extends State<_FadingHomePuzzleTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _handleReady() {
    if (_fadeController.isAnimating || _fadeController.isCompleted) return;
    _fadeController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
      child: ClipRect(
        child: HomePuzzleAutoplay(
          levelIndex: widget.levelIndex,
          startDelay: widget.startDelay,
          onReady: _handleReady,
        ),
      ),
    );
  }
}
