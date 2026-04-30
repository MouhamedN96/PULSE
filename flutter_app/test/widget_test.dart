import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroll/main.dart';

import 'test_helpers/fake_repository.dart';

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
  testWidgets('app boots with the main navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _ignoreNetworkImageErrors();

    await tester.pumpWidget(
      StrollApp(repository: FakeStrollRepository()),
    );

    await tester.pumpAndSettle();

    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Feed'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
