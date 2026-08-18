import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:arrows/main.dart';
import 'package:arrows/models/level.dart';
import 'package:arrows/providers/game_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Arrows app loads home then game screen', (tester) async {
    final provider = GameProvider();
    await provider.restoreProgress();

    await tester.pumpWidget(ArrowsApp(gameProvider: provider));
    expect(find.text('Arrow Maze'), findsOneWidget);
    expect(find.text('New Game'), findsOneWidget);

    await tester.tap(find.text('New Game'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Level 1'), findsOneWidget);
    expect(
      find.text('${LevelCatalog.byIndex(0).arrows.length} left'),
      findsOneWidget,
    );
  });
}
