import 'package:arrows/game/game_engine.dart';
import 'package:arrows/game/level_generator.dart';
import 'package:arrows/models/arrow.dart';
import 'package:arrows/models/board.dart';
import 'package:arrows/models/level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = GameEngine();

  test('single open arrow can exit', () {
    final board = Board.fromLevel(
      LevelDef(
        id: 't1',
        name: 't1',
        rows: 3,
        cols: 3,
        shapeName: 'Square',
        shapeCells: {
          for (var row = 0; row < 3; row++)
            for (var col = 0; col < 3; col++) GridPoint(row, col),
        },
        arrows: const [
          Arrow(id: 'a', points: [GridPoint(1, 0), GridPoint(1, 1)]),
        ],
      ),
    );

    expect(engine.canMove(board, 'a'), isTrue);
    final result = engine.tryMove(board, 'a');
    expect(result, isA<MoveSuccess>());
    final success = result as MoveSuccess;
    expect(success.board.isWon, isTrue);
  });

  test('blocked arrow cannot move', () {
    final board = Board.fromLevel(
      LevelDef(
        id: 't2',
        name: 't2',
        rows: 3,
        cols: 3,
        shapeName: 'Square',
        shapeCells: {
          for (var row = 0; row < 3; row++)
            for (var col = 0; col < 3; col++) GridPoint(row, col),
        },
        arrows: const [
          Arrow(id: 'a', points: [GridPoint(1, 0), GridPoint(1, 1)]),
          Arrow(id: 'b', points: [GridPoint(2, 2), GridPoint(1, 2)]),
        ],
      ),
    );

    expect(engine.canMove(board, 'a'), isFalse);
    expect(engine.tryMove(board, 'a'), isA<MoveFailure>());
    expect(engine.canMove(board, 'b'), isTrue);
  });

  test('bent snake can exit when only the pointer path is clear', () {
    final board = Board.fromLevel(
      LevelDef(
        id: 't3',
        name: 't3',
        rows: 5,
        cols: 5,
        shapeName: 'Square',
        shapeCells: {
          for (var row = 0; row < 5; row++)
            for (var col = 0; col < 5; col++) GridPoint(row, col),
        },
        arrows: const [
          Arrow(
            id: 'a',
            points: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(1, 1)],
          ),
          Arrow(id: 'b', points: [GridPoint(0, 2), GridPoint(0, 3)]),
        ],
      ),
    );

    expect(engine.canMove(board, 'a'), isTrue);
  });

  test('bent snake is blocked when the pointer path is occupied', () {
    final board = Board.fromLevel(
      LevelDef(
        id: 't4',
        name: 't4',
        rows: 5,
        cols: 5,
        shapeName: 'Square',
        shapeCells: {
          for (var row = 0; row < 5; row++)
            for (var col = 0; col < 5; col++) GridPoint(row, col),
        },
        arrows: const [
          Arrow(
            id: 'a',
            points: [GridPoint(0, 0), GridPoint(1, 0), GridPoint(1, 1)],
          ),
          Arrow(id: 'b', points: [GridPoint(1, 2), GridPoint(1, 3)]),
        ],
      ),
    );

    expect(engine.canMove(board, 'a'), isFalse);
  });

  test('bent snake cannot exit when head would hit its own body', () {
    final board = Board.fromLevel(
      LevelDef(
        id: 't5',
        name: 't5',
        rows: 5,
        cols: 5,
        shapeName: 'Square',
        shapeCells: {
          for (var row = 0; row < 5; row++)
            for (var col = 0; col < 5; col++) GridPoint(row, col),
        },
        arrows: const [
          Arrow(
            id: 'a',
            points: [
              GridPoint(1, 1),
              GridPoint(1, 2),
              GridPoint(1, 3),
              GridPoint(2, 3),
              GridPoint(3, 3),
              GridPoint(3, 2),
              GridPoint(2, 2),
            ],
          ),
        ],
      ),
    );

    expect(engine.canMove(board, 'a'), isFalse);
    expect(engine.tryMove(board, 'a'), isA<MoveFailure>());
  });

  test('all 1000 levels are unique, valid, and solvable', () {
    final fingerprints = <String>{};

    for (
      var levelIndex = 0;
      levelIndex < LevelCatalog.levelCount;
      levelIndex++
    ) {
      final level = LevelCatalog.byIndex(levelIndex);
      final occupied = <GridPoint>{};

      expect(
        level.arrows.length,
        greaterThanOrEqualTo(_minimumCount(levelIndex) - 8),
        reason: 'Level ${level.id} has too few arrows',
      );
      expect(level.solution.length, level.arrows.length);

      for (final arrow in level.arrows) {
        expect(arrow.points.length, greaterThanOrEqualTo(3));
        expect(_bendCount(arrow), greaterThanOrEqualTo(1));
        for (
          var pointIndex = 0;
          pointIndex < arrow.points.length;
          pointIndex++
        ) {
          final point = arrow.points[pointIndex];
          expect(point.row, inInclusiveRange(0, level.rows - 1));
          expect(point.col, inInclusiveRange(0, level.cols - 1));
          expect(occupied.add(point), isTrue);
          if (pointIndex > 0) {
            final previous = arrow.points[pointIndex - 1];
            final distance =
                (point.row - previous.row).abs() +
                (point.col - previous.col).abs();
            expect(distance, 1);
          }
        }
      }

      expect(fingerprints.add(_fingerprint(level)), isTrue);
      var board = Board.fromLevel(level);
      final openingMoves = engine.getMovableIds(board);
      expect(openingMoves, isNotEmpty);
      expect(
        openingMoves.length,
        lessThan(level.arrows.length),
        reason: 'Level ${level.id} should not start fully unlocked',
      );

      for (final arrowId in level.solution) {
        final result = engine.tryMove(board, arrowId);
        expect(
          result,
          isA<MoveSuccess>(),
          reason: 'Level ${level.id} solution fails at $arrowId',
        );
        board = (result as MoveSuccess).board;
      }
      expect(board.isWon, isTrue);
    }

    expect(fingerprints.length, LevelCatalog.levelCount);
  });

  test('generation is deterministic and difficulty scales upward', () {
    const generator = LevelGenerator();
    final firstA = generator.generate(0);
    final firstB = generator.generate(0);
    expect(_fingerprint(firstA), _fingerprint(firstB));

    final early = LevelCatalog.byIndex(0);
    final middle = LevelCatalog.byIndex(500);
    final late = LevelCatalog.byIndex(999);
    expect(middle.difficulty, greaterThan(early.difficulty));
    expect(late.difficulty, greaterThan(middle.difficulty));
    expect(middle.rows, greaterThan(early.rows));
    expect(late.rows, greaterThan(middle.rows));
    expect(middle.arrows.length, greaterThan(early.arrows.length - 8));
    expect(late.arrows.length, greaterThan(early.arrows.length - 8));
    expect(early.difficulty, greaterThanOrEqualTo(7));
    expect(late.difficulty, 10);
  });
}

int _minimumCount(int index) {
  if (index < 100) return 20;
  if (index < 400) return 28;
  if (index < 750) return 36;
  return 44;
}

int _bendCount(Arrow arrow) {
  var bends = 0;
  for (var index = 2; index < arrow.points.length; index++) {
    final a = arrow.points[index - 2];
    final b = arrow.points[index - 1];
    final c = arrow.points[index];
    if ((a.row == b.row) != (b.row == c.row)) bends++;
  }
  return bends;
}

String _fingerprint(LevelDef level) {
  final arrows =
      level.arrows
          .map(
            (arrow) =>
                '${arrow.points.map((point) => '${point.row},${point.col}').join(';')}'
                ':${arrow.direction.name}',
          )
          .toList()
        ..sort();
  return '${level.rows}x${level.cols}|${level.shapeName}|${arrows.join('|')}';
}
