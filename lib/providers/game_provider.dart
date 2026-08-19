import 'package:flutter/foundation.dart';
import '../game/game_engine.dart';
import '../models/board.dart';
import '../models/level.dart';
import '../services/game_progress_store.dart';

enum GameStatus { playing, won, lost }

class GameProvider extends ChangeNotifier {
  GameProvider({GameEngine? engine}) : _engine = engine ?? const GameEngine();

  final GameEngine _engine;

  late Board _board;
  late LevelDef _level;
  int _levelIndex = 0;
  int _boardSession = 0;
  GameStatus _status = GameStatus.playing;
  bool _isAnimating = false;
  bool _isLoadingLevel = false;
  bool _showShapeBackground = true;
  int _lives = 3;
  String? _lastRejectedId;
  MoveSuccess? _pendingMove;
  String? _hintedArrowId;
  LevelDef? _preloadedLevel;
  int? _preloadedLevelIndex;
  int _lossGeneration = 0;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  int get lossGeneration => _lossGeneration;
  Board get board => _board;
  LevelDef get level => _level;
  int get levelIndex => _levelIndex;
  int get boardSession => _boardSession;
  int get levelCount => LevelCatalog.levelCount;
  GameStatus get status => _status;
  bool get isAnimating => _isAnimating;
  bool get isLoadingLevel => _isLoadingLevel;
  bool get showShapeBackground => _showShapeBackground;
  int get lives => _lives;
  String? get lastRejectedId => _lastRejectedId;
  String? get hintedArrowId => _hintedArrowId;
  MoveSuccess? get pendingMove => _pendingMove;
  Set<String> get movableIds => _engine.getMovableIds(_board).toSet();
  bool get hasNextLevel => _levelIndex < LevelCatalog.levelCount - 1;
  bool get isNextLevelReady =>
      hasNextLevel &&
      _preloadedLevelIndex == _levelIndex + 1 &&
      _preloadedLevel != null;
  bool get hasGameInProgress {
    if (_levelIndex > 0) return true;
    if (_status != GameStatus.playing) return true;
    if (_lives < 3) return true;
    if (_board.arrows.length < _level.arrows.length) return true;
    return false;
  }

  Future<void> restoreProgress() async {
    final saved = await GameProgressStore.load();
    if (saved != null) {
      await _restoreFromSave(saved);
    } else {
      loadLevel(0);
    }
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> saveProgress() => _persistProgress();

  Future<void> _restoreFromSave(SavedGameState saved) async {
    final safeIndex = saved.levelIndex.clamp(0, LevelCatalog.levelCount - 1);
    final level = LevelCatalog.isCached(safeIndex)
        ? LevelCatalog.byIndex(safeIndex)
        : await LevelCatalog.byIndexAsync(safeIndex);

    final validIds = saved.remainingArrowIds
        .where((id) => level.arrows.any((arrow) => arrow.id == id))
        .toList();

    if (validIds.isEmpty && saved.status == GameStatus.playing.name) {
      loadLevel(safeIndex);
      return;
    }

    _levelIndex = safeIndex;
    _level = level;
    _board = Board(
      rows: level.rows,
      cols: level.cols,
      arrows: {
        for (final arrow in level.arrows)
          if (validIds.contains(arrow.id)) arrow.id: arrow,
      },
    );
    _boardSession++;
    _status = _board.isWon
        ? GameStatus.won
        : GameStatus.values.asNameMap()[saved.status] ?? GameStatus.playing;
    _isAnimating = false;
    _showShapeBackground = true;
    _lives = saved.lives.clamp(0, 3);
    _lastRejectedId = null;
    _pendingMove = null;
    _hintedArrowId = null;
    _preloadedLevel = null;
    _preloadedLevelIndex = null;

    if (_status == GameStatus.won) {
      _preloadNextLevel();
    }
  }

  Future<void> startNewGame() async {
    await GameProgressStore.clear();
    loadLevel(0);
  }

  void _applyLevel(int index, LevelDef level) {
    _levelIndex = index;
    _level = level;
    _board = Board.fromLevel(_level);
    _boardSession++;
    _status = GameStatus.playing;
    _isAnimating = false;
    _showShapeBackground = true;
    _lives = 3;
    _lastRejectedId = null;
    _pendingMove = null;
    _hintedArrowId = null;
    _preloadedLevel = null;
    _preloadedLevelIndex = null;
    notifyListeners();
    _persistProgress();
  }

  void loadLevel(int index, {LevelDef? preloaded}) {
    final safeIndex = index.clamp(0, LevelCatalog.levelCount - 1);
    if (preloaded != null) {
      _applyLevel(safeIndex, preloaded);
      return;
    }

    if (LevelCatalog.isCached(safeIndex)) {
      _applyLevel(safeIndex, LevelCatalog.byIndex(safeIndex));
      return;
    }

    _applyLevel(safeIndex, LevelCatalog.byIndex(safeIndex));
  }

  void restart() => loadLevel(_levelIndex);

  void restoreLifeFromAd() {
    if (_status != GameStatus.lost) return;

    _lives = 1;
    _status = GameStatus.playing;
    _lastRejectedId = null;
    notifyListeners();
    _persistProgress();
  }

  Future<void> continueToNextLevel() async {
    if (!hasNextLevel) {
      restart();
      return;
    }

    final nextIndex = _levelIndex + 1;
    LevelDef level;

    if (_preloadedLevelIndex == nextIndex && _preloadedLevel != null) {
      level = _preloadedLevel!;
    } else {
      _isLoadingLevel = true;
      notifyListeners();
      try {
        level = await LevelCatalog.byIndexAsync(nextIndex);
      } finally {
        _isLoadingLevel = false;
      }
    }

    _applyLevel(nextIndex, level);
  }

  void _preloadNextLevel() {
    if (!hasNextLevel) return;
    final nextIndex = _levelIndex + 1;
    if (_preloadedLevelIndex == nextIndex) return;

    LevelCatalog.byIndexAsync(nextIndex).then((level) {
      if (_levelIndex + 1 == nextIndex) {
        _preloadedLevelIndex = nextIndex;
        _preloadedLevel = level;
        notifyListeners();
      }
    });
  }

  /// Returns the hinted arrow id, or null if no hint is available.
  String? revealHint() {
    if (_status != GameStatus.playing || _isAnimating) return null;

    for (final arrowId in _level.solution) {
      if (_board.arrows.containsKey(arrowId)) {
        _hintedArrowId = arrowId;
        notifyListeners();
        return arrowId;
      }
    }
    return null;
  }

  void clearHint() {
    if (_hintedArrowId == null) return;
    _hintedArrowId = null;
    notifyListeners();
  }

  /// Returns a successful move to animate, or null if rejected.
  MoveSuccess? tapArrow(String arrowId) {
    if (_isAnimating || _status != GameStatus.playing) return null;

    clearHint();
    final result = _engine.tryMove(_board, arrowId);
    if (result is MoveFailure) {
      _lastRejectedId = arrowId;
      _lives--;
      if (_lives <= 0) {
        _status = GameStatus.lost;
        _lossGeneration++;
      }
      notifyListeners();
      _persistProgress();
      return null;
    }

    final success = result as MoveSuccess;
    _isAnimating = true;
    _pendingMove = success;
    _lastRejectedId = null;
    return success;
  }

  void toggleShapeBackground() {
    _showShapeBackground = !_showShapeBackground;
    notifyListeners();
  }

  void clearRejected() {
    if (_lastRejectedId == null) return;
    _lastRejectedId = null;
    notifyListeners();
  }

  void completePendingMove() {
    final pending = _pendingMove;
    if (pending == null) return;

    _board = pending.board;
    _pendingMove = null;
    _isAnimating = false;

    if (_engine.isWon(_board)) {
      _status = GameStatus.won;
      _preloadNextLevel();
    }

    notifyListeners();
    _persistProgress();
  }

  Future<void> _persistProgress() async {
    if (!_isInitialized) return;

    await GameProgressStore.save(
      levelIndex: _levelIndex,
      remainingArrowIds: _board.arrows.keys.toList(),
      lives: _lives,
      status: _status.name,
    );
  }
}
