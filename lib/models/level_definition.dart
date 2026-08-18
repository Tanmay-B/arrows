import 'arrow.dart';

class LevelDef {
  const LevelDef({
    required this.id,
    required this.name,
    required this.rows,
    required this.cols,
    required this.arrows,
    this.difficulty = 1,
    this.solution = const [],
  });

  final String id;
  final String name;
  final int rows;
  final int cols;
  final List<Arrow> arrows;
  final int difficulty;

  /// Arrow IDs in one guaranteed removal order.
  final List<String> solution;
}
