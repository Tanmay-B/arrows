import 'dart:math' as math;

import '../models/arrow.dart';

/// Playable cell mask that gives each level a distinct silhouette.
class LevelShape {
  const LevelShape({
    required this.id,
    required this.displayName,
    required this.rows,
    required this.cols,
    required this.cells,
  });

  final String id;
  final String displayName;
  final int rows;
  final int cols;
  final Set<GridPoint> cells;

  bool contains(GridPoint point) => cells.contains(point);

  /// Deterministic unique shape for every level index.
  factory LevelShape.forLevel(int levelIndex, int size) {
    final kind = levelIndex % _builders.length;
    final rotation = (levelIndex ~/ _builders.length) % 4;
    final mirror = (levelIndex ~/ (_builders.length * 4)) % 2 == 1;
    var raw = _thicken(_builders[kind](size), size);
    if (_hollowKinds.contains(kind)) {
      raw = _thicken(raw, size);
    }
    if (raw.length < size * size * 0.42) {
      raw = _thicken(raw, size);
    }
    final cells = {
      for (final point in raw)
        _transform(point, size, rotation, mirror),
    };
    return LevelShape(
      id: '${_names[kind]}_${rotation}_$mirror',
      displayName: _names[kind],
      rows: size,
      cols: size,
      cells: cells,
    );
  }

  static GridPoint _transform(
    GridPoint point,
    int size,
    int rotation,
    bool mirror,
  ) {
    var row = point.row;
    var col = point.col;
    if (mirror) col = size - 1 - col;
    for (var turn = 0; turn < rotation; turn++) {
      final nextRow = col;
      final nextCol = size - 1 - row;
      row = nextRow;
      col = nextCol;
    }
    return GridPoint(row, col);
  }

  static Set<GridPoint> _thicken(Set<GridPoint> cells, int size) {
    final thickened = {...cells};
    for (final point in cells) {
      for (final delta in const [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        final neighbor = GridPoint(point.row + delta[0], point.col + delta[1]);
        if (neighbor.row >= 0 &&
            neighbor.row < size &&
            neighbor.col >= 0 &&
            neighbor.col < size) {
          thickened.add(neighbor);
        }
      }
    }
    return thickened;
  }
}

const _hollowKinds = {1, 10, 12, 13, 14, 18, 19, 22};

typedef _ShapeBuilder = Set<GridPoint> Function(int size);

const _names = [
  'Diamond',
  'Orbit',
  'Cross',
  'Heart',
  'Star',
  'Hourglass',
  'Hexagon',
  'Chevron',
  'Spiral',
  'Wave',
  'Frame',
  'Crescent',
  'Arrow',
  'Ladder',
  'Bridge',
  'Castle',
  'Flower',
  'Lightning',
  'Maze',
  'Ribbon',
  'Shield',
  'Tower',
  'Vortex',
  'Zigzag',
];

final _builders = <_ShapeBuilder>[
  _diamond,
  _ring,
  _cross,
  _heart,
  _star,
  _hourglass,
  _hexagon,
  _chevron,
  _spiral,
  _wave,
  _frame,
  _crescent,
  _arrowGlyph,
  _ladder,
  _bridge,
  _castle,
  _flower,
  _lightning,
  _maze,
  _ribbon,
  _shield,
  _tower,
  _vortex,
  _zigzag,
];

Set<GridPoint> _all(int size) {
  return {
    for (var row = 0; row < size; row++)
      for (var col = 0; col < size; col++) GridPoint(row, col),
  };
}

double _center(int size) => (size - 1) / 2.0;

double _dist(GridPoint point, double centerRow, double centerCol) {
  final dx = point.col - centerCol;
  final dy = point.row - centerRow;
  return math.sqrt(dx * dx + dy * dy);
}

Set<GridPoint> _diamond(int size) {
  final center = _center(size);
  final radius = size * 0.46;
  return {
    for (final point in _all(size))
      if ((point.row - center).abs() + (point.col - center).abs() <= radius)
        point,
  };
}

Set<GridPoint> _ring(int size) {
  final center = _center(size);
  final outer = size * 0.47;
  final inner = size * 0.22;
  return {
    for (final point in _all(size))
      if (_dist(point, center, center) <= outer &&
          _dist(point, center, center) >= inner)
        point,
  };
}

Set<GridPoint> _cross(int size) {
  final mid = size ~/ 2;
  final arm = (size * 0.16).ceil().clamp(1, 4);
  return {
    for (final point in _all(size))
      if ((point.row - mid).abs() <= arm || (point.col - mid).abs() <= arm)
        point,
  };
}

Set<GridPoint> _heart(int size) {
  final center = _center(size);
  return {
    for (final point in _all(size))
      if (_heartInside(point.row.toDouble(), point.col.toDouble(), center, size))
        point,
  };
}

bool _heartInside(double row, double col, double center, int size) {
  final x = (col - center) / (size * 0.34);
  final y = (center - row) / (size * 0.34) + 0.2;
  final value = x * x + y * y - 1;
  return value * value * value - x * x * y * y * y <= 0.08;
}

Set<GridPoint> _star(int size) {
  final center = _center(size);
  return {
    for (final point in _all(size))
      if (_starInside(point.row.toDouble(), point.col.toDouble(), center, size))
        point,
  };
}

bool _starInside(double row, double col, double center, int size) {
  final dx = col - center;
  final dy = center - row;
  final angle = math.atan2(dy, dx);
  final radius = size * 0.22 * (1 + 0.55 * math.cos(5 * angle).abs());
  return dx * dx + dy * dy <= radius * radius;
}

Set<GridPoint> _hourglass(int size) {
  final center = _center(size);
  return {
    for (final point in _all(size))
      if ((point.row - center).abs() <=
          (point.col - center).abs() * 0.55 + size * 0.18)
        point,
  };
}

Set<GridPoint> _hexagon(int size) {
  final center = _center(size);
  return {
    for (final point in _all(size))
      if (_hexInside(point.row.toDouble(), point.col.toDouble(), center, size))
        point,
  };
}

bool _hexInside(double row, double col, double center, int size) {
  final dx = (col - center).abs() / (size * 0.42);
  final dy = (row - center).abs() / (size * 0.36);
  return dx + dy * 0.65 <= 1.0;
}

Set<GridPoint> _chevron(int size) {
  final cells = <GridPoint>{};
  final thickness = (size * 0.14).ceil().clamp(2, 4);
  for (var row = 0; row < size; row++) {
    for (var col = 0; col < size; col++) {
      final leftEdge = (row * 0.55).floor();
      final rightEdge = size - 1 - leftEdge;
      if ((col - leftEdge).abs() <= thickness ||
          (col - rightEdge).abs() <= thickness) {
        cells.add(GridPoint(row, col));
      }
    }
  }
  return cells;
}

Set<GridPoint> _spiral(int size) {
  final cells = <GridPoint>{};
  var row = 0;
  var col = 0;
  var dir = 0;
  var steps = size - 1;
  var stepCount = 0;
  var leg = 0;
  const deltas = [
    [0, 1],
    [1, 0],
    [0, -1],
    [-1, 0],
  ];
  for (var index = 0; index < size * size ~/ 2; index++) {
    if (row >= 0 && row < size && col >= 0 && col < size) {
      cells.add(GridPoint(row, col));
    }
    row += deltas[dir][0];
    col += deltas[dir][1];
    stepCount++;
    if (stepCount >= steps) {
      stepCount = 0;
      dir = (dir + 1) % 4;
      leg++;
      if (leg.isEven) steps--;
    }
  }
  return cells;
}

Set<GridPoint> _wave(int size) {
  return {
    for (final point in _all(size))
      if ((point.col +
                  (math.sin(point.row * 1.4) * 2.2).round() -
                  size ~/ 2)
              .abs() <=
          (size * 0.16).ceil())
        point,
  };
}

Set<GridPoint> _frame(int size) {
  final margin = (size * 0.12).ceil().clamp(1, 3);
  return {
    for (final point in _all(size))
      if (point.row < margin ||
          point.col < margin ||
          point.row >= size - margin ||
          point.col >= size - margin)
        point,
  };
}

Set<GridPoint> _crescent(int size) {
  final center = _center(size);
  return {
    for (final point in _all(size))
      if (_dist(point, center, center) <= size * 0.44 &&
          _dist(point, center, center - size * 0.18) >= size * 0.28)
        point,
  };
}

Set<GridPoint> _arrowGlyph(int size) {
  final cells = <GridPoint>{};
  final shaft = size ~/ 2;
  for (var row = 0; row < size; row++) {
    for (var col = 0; col < size; col++) {
      if ((col - shaft).abs() <= 1) cells.add(GridPoint(row, col));
      if (row <= size ~/ 3 && (col - row).abs() <= 1) {
        cells.add(GridPoint(row, col));
      }
      if (row <= size ~/ 3 && (col - (size - 1 - row)).abs() <= 1) {
        cells.add(GridPoint(row, col));
      }
    }
  }
  return cells;
}

Set<GridPoint> _ladder(int size) {
  final cells = <GridPoint>{};
  final left = size ~/ 4;
  final right = size - 1 - left;
  for (var row = 0; row < size; row++) {
    cells.add(GridPoint(row, left));
    cells.add(GridPoint(row, right));
    if (row.isEven) {
      for (var col = left; col <= right; col++) {
        cells.add(GridPoint(row, col));
      }
    }
  }
  return cells;
}

Set<GridPoint> _bridge(int size) {
  final cells = <GridPoint>{};
  final top = size ~/ 4;
  final bottom = size - 1 - top;
  for (var col = 0; col < size; col++) {
    cells.add(GridPoint(top, col));
    cells.add(GridPoint(bottom, col));
  }
  for (var row = top; row <= bottom; row++) {
    cells.add(GridPoint(row, size ~/ 2));
  }
  return cells;
}

Set<GridPoint> _castle(int size) {
  final cells = <GridPoint>{};
  final base = size - 1 - size ~/ 5;
  for (var col = 0; col < size; col++) {
    cells.add(GridPoint(base, col));
  }
  for (final tower in [size ~/ 5, size - 1 - size ~/ 5]) {
    for (var row = size ~/ 5; row <= base; row++) {
      for (var col = tower - 1; col <= tower + 1; col++) {
        if (col >= 0 && col < size) cells.add(GridPoint(row, col));
      }
    }
  }
  return cells;
}

Set<GridPoint> _flower(int size) {
  final center = _center(size);
  return {
    for (final point in _all(size))
      if (_flowerInside(point.row.toDouble(), point.col.toDouble(), center, size))
        point,
  };
}

bool _flowerInside(double row, double col, double center, int size) {
  final dx = col - center;
  final dy = center - row;
  final angle = math.atan2(dy, dx);
  final petal = size * 0.17 * (1 + 0.75 * math.cos(2 * angle).abs());
  return dx * dx + dy * dy <= petal * petal ||
      _dist(GridPoint(row.round(), col.round()), center, center) <= size * 0.08;
}

Set<GridPoint> _lightning(int size) {
  final cells = <GridPoint>{};
  var row = 0;
  var col = size ~/ 2;
  while (row < size && col >= 0 && col < size) {
    cells.add(GridPoint(row, col));
    if (row.isEven) {
      row++;
      col--;
    } else {
      row++;
      col += 2;
    }
  }
  for (final point in cells.toList()) {
    if (point.col + 1 < size) cells.add(GridPoint(point.row, point.col + 1));
  }
  return cells;
}

Set<GridPoint> _maze(int size) {
  return {
    for (final point in _all(size))
      if (point.row.isEven || point.col.isEven) point,
  };
}

Set<GridPoint> _ribbon(int size) {
  return {
    for (final point in _all(size))
      if ((point.row - point.col).abs() <= (size * 0.14).ceil() ||
          ((size - 1 - point.row) - point.col).abs() <= (size * 0.14).ceil())
        point,
  };
}

Set<GridPoint> _shield(int size) {
  final center = _center(size);
  return {
    for (final point in _all(size))
      if (_shieldInside(point.row.toDouble(), point.col.toDouble(), center, size))
        point,
  };
}

bool _shieldInside(double row, double col, double center, int size) {
  final dx = (col - center).abs() / (size * 0.4);
  final top = row / (size * 0.32);
  final bottom = (size - 1 - row) / (size * 0.42);
  if (row < size * 0.35) return dx * dx + top * top <= 1.0;
  return dx <= 1.0 - bottom * 0.35;
}

Set<GridPoint> _tower(int size) {
  final cells = <GridPoint>{};
  final width = (size * 0.22).ceil().clamp(2, 5);
  final left = size ~/ 2 - width ~/ 2;
  for (var row = 0; row < size; row++) {
    for (var col = left; col < left + width; col++) {
      cells.add(GridPoint(row, col));
    }
  }
  for (var col = left - 1; col <= left + width; col++) {
    if (col >= 0 && col < size) cells.add(GridPoint(size ~/ 5, col));
  }
  return cells;
}

Set<GridPoint> _vortex(int size) {
  final center = _center(size);
  return {
    for (final point in _all(size))
      if (_vortexInside(point.row.toDouble(), point.col.toDouble(), center, size))
        point,
  };
}

bool _vortexInside(double row, double col, double center, int size) {
  final dx = col - center;
  final dy = center - row;
  final angle = math.atan2(dy, dx);
  final radius = math.sqrt(dx * dx + dy * dy);
  final spiral = size * 0.12 + size * 0.03 * (angle * 2 + radius * 0.35);
  return radius <= spiral && radius >= spiral - size * 0.12;
}

Set<GridPoint> _zigzag(int size) {
  final cells = <GridPoint>{};
  final amplitude = (size * 0.22).ceil();
  for (var row = 0; row < size; row++) {
    final col = size ~/ 2 + (row.isEven ? amplitude : -amplitude);
    for (var offset = -1; offset <= 1; offset++) {
      final c = col + offset;
      if (c >= 0 && c < size) cells.add(GridPoint(row, c));
    }
  }
  return cells;
}
