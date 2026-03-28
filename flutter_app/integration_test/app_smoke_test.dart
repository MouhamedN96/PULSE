import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stroll/main.dart';

import 'fake_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots and shows bottom tabs', (tester) async {
    await tester.pumpWidget(
      StrollApp(repository: IntegrationFakeRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);

    await tester.tap(find.text('Links'));
    await tester.pumpAndSettle();
    expect(find.text('Links'), findsWidgets);
  });
}
