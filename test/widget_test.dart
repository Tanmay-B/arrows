import 'package:flutter_test/flutter_test.dart';
import 'package:arrows/main.dart';
import 'package:arrows/models/level.dart';

void main() {
  testWidgets('Arrows app loads home then game screen', (tester) async {
    await tester.pumpWidget(const ArrowsApp());
    expect(find.text('Home screen coming soon.'), findsOneWidget);

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Level 1'), findsOneWidget);
    expect(
      find.text('${LevelCatalog.byIndex(0).arrows.length} left'),
      findsOneWidget,
    );
  });
}
