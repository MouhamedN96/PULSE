import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroll/presentation/screens/main_screen.dart';

import '../test_helpers/fake_repository.dart';

void _ignoreNetworkImageErrors() {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exception is NetworkImageLoadException) {
      return;
    }
    previousOnError?.call(details);
  };
}

void main() {
  testWidgets('renders bottom navigation tabs', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _ignoreNetworkImageErrors();

    final repository = FakeStrollRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(repository: repository),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });

  testWidgets('switches to links tab', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _ignoreNetworkImageErrors();

    final repository = FakeStrollRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MainScreen(repository: repository),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Feed'));
    await tester.pumpAndSettle();

    expect(find.text('Your network & connections'), findsOneWidget);
  });
}
