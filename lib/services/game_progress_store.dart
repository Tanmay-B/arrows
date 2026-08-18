import 'package:shared_preferences/shared_preferences.dart';

class SavedGameState {
  const SavedGameState({
    required this.levelIndex,
    required this.remainingArrowIds,
    required this.lives,
    required this.status,
  });

  final int levelIndex;
  final List<String> remainingArrowIds;
  final int lives;
  final String status;
}

class GameProgressStore {
  static const _keyLevelIndex = 'game_level_index';
  static const _keyRemainingArrows = 'game_remaining_arrows';
  static const _keyLives = 'game_lives';
  static const _keyStatus = 'game_status';

  static Future<SavedGameState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_keyLevelIndex)) return null;

    final levelIndex = prefs.getInt(_keyLevelIndex);
    final remainingArrowIds = prefs.getStringList(_keyRemainingArrows);
    final lives = prefs.getInt(_keyLives);
    final status = prefs.getString(_keyStatus);

    if (levelIndex == null ||
        remainingArrowIds == null ||
        lives == null ||
        status == null) {
      return null;
    }

    return SavedGameState(
      levelIndex: levelIndex,
      remainingArrowIds: remainingArrowIds,
      lives: lives,
      status: status,
    );
  }

  static Future<void> save({
    required int levelIndex,
    required List<String> remainingArrowIds,
    required int lives,
    required String status,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLevelIndex, levelIndex);
    await prefs.setStringList(_keyRemainingArrows, remainingArrowIds);
    await prefs.setInt(_keyLives, lives);
    await prefs.setString(_keyStatus, status);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLevelIndex);
    await prefs.remove(_keyRemainingArrows);
    await prefs.remove(_keyLives);
    await prefs.remove(_keyStatus);
  }
}
