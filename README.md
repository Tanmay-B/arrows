# Arrows

Tap-away arrow puzzle in Flutter. Clear the board by sliding arrows off-grid when their path is empty.

## Run

```bash
flutter pub get
flutter run
```

## Tests

```bash
flutter test
```

## Structure

```text
lib/
  game/           # Pure engine and deterministic level generator
  models/         # Arrow, Board, Level, Direction
  providers/      # GameProvider (ChangeNotifier)
  screens/        # GameScreen
  widgets/        # Custom-painted snake-arrow board
```

Includes 1,000 reproducible, unique levels built in reverse solution order.
Every level is validated for geometry, uniqueness, and solvability.
