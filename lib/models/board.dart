import 'arrow.dart';
import 'level.dart';

class Board {
  Board({required this.rows, required this.cols, required this.arrows});

  final int rows;
  final int cols;
  final Map<String, Arrow> arrows;

  factory Board.fromLevel(LevelDef level) {
    return Board(
      rows: level.rows,
      cols: level.cols,
      arrows: {for (final arrow in level.arrows) arrow.id: arrow},
    );
  }

  Board copy() {
    return Board(
      rows: rows,
      cols: cols,
      arrows: Map<String, Arrow>.from(arrows),
    );
  }

  bool inBounds(int row, int col) =>
      row >= 0 && row < rows && col >= 0 && col < cols;

  bool get isWon => arrows.isEmpty;

  Map<GridPoint, String> occupied({String? exceptArrowId}) {
    return {
      for (final arrow in arrows.values)
        if (arrow.id != exceptArrowId)
          for (final point in arrow.points) point: arrow.id,
    };
  }
}
