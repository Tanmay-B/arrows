import 'direction.dart';

class GridPoint {
  const GridPoint(this.row, this.col);

  final int row;
  final int col;

  GridPoint translate(Direction direction, [int distance = 1]) {
    return GridPoint(
      row + direction.dRow * distance,
      col + direction.dCol * distance,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GridPoint && other.row == row && other.col == col;

  @override
  int get hashCode => Object.hash(row, col);
}

/// A snake-shaped arrow represented from tail to arrowhead.
///
/// Adjacent points must be orthogonally connected. The final segment determines
/// the direction in which the pointer advances when tapped. The body follows
/// like a rope, vacating cells as the pointer moves.
class Arrow {
  const Arrow({required this.id, required this.points});

  final String id;
  final List<GridPoint> points;

  GridPoint get head => points.last;

  Direction get direction {
    final beforeHead = points[points.length - 2];
    final rowDelta = head.row - beforeHead.row;
    final colDelta = head.col - beforeHead.col;

    if (rowDelta < 0) return Direction.up;
    if (rowDelta > 0) return Direction.down;
    if (colDelta < 0) return Direction.left;
    return Direction.right;
  }

  /// Whether advancing the pointer one step would collide with this snake's body.
  bool collidesWithSelfOnNextStep() {
    if (points.length <= 2) return false;
    final nextHead = head.translate(direction);
    return points.sublist(1).contains(nextHead);
  }

  /// One rope step: the pointer advances and the body follows, tail vacating.
  Arrow advanceStep() {
    return Arrow(
      id: id,
      points: [
        ...points.skip(1),
        head.translate(direction),
      ],
    );
  }

  /// Grid positions of every segment after [step] rope advances from this shape.
  List<GridPoint> pointsAtStep(int step) {
    final length = points.length;
    return [
      for (var index = 0; index < length; index++)
        index + step < length
            ? points[index + step]
            : head.translate(direction, index + step - length + 1),
    ];
  }
}
