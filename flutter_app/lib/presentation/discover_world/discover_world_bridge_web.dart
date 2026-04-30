import 'dart:js_interop';
import 'dart:js_util' as js_util;

import 'discover_world_bridge.dart';

@JS('globalThis.pulseDiscoverWorld')
external JSObject? get _discoverWorldRuntime;

class WebDiscoverWorldBridge implements DiscoverWorldBridge {
  DiscoverWorldPayloadHandler? _onPlaceSelected;
  DiscoverWorldPayloadHandler? _onPlaceHovered;
  DiscoverWorldPayloadHandler? _onCameraSettled;
  DiscoverWorldPayloadHandler? _onWorldInitFailed;

  JSObject? get _runtime => _discoverWorldRuntime;

  @override
  bool supportsWebGpu() {
    final runtime = _runtime;
    if (runtime == null) {
      return false;
    }

    try {
      final result =
          js_util.callMethod<Object?>(runtime, 'supportsWebGpu', const []);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  @override
  void attachCallbacks({
    DiscoverWorldPayloadHandler? onPlaceSelected,
    DiscoverWorldPayloadHandler? onPlaceHovered,
    DiscoverWorldPayloadHandler? onCameraSettled,
    DiscoverWorldPayloadHandler? onWorldInitFailed,
  }) {
    _onPlaceSelected = onPlaceSelected;
    _onPlaceHovered = onPlaceHovered;
    _onCameraSettled = onCameraSettled;
    _onWorldInitFailed = onWorldInitFailed;

    final runtime = _runtime;
    if (runtime == null) {
      return;
    }

    js_util.setProperty(
      runtime,
      'onPlaceSelected',
      ((JSAny? payload) => _dispatch(_onPlaceSelected, payload)).toJS,
    );
    js_util.setProperty(
      runtime,
      'onPlaceHovered',
      ((JSAny? payload) => _dispatch(_onPlaceHovered, payload)).toJS,
    );
    js_util.setProperty(
      runtime,
      'onCameraSettled',
      ((JSAny? payload) => _dispatch(_onCameraSettled, payload)).toJS,
    );
    js_util.setProperty(
      runtime,
      'onWorldInitFailed',
      ((JSAny? payload) => _dispatch(_onWorldInitFailed, payload)).toJS,
    );
  }

  @override
  Future<void> initWorld({
    required String containerId,
    Map<String, dynamic> config = const <String, dynamic>{},
  }) async {
    final runtime = _runtime;
    if (runtime == null) {
      throw StateError('Discover world runtime is not loaded');
    }

    final promise = js_util.callMethod<JSAny?>(
      runtime,
      'initWorld',
      <Object?>[containerId, js_util.jsify(config)],
    );
    if (promise != null) {
      await js_util.promiseToFuture<Object?>(promise);
    }
  }

  @override
  Future<void> setWorldData(Map<String, dynamic> data) async {
    final runtime = _runtime;
    if (runtime == null) {
      return;
    }

    final promise = js_util.callMethod<JSAny?>(
      runtime,
      'setWorldData',
      <Object?>[js_util.jsify(data)],
    );
    if (promise != null) {
      await js_util.promiseToFuture<Object?>(promise);
    }
  }

  @override
  Future<void> focusPlace(String? placeId) async {
    final runtime = _runtime;
    if (runtime == null) {
      return;
    }

    final promise = js_util.callMethod<JSAny?>(
      runtime,
      'focusPlace',
      <Object?>[placeId],
    );
    if (promise != null) {
      await js_util.promiseToFuture<Object?>(promise);
    }
  }

  @override
  Future<void> updateCamera(String mode) async {
    final runtime = _runtime;
    if (runtime == null) {
      return;
    }

    final promise = js_util.callMethod<JSAny?>(
      runtime,
      'updateCamera',
      <Object?>[mode],
    );
    if (promise != null) {
      await js_util.promiseToFuture<Object?>(promise);
    }
  }

  @override
  Future<void> disposeWorld() async {
    final runtime = _runtime;
    if (runtime == null) {
      return;
    }

    final promise = js_util.callMethod<JSAny?>(
      runtime,
      'disposeWorld',
      const <Object?>[],
    );
    if (promise != null) {
      await js_util.promiseToFuture<Object?>(promise);
    }
  }

  void _dispatch(
    DiscoverWorldPayloadHandler? handler,
    JSAny? payload,
  ) {
    if (handler == null) {
      return;
    }

    final dartified = js_util.dartify(payload);
    if (dartified is Map) {
      handler(Map<String, dynamic>.from(dartified));
    } else {
      handler(const <String, dynamic>{});
    }
  }
}

DiscoverWorldBridge createPlatformDiscoverWorldBridge() =>
    WebDiscoverWorldBridge();
