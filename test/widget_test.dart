
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:demo/main.dart';

void main() {
  testWidgets('La aplicación se inicializa correctamente',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Comprueba que la aplicación haya construido su MaterialApp.
    expect(find.byType(ProviderScope), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
