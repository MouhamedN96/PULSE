import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroll/presentation/screens/voice_agent_screen.dart';

import '../test_helpers/fake_repository.dart';

void main() {
  testWidgets('shows voice agent input prompt', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VoiceAgentScreen(repository: FakeStrollRepository()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('STROLL Agent'), findsOneWidget);
    expect(
      find.text('Tap the microphone and tell me what you want to explore'),
      findsOneWidget,
    );
  });
}
