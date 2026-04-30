import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stroll/presentation/discover_world/discover_world_bridge.dart';
import 'package:stroll/presentation/screens/discover_world_screen.dart';

import '../test_helpers/fake_repository.dart';

class _FakeDiscoverWorldBridge implements DiscoverWorldBridge {
  _FakeDiscoverWorldBridge({required this.supported});

  final bool supported;
  int setWorldDataCalls = 0;
  Map<String, dynamic>? lastPayload;
  DiscoverWorldPayloadHandler? _onPlaceSelected;

  @override
  bool supportsWebGpu() => supported;

  @override
  void attachCallbacks({
    DiscoverWorldPayloadHandler? onPlaceSelected,
    DiscoverWorldPayloadHandler? onPlaceHovered,
    DiscoverWorldPayloadHandler? onCameraSettled,
    DiscoverWorldPayloadHandler? onWorldInitFailed,
  }) {
    _onPlaceSelected = onPlaceSelected;
  }

  @override
  Future<void> initWorld({
    required String containerId,
    Map<String, dynamic> config = const <String, dynamic>{},
  }) async {}

  @override
  Future<void> setWorldData(Map<String, dynamic> data) async {
    setWorldDataCalls += 1;
    lastPayload = data;
  }

  @override
  Future<void> focusPlace(String? placeId) async {}

  @override
  Future<void> updateCamera(String mode) async {}

  @override
  Future<void> disposeWorld() async {}

  void emitPlaceSelected(String activityId, {String? clusterId}) {
    _onPlaceSelected?.call(<String, dynamic>{
      'placeId': activityId,
      if (clusterId != null) 'clusterId': clusterId,
    });
  }
}

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
  setUp(_ignoreNetworkImageErrors);

  testWidgets('falls back to feed when world bridge is unsupported',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverWorldScreen(
          repository: FakeStrollRepository(),
          bridge: _FakeDiscoverWorldBridge(supported: false),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('PULSE'), findsOneWidget);
    expect(find.byKey(const Key('discover-world-platform-view')), findsNothing);
  });

  testWidgets('renders world overlay and pushes data into the bridge',
      (tester) async {
    final bridge = _FakeDiscoverWorldBridge(supported: true);

    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverWorldScreen(
          repository: FakeStrollRepository(),
          bridge: bridge,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('PULSE CITY'), findsOneWidget);
    expect(
        find.byKey(const Key('discover-world-platform-view')), findsOneWidget);
    expect(bridge.setWorldDataCalls, greaterThan(0));
    expect(bridge.lastPayload?['activity_count'], greaterThan(0));
  });

  testWidgets(
      'updates the selected activity when the world bridge emits a place event',
      (tester) async {
    final bridge = _FakeDiscoverWorldBridge(supported: true);

    await tester.pumpWidget(
      MaterialApp(
        home: DiscoverWorldScreen(
          repository: FakeStrollRepository(),
          bridge: bridge,
        ),
      ),
    );

    await tester.pumpAndSettle();
    bridge.emitPlaceSelected('act-2', clusterId: 'wellness::jingan');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('discover-world-selected-activity-card')),
        findsOneWidget);
    expect(find.text('Pure Yoga'), findsWidgets);
  });
}
