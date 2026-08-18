import 'dart:math';

import '../models/arrow.dart';
import '../models/direction.dart';
import '../models/level_definition.dart';
import 'level_shape.dart';

/// Deterministic generator for dense, guaranteed-solvable snake-arrow puzzles.
///
/// Snakes are inserted in reverse solution order inside a unique level shape.
/// Every inserted snake can escape through the existing layout, so removing them
/// in reverse insertion order always clears the generated board.
class LevelGenerator {
  const LevelGenerator();

  LevelDef generate(int levelIndex) {
    final config = _DifficultyConfig.forLevel(levelIndex);
    final shape = LevelShape.forLevel(levelIndex, config.size);
    _GeneratedLayout? best;
    _GeneratedLayout? bestConstrained;

    final restartCount = levelIndex >= 750
        ? 6
        : levelIndex < 100
        ? 6
        : 4;
    for (var restart = 0; restart < restartCount; restart++) {
      final random = Random(_seedFor(levelIndex, restart));
      final layout = _buildLayout(random, config, shape);
      if (layout == null) continue;

      if (_layoutScore(layout) > _layoutScore(best)) {
        best = layout;
      }

      if (layout.initialMovableCount <= config.maxInitialMovable &&
          layout.shapeCoverage >= config.minShapeCoverage - 0.04) {
        if (_layoutScore(layout, preferFewMovable: true) >
            _layoutScore(bestConstrained, preferFewMovable: true)) {
          bestConstrained = layout;
        }
      }

      if (layout.arrows.length >= config.minArrowCount &&
          layout.initialMovableCount <= config.maxInitialMovable &&
          layout.shapeCoverage >= config.minShapeCoverage) {
        return _toLevel(levelIndex, config, shape, layout);
      }
    }

    var fallback = bestConstrained != null &&
            bestConstrained.arrows.length >= config.minArrowCount - 6
        ? bestConstrained
        : best;
    if (fallback == null) {
      throw StateError('Unable to generate level ${levelIndex + 1}');
    }
    var selected = fallback;
    if (selected.arrows.length < config.minArrowCount - 6) {
      final relaxed = config.relaxed();
      for (var restart = 0; restart < 4; restart++) {
        final random = Random(_seedFor(levelIndex, restartCount + restart));
        final layout = _buildLayout(random, relaxed, shape);
        if (layout == null) continue;
        if (_layoutScore(layout) > _layoutScore(selected)) {
          selected = layout;
        }
        if (layout.arrows.length >= config.minArrowCount - 6) {
          break;
        }
      }
    }
    return _toLevel(levelIndex, config, shape, selected);
  }

  int _layoutScore(_GeneratedLayout? layout, {bool preferFewMovable = false}) {
    if (layout == null) return -1;
    final movableWeight = preferFewMovable ? 80 : 40;
    return layout.arrows.length * 100 -
        layout.initialMovableCount * movableWeight +
        (layout.shapeCoverage * 80).round();
  }

  LevelDef _toLevel(
    int levelIndex,
    _DifficultyConfig config,
    LevelShape shape,
    _GeneratedLayout layout,
  ) {
    return LevelDef(
      id: '${levelIndex + 1}',
      name: '${shape.displayName} · ${_levelName(levelIndex)}',
      rows: config.size,
      cols: config.size,
      arrows: List.unmodifiable(layout.arrows),
      shapeName: shape.displayName,
      shapeCells: Set.unmodifiable(shape.cells),
      difficulty: config.difficulty,
      solution: List.unmodifiable(
        layout.arrows.reversed.map((arrow) => arrow.id),
      ),
    );
  }

  _GeneratedLayout? _buildLayout(
    Random random,
    _DifficultyConfig config,
    LevelShape shape,
  ) {
    final arrows = <Arrow>[];
    final occupied = <GridPoint>{};
    var movable = <Arrow>[];

    var consecutiveFailures = 0;

    for (var index = 0; index < config.arrowCount; index++) {
      _ScoredCandidate? bestCandidate;
      final needsBlocker = movable.isNotEmpty && index >= 1;
      final emptyShapeCells = shape.cells.difference(occupied);
      final blockingCells = <GridPoint>{
        for (final arrow in movable)
          ..._sweptCells(
            arrow,
            config.size,
          ).where((point) => !occupied.contains(point) && shape.contains(point)),
      };
      final safeCells = {
        for (final direction in Direction.values)
          direction: _safeCells(direction, occupied, shape),
      };

      for (var attempt = 0; attempt < 160; attempt++) {
        final candidate = _randomArrow(
          random,
          'a${index + 1}',
          config,
          shape,
          blockingCells,
          safeCells,
          emptyShapeCells,
          strict: attempt < 96,
        );
        if (candidate == null ||
            candidate.points.any(occupied.contains) ||
            !_canExit(candidate, occupied, config.size)) {
          continue;
        }

        final withCandidate = {...occupied, ...candidate.points};
        final blockedCount = movable
            .where(
              (arrow) => !_canExit(
                arrow,
                withCandidate.difference(arrow.points.toSet()),
                config.size,
              ),
            )
            .length;
        final bends = _bendCount(candidate);
        final shapeFill = candidate.points.where(shape.contains).length;
        final score =
            blockedCount * 180 +
            bends * 10 +
            candidate.points.length * 6 +
            shapeFill * 8 +
            emptyShapeCells.intersection(candidate.points.toSet()).length * 4;
        final scored = _ScoredCandidate(candidate, blockedCount, score);

        if (bestCandidate == null || scored.score > bestCandidate.score) {
          bestCandidate = scored;
        }

        if (!needsBlocker || blockedCount > 0) {
          if (attempt >= 16 || blockedCount > 1) break;
        }
      }

      if (bestCandidate == null) {
        consecutiveFailures++;
        if (consecutiveFailures >= 3) break;
        continue;
      }
      consecutiveFailures = 0;

      arrows.add(bestCandidate.arrow);
      occupied.addAll(bestCandidate.arrow.points);
      movable = [
        for (final arrow in arrows)
          if (_canExit(
            arrow,
            occupied.difference(arrow.points.toSet()),
            config.size,
          ))
            arrow,
      ];
    }

    final coverage = occupied.length / shape.cells.length;
    return _GeneratedLayout(arrows, movable.length, coverage);
  }

  Arrow? _randomArrow(
    Random random,
    String id,
    _DifficultyConfig config,
    LevelShape shape,
    Set<GridPoint> preferredCells,
    Map<Direction, Set<GridPoint>> safeCellsByDirection,
    Set<GridPoint> emptyShapeCells, {
    bool strict = true,
  }) {
    final direction = Direction.values[random.nextInt(Direction.values.length)];
    final safeCells = safeCellsByDirection[direction]!;
    final possibleHeads = <GridPoint>[];
    for (final head in shape.cells) {
      final beforeHead = GridPoint(
        head.row - direction.dRow,
        head.col - direction.dCol,
      );
      if (shape.contains(beforeHead) &&
          safeCells.contains(head) &&
          safeCells.contains(beforeHead)) {
        possibleHeads.add(head);
      }
    }
    if (possibleHeads.isEmpty) return null;
    possibleHeads.shuffle(random);

    if (preferredCells.isNotEmpty) {
      for (final targetedHead in possibleHeads.take(
        min(6, possibleHeads.length),
      )) {
        final targetedBefore = GridPoint(
          targetedHead.row - direction.dRow,
          targetedHead.col - direction.dCol,
        );
        final targeted = _findTargetedArrow(
          random: random,
          id: id,
          head: targetedHead,
          beforeHead: targetedBefore,
          safeCells: safeCells,
          preferredCells: preferredCells,
          shape: shape,
          config: config,
        );
        if (targeted != null) return targeted;
      }
    }

    final preferredHeads = possibleHeads
        .where(
          (point) =>
              preferredCells.contains(point) ||
              preferredCells.contains(
                GridPoint(
                  point.row - direction.dRow,
                  point.col - direction.dCol,
                ),
              ) ||
              emptyShapeCells.contains(point),
        )
        .toList();
    final headPool = preferredHeads.isNotEmpty ? preferredHeads : possibleHeads;
    final head = headPool[random.nextInt(min(10, headPool.length))];
    final beforeHead = GridPoint(
      head.row - direction.dRow,
      head.col - direction.dCol,
    );
    if (!shape.contains(beforeHead)) return null;

    final targetLength = strict
        ? config.minLength +
            random.nextInt(config.maxLength - config.minLength + 1)
        : config.minLength +
            random.nextInt(
              (config.maxLength - config.minLength).clamp(1, 3) + 1,
            );
    final backwards = <GridPoint>[head, beforeHead];
    final visited = <GridPoint>{head, beforeHead};

    while (backwards.length < targetLength) {
      final current = backwards.last;
      final choices = <GridPoint>[
        GridPoint(current.row - 1, current.col),
        GridPoint(current.row + 1, current.col),
        GridPoint(current.row, current.col - 1),
        GridPoint(current.row, current.col + 1),
      ]..shuffle(random);
      final valid = choices
          .where(
            (point) => shape.contains(point) && !visited.contains(point),
          )
          .toList();
      if (valid.isEmpty) return null;

      final preferred = valid
          .where(
            (point) =>
                preferredCells.contains(point) || emptyShapeCells.contains(point),
          )
          .toList(growable: false);
      final nextPool = preferred.isNotEmpty ? preferred : valid;
      final next = nextPool[random.nextInt(nextPool.length)];
      backwards.add(next);
      visited.add(next);
    }

    final points = backwards.reversed.toList(growable: false);
    final arrow = Arrow(id: id, points: points);
    final minBends = strict ? config.minBends : max(1, config.minBends - 1);
    if (_bendCount(arrow) < minBends) return null;
    return arrow;
  }

  Arrow? _findTargetedArrow({
    required Random random,
    required String id,
    required GridPoint head,
    required GridPoint beforeHead,
    required Set<GridPoint> safeCells,
    required Set<GridPoint> preferredCells,
    required LevelShape shape,
    required _DifficultyConfig config,
  }) {
    final queue = <List<GridPoint>>[
      [beforeHead],
    ];
    var cursor = 0;
    var expansions = 0;

    while (cursor < queue.length && expansions < 32) {
      final backwardsBody = queue[cursor++];
      final current = backwardsBody.last;
      final totalLength = backwardsBody.length + 1;

      if (totalLength >= config.minLength && preferredCells.contains(current)) {
        final arrow = Arrow(id: id, points: [...backwardsBody.reversed, head]);
        if (_bendCount(arrow) >= config.minBends) return arrow;
      }
      if (totalLength >= config.maxLength) continue;

      final choices =
          <GridPoint>[
              GridPoint(current.row - 1, current.col),
              GridPoint(current.row + 1, current.col),
              GridPoint(current.row, current.col - 1),
              GridPoint(current.row, current.col + 1),
            ]
            ..removeWhere(
              (point) =>
                  point == head ||
                  backwardsBody.contains(point) ||
                  !shape.contains(point),
            )
            ..shuffle(random)
            ..sort(
              (a, b) => (preferredCells.contains(b) ? 1 : 0).compareTo(
                preferredCells.contains(a) ? 1 : 0,
              ),
            );

      for (final next in choices) {
        queue.add([...backwardsBody, next]);
      }
      expansions++;
    }
    return null;
  }

  Set<GridPoint> _safeCells(
    Direction direction,
    Set<GridPoint> occupied,
    LevelShape shape,
  ) {
    return {
      for (final point in shape.cells)
        if (!occupied.contains(point) &&
            _isSafeCell(point, direction, occupied, shape.rows))
          point,
    };
  }

  Set<GridPoint> _sweptCells(Arrow arrow, int size) {
    final cells = <GridPoint>{};
    var current = arrow;
    final maxSteps = size * 2 + arrow.points.length;

    for (var step = 0; step <= maxSteps; step++) {
      if (_inside(current.head, size)) {
        cells.add(current.head);
      }
      if (current.points.every((point) => !_inside(point, size))) {
        break;
      }
      current = current.advanceStep();
    }
    return cells;
  }

  bool _isSafeCell(
    GridPoint point,
    Direction direction,
    Set<GridPoint> occupied,
    int size,
  ) {
    for (var distance = 1; distance <= size; distance++) {
      final moved = point.translate(direction, distance);
      if (!_inside(moved, size)) return true;
      if (occupied.contains(moved)) return false;
    }
    return false;
  }

  bool _canExit(Arrow arrow, Set<GridPoint> occupied, int size) {
    final maxSteps = size * 2 + arrow.points.length;
    var current = arrow;

    for (var step = 1; step <= maxSteps; step++) {
      final nextHead = current.head.translate(current.direction);
      if (_inside(nextHead, size) && occupied.contains(nextHead)) {
        return false;
      }

      current = current.advanceStep();
      if (current.points.every((point) => !_inside(point, size))) {
        return true;
      }
    }
    return false;
  }

  int _bendCount(Arrow arrow) {
    var bends = 0;
    for (var index = 2; index < arrow.points.length; index++) {
      final first = arrow.points[index - 2];
      final middle = arrow.points[index - 1];
      final last = arrow.points[index];
      final firstHorizontal = first.row == middle.row;
      final secondHorizontal = middle.row == last.row;
      if (firstHorizontal != secondHorizontal) bends++;
    }
    return bends;
  }

  bool _inside(GridPoint point, int size) =>
      point.row >= 0 && point.row < size && point.col >= 0 && point.col < size;

  int _seedFor(int levelIndex, int restart) {
    return (((levelIndex + 1) * 0x1f123bb5) ^
            ((restart + 1) * 0x5f356495) ^
            0x6d2b79f5) &
        0x7fffffff;
  }

  String _levelName(int levelIndex) {
    const names = [
      'Tight knot',
      'Hidden lane',
      'Crossed paths',
      'Deep tangle',
      'Narrow escape',
      'Chain reaction',
      'Twisted route',
      'Locked maze',
    ];
    return names[levelIndex % names.length];
  }
}

class _DifficultyConfig {
  const _DifficultyConfig({
    required this.size,
    required this.arrowCount,
    required this.minArrowCount,
    required this.minLength,
    required this.maxLength,
    required this.minBends,
    required this.maxInitialMovable,
    required this.minShapeCoverage,
    required this.difficulty,
  });

  final int size;
  final int arrowCount;
  final int minArrowCount;
  final int minLength;
  final int maxLength;
  final int minBends;
  final int maxInitialMovable;
  final double minShapeCoverage;
  final int difficulty;

  _DifficultyConfig relaxed() {
    return _DifficultyConfig(
      size: size,
      arrowCount: arrowCount,
      minArrowCount: minArrowCount,
      minLength: minLength,
      maxLength: maxLength,
      minBends: max(1, minBends - 1),
      maxInitialMovable: maxInitialMovable + 1,
      minShapeCoverage: max(0.44, minShapeCoverage - 0.05),
      difficulty: difficulty,
    );
  }

  factory _DifficultyConfig.forLevel(int index) {
    if (index < 100) {
      final size = 26 + index ~/ 25;
      return _DifficultyConfig(
        size: size,
        arrowCount: (size * 2.2).round() + index % 6,
        minArrowCount: (size * 1.4).round(),
        minLength: 6,
        maxLength: 14,
        minBends: index < 15 ? 1 : 2,
        maxInitialMovable: 2,
        minShapeCoverage: 0.62,
        difficulty: 7,
      );
    }
    if (index < 400) {
      final progress = (index - 100) ~/ 100;
      final size = 30 + progress;
      return _DifficultyConfig(
        size: size,
        arrowCount: (size * 2.4).round() + index % 6,
        minArrowCount: (size * 1.5).round(),
        minLength: 6,
        maxLength: 15,
        minBends: 2,
        maxInitialMovable: 2,
        minShapeCoverage: 0.64,
        difficulty: 8 + progress,
      );
    }
    if (index < 750) {
      final progress = (index - 400) ~/ 120;
      final size = 34 + progress;
      return _DifficultyConfig(
        size: size,
        arrowCount: (size * 2.5).round() + index % 6,
        minArrowCount: (size * 1.5).round(),
        minLength: 6,
        maxLength: 16,
        minBends: 2,
        maxInitialMovable: 2,
        minShapeCoverage: 0.66,
        difficulty: 9 + progress ~/ 2,
      );
    }
    const size = 38;
    return _DifficultyConfig(
      size: size,
      arrowCount: (size * 2.6).round() + index % 6,
      minArrowCount: (size * 1.5).round(),
      minLength: 7,
      maxLength: 17,
      minBends: 3,
      maxInitialMovable: 3,
      minShapeCoverage: 0.66,
      difficulty: 10,
    );
  }
}

class _GeneratedLayout {
  const _GeneratedLayout(
    this.arrows,
    this.initialMovableCount,
    this.shapeCoverage,
  );

  final List<Arrow> arrows;
  final int initialMovableCount;
  final double shapeCoverage;
}

class _ScoredCandidate {
  const _ScoredCandidate(this.arrow, this.blockedCount, this.score);

  final Arrow arrow;
  final int blockedCount;
  final int score;
}
