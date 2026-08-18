import 'package:flutter/foundation.dart';

import '../game/level_generator.dart';
import 'level_definition.dart';

export 'level_definition.dart';

LevelDef _generateLevelInIsolate(int index) {
  return const LevelGenerator().generate(index);
}

class LevelCatalog {
  static const int levelCount = 1000;
  static const LevelGenerator _generator = LevelGenerator();
  static final Map<int, LevelDef> _cache = {};
  static final Map<int, Future<LevelDef>> _inFlight = {};

  /// Lazy iterable used by validation tooling without generating every level
  /// during normal app startup.
  static Iterable<LevelDef> get levels =>
      Iterable<LevelDef>.generate(levelCount, byIndex);

  static bool isCached(int index) {
    final safeIndex = index.clamp(0, levelCount - 1);
    return _cache.containsKey(safeIndex);
  }

  static LevelDef byIndex(int index) {
    final safeIndex = index.clamp(0, levelCount - 1);
    return _cache.putIfAbsent(safeIndex, () => _generator.generate(safeIndex));
  }

  static Future<LevelDef> byIndexAsync(int index) {
    final safeIndex = index.clamp(0, levelCount - 1);
    final cached = _cache[safeIndex];
    if (cached != null) {
      return Future.value(cached);
    }

    return _inFlight.putIfAbsent(safeIndex, () async {
      try {
        final level = await compute(_generateLevelInIsolate, safeIndex);
        return _cache.putIfAbsent(safeIndex, () => level);
      } finally {
        _inFlight.remove(safeIndex);
      }
    });
  }
}
