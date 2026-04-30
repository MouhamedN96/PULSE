import 'discover_world_bridge_stub.dart'
    if (dart.library.js_interop) 'discover_world_bridge_web.dart';

typedef DiscoverWorldPayloadHandler = void Function(
    Map<String, dynamic> payload);

abstract class DiscoverWorldBridge {
  bool supportsWebGpu();

  void attachCallbacks({
    DiscoverWorldPayloadHandler? onPlaceSelected,
    DiscoverWorldPayloadHandler? onPlaceHovered,
    DiscoverWorldPayloadHandler? onCameraSettled,
    DiscoverWorldPayloadHandler? onWorldInitFailed,
  });

  Future<void> initWorld({
    required String containerId,
    Map<String, dynamic> config = const <String, dynamic>{},
  });

  Future<void> setWorldData(Map<String, dynamic> data);

  Future<void> focusPlace(String? placeId);

  Future<void> updateCamera(String mode);

  Future<void> disposeWorld();
}

DiscoverWorldBridge createDiscoverWorldBridge() =>
    createPlatformDiscoverWorldBridge();
