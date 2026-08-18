import 'package:flutter/foundation.dart';
import '../game/game_engine.dart';
import '../models/board.dart';
import '../models/level.dart';

enum GameStatus { playing, won, lost }

class GameProvider extends ChangeNotifier {
  GameProvider({GameEngine? engine}) : _engine = engine ?? const GameEngine() {
    loadLevel(0);
  }

  final GameEngine _engine;

  late Board _board;
  late LevelDef _level;
  int _levelIndex = 0;
  int _boardSession = 0;
  GameStatus _status = GameStatus.playing;
  bool _isAnimating = false;
  bool _showShapeBackground = true;
  int _lives = 3;
  String? _lastRejectedId;
  MoveSuccess? _pendingMove;

  Board get board => _board;
  LevelDef get level => _level;
  int get levelIndex => _levelIndex;
  int get boardSession => _boardSession;
  int get levelCount => LevelCatalog.levelCount;
  GameStatus get status => _status;
  bool get isAnimating => _isAnimating;
  bool get showShapeBackground => _showShapeBackground;
  int get lives => _lives;
  String? get lastRejectedId => _lastRejectedId;
  MoveSuccess? get pendingMove => _pendingMove;
  Set<String> get movableIds => _engine.getMovableIds(_board).toSet();

  void loadLevel(int index) {
    _levelIndex = index.clamp(0, LevelCatalog.levelCount - 1);
    _level = LevelCatalog.byIndex(_levelIndex);
    _board = Board.fromLevel(_level);
    _boardSession++;
    _status = GameStatus.playing;
    _isAnimating = false;
    _showShapeBackground = true;
    _lives = 3;
    _lastRejectedId = null;
    _pendingMove = null;
    notifyListeners();
  }

  void restart() => loadLevel(_levelIndex);

  void nextLevel() {
    if (_levelIndex < LevelCatalog.levelCount - 1) {
      loadLevel(_levelIndex + 1);
    }
  }

  /// Returns a successful move to animate, or null if rejected.
  MoveSuccess? tapArrow(String arrowId) {
    if (_isAnimating || _status != GameStatus.playing) return null;

    final result = _engine.tryMove(_board, arrowId);
    if (result is MoveFailure) {
      _lastRejectedId = arrowId;
      _lives--;
      if (_lives <= 0) {
        _status = GameStatus.lost;
      }
      notifyListeners();
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
    }

    notifyListeners();
  }
}
