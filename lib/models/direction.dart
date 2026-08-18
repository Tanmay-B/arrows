enum Direction { up, down, left, right }

extension DirectionX on Direction {
  int get dRow {
    switch (this) {
      case Direction.up:
        return -1;
      case Direction.down:
        return 1;
      case Direction.left:
      case Direction.right:
        return 0;
    }
  }

  int get dCol {
    switch (this) {
      case Direction.left:
        return -1;
      case Direction.right:
        return 1;
      case Direction.up:
      case Direction.down:
        return 0;
    }
  }

  double get angleRadians {
    switch (this) {
      case Direction.up:
        return -1.5707963267948966; // -pi/2
      case Direction.right:
        return 0;
      case Direction.down:
        return 1.5707963267948966; // pi/2
      case Direction.left:
        return 3.141592653589793; // pi
    }
  }
}
