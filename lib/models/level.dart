import '../game/level_generator.dart';
import 'level_definition.dart';

export 'level_definition.dart';

class LevelCatalog {
  static const int levelCount = 1000;
  static const LevelGenerator _generator = LevelGenerator();
  static final Map<int, LevelDef> _cache = {};

  /// Lazy iterable used by validation tooling without generating every level
  /// during normal app startup.
  static Iterable<LevelDef> get levels =>
      Iterable<LevelDef>.generate(levelCount, byIndex);

  static LevelDef byIndex(int index) {
    final safeIndex = index.clamp(0, levelCount - 1);
    return _cache.putIfAbsent(safeIndex, () => _generator.generate(safeIndex));
  }
}
