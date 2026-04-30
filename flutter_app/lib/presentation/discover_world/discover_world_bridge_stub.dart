import 'discover_world_bridge.dart';

class UnsupportedDiscoverWorldBridge implements DiscoverWorldBridge {
  @override
  bool supportsWebGpu() => false;

  @override
  void attachCallbacks({
    DiscoverWorldPayloadHandler? onPlaceSelected,
    DiscoverWorldPayloadHandler? onPlaceHovered,
    DiscoverWorldPayloadHandler? onCameraSettled,
    DiscoverWorldPayloadHandler? onWorldInitFailed,
  }) {}

  @override
  Future<void> initWorld({
    required String containerId,
    Map<String, dynamic> config = const <String, dynamic>{},
  }) async {}

  @override
  Future<void> setWorldData(Map<String, dynamic> data) async {}

  @override
  Future<void> focusPlace(String? placeId) async {}

  @override
  Future<void> updateCamera(String mode) async {}

  @override
  Future<void> disposeWorld() async {}
}

DiscoverWorldBridge createPlatformDiscoverWorldBridge() =>
    UnsupportedDiscoverWorldBridge();
