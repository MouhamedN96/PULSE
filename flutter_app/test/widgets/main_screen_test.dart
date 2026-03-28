import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroll/presentation/screens/main_screen.dart';

import '../test_helpers/fake_repository.dart';

void main() {
  testWidgets('renders bottom navigation tabs', (tester) async {
    final repository = FakeStrollRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(repository: repository),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Links'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('switches to links tab', (tester) async {
    final repository = FakeStrollRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(repository: repository),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Links'));
    await tester.pumpAndSettle();

    expect(find.text('Your network & connections'), findsOneWidget);
  });
}
