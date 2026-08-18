import '../models/arrow.dart';
import '../models/board.dart';

sealed class MoveResult {
  const MoveResult();
}

class MoveSuccess extends MoveResult {
  const MoveSuccess({
    required this.arrowId,
    required this.exitDistance,
    required this.board,
  });

  final String arrowId;
  final int exitDistance;
  final Board board;
}

class MoveFailure extends MoveResult {
  const MoveFailure(this.reason);

  final MoveFailReason reason;
}

enum MoveFailReason { notFound, blocked, animating }

/// Pure game engine — no Flutter imports.
class GameEngine {
  const GameEngine();

  bool canMove(Board board, String arrowId) {
    final arrow = board.arrows[arrowId];
    if (arrow == null) return false;
    return _pathClear(board, arrow);
  }

  List<String> getMovableIds(Board board) {
    return board.arrows.keys.where((id) => canMove(board, id)).toList();
  }

  MoveResult tryMove(Board board, String arrowId) {
    final arrow = board.arrows[arrowId];
    if (arrow == null) {
      return const MoveFailure(MoveFailReason.notFound);
    }

    final exitDistance = _exitDistance(board, arrow);
    if (exitDistance == null) {
      return const MoveFailure(MoveFailReason.blocked);
    }

    final next = board.copy();
    next.arrows.remove(arrowId);

    return MoveSuccess(
      arrowId: arrowId,
      exitDistance: exitDistance,
      board: next,
    );
  }

  bool isWon(Board board) => board.isWon;

  bool _pathClear(Board board, Arrow arrow) {
    return _exitDistance(board, arrow) != null;
  }

  /// Simulates rope steps until the pointer path is blocked or fully exited.
  int? _exitDistance(Board board, Arrow arrow) {
    final occupied = board.occupied(exceptArrowId: arrow.id);
    final maxSteps = board.rows + board.cols + arrow.points.length;
    var current = arrow;

    for (var step = 1; step <= maxSteps; step++) {
      if (current.collidesWithSelfOnNextStep()) {
        return null;
      }

      final nextHead = current.head.translate(current.direction);
      if (board.inBounds(nextHead.row, nextHead.col) &&
          occupied.containsKey(nextHead)) {
        return null;
      }

      current = current.advanceStep();
      if (current.points.every((point) => !board.inBounds(point.row, point.col))) {
        return step;
      }
    }

    return null;
  }
}
