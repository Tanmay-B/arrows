import 'package:flutter_test/flutter_test.dart';
import 'package:arrows/main.dart';
import 'package:arrows/models/level.dart';

void main() {
  testWidgets('Arrows app loads home then game screen', (tester) async {
    await tester.pumpWidget(const ArrowsApp());
    expect(find.text('ARROWS'), findsOneWidget);
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
