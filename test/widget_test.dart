import 'package:flutter_test/flutter_test.dart';
import 'package:arrows/main.dart';
import 'package:arrows/models/level.dart';

void main() {
  testWidgets('Arrows app loads game screen', (tester) async {
    await tester.pumpWidget(const ArrowsApp());
    expect(find.text('Level 1'), findsOneWidget);
    expect(
      find.text('${LevelCatalog.byIndex(0).arrows.length} left'),
      findsOneWidget,
    );
  });
}
