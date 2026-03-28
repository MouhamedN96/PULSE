import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

import '../data/stroll_models.dart';

DynamicLibrary _loadLibrary() {
  if (Platform.isAndroid) {
    return DynamicLibrary.open('libstroll_core.so');
  }
  if (Platform.isIOS) {
    return DynamicLibrary.process();
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('stroll_core.dll');
  }
  if (Platform.isLinux) {
    return DynamicLibrary.open('libstroll_core.so');
  }
  return DynamicLibrary.open('libstroll_core.dylib');
}

final DynamicLibrary strollLib = _loadLibrary();

// Native signatures.
typedef CreateCoreC = Pointer<Void> Function();
typedef CreateCoreDart = Pointer<Void> Function();

typedef CreateCoreWithDbPathC = Pointer<Void> Function(Pointer<Utf8>);
typedef CreateCoreWithDbPathDart = Pointer<Void> Function(Pointer<Utf8>);

typedef DisposeCoreC = Void Function(Pointer<Void>);
typedef DisposeCoreDart = void Function(Pointer<Void>);

typedef InitMockDataC = Pointer<Utf8> Function(Pointer<Void>);
typedef InitMockDataDart = Pointer<Utf8> Function(Pointer<Void>);

typedef ProcessVoiceQueryC = Pointer<Utf8> Function(
  Pointer<Void>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
);
typedef ProcessVoiceQueryDart = Pointer<Utf8> Function(
  Pointer<Void>,
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
);

typedef GetPersonalizedFeedC = Pointer<Utf8> Function(Pointer<Void>);
typedef GetPersonalizedFeedDart = Pointer<Utf8> Function(Pointer<Void>);

typedef GetNetworkC = Pointer<Utf8> Function(Pointer<Void>);
typedef GetNetworkDart = Pointer<Utf8> Function(Pointer<Void>);

typedef FollowUserC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef FollowUserDart = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);

typedef GetTrendingC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef GetTrendingDart = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);

typedef SaveActivityC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef SaveActivityDart = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);

typedef GetSavedActivitiesC = Pointer<Utf8> Function(Pointer<Void>);
typedef GetSavedActivitiesDart = Pointer<Utf8> Function(Pointer<Void>);

typedef FreeStringC = Void Function(Pointer<Utf8>);
typedef FreeStringDart = void Function(Pointer<Utf8>);

class StrollBridgeException implements Exception {
  StrollBridgeException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => '[$code] $message';
}

abstract class StrollBridgeClient {
  Future<void> initialize({String? databasePath});

  Future<AgentResponseModel> processVoiceQuery({
    required String query,
    GeoLocationModel? location,
    String? imageAnalysis,
  });

  Future<FeedResponseModel> getPersonalizedFeed();
  Future<NetworkResponseModel> getNetwork();
  Future<void> followUser(String userId);
  Future<List<ActivityModel>> getTrending({String? category});
  Future<void> saveActivity(String activityId);
  Future<List<ActivityModel>> getSavedActivities();
  Future<void> dispose();
}

class StrollBridge implements StrollBridgeClient {
  StrollBridge._internal();

  static final StrollBridge instance = StrollBridge._internal();

  Pointer<Void>? _core;

  late final CreateCoreDart _createCore;
  CreateCoreWithDbPathDart? _createCoreWithDbPath;
  late final DisposeCoreDart _disposeCore;
  late final InitMockDataDart _initMockData;
  late final ProcessVoiceQueryDart _processVoiceQuery;
  late final GetPersonalizedFeedDart _getPersonalizedFeed;
  late final GetNetworkDart _getNetwork;
  late final FollowUserDart _followUser;
  late final GetTrendingDart _getTrending;
  late final SaveActivityDart _saveActivity;
  late final GetSavedActivitiesDart _getSavedActivities;
  late final FreeStringDart _freeString;

  bool _initialized = false;

  @override
  Future<void> initialize({String? databasePath}) async {
    if (_initialized) {
      return;
    }

    try {
      _createCore = strollLib
          .lookup<NativeFunction<CreateCoreC>>('stroll_create_core')
          .asFunction();
      try {
        _createCoreWithDbPath = strollLib
            .lookup<NativeFunction<CreateCoreWithDbPathC>>(
              'stroll_create_core_with_db_path',
            )
            .asFunction();
      } catch (_) {
        _createCoreWithDbPath = null;
      }
      _disposeCore = strollLib
          .lookup<NativeFunction<DisposeCoreC>>('stroll_dispose_core')
          .asFunction();
      _initMockData = strollLib
          .lookup<NativeFunction<InitMockDataC>>('stroll_init_mock_data')
          .asFunction();
      _processVoiceQuery = strollLib
          .lookup<NativeFunction<ProcessVoiceQueryC>>('stroll_process_voice_query')
          .asFunction();
      _getPersonalizedFeed = strollLib
          .lookup<NativeFunction<GetPersonalizedFeedC>>('stroll_get_personalized_feed')
          .asFunction();
      _getNetwork = strollLib
          .lookup<NativeFunction<GetNetworkC>>('stroll_get_network')
          .asFunction();
      _followUser = strollLib
          .lookup<NativeFunction<FollowUserC>>('stroll_follow_user')
          .asFunction();
      _getTrending = strollLib
          .lookup<NativeFunction<GetTrendingC>>('stroll_get_trending')
          .asFunction();
      _saveActivity = strollLib
          .lookup<NativeFunction<SaveActivityC>>('stroll_save_activity')
          .asFunction();
      _getSavedActivities = strollLib
          .lookup<NativeFunction<GetSavedActivitiesC>>('stroll_get_saved_activities')
          .asFunction();
      _freeString = strollLib
          .lookup<NativeFunction<FreeStringC>>('stroll_free_string')
          .asFunction();

      final requestedDatabasePath = databasePath?.trim();
      if (requestedDatabasePath != null &&
          requestedDatabasePath.isNotEmpty &&
          _createCoreWithDbPath != null) {
        final dbPathPtr = requestedDatabasePath.toNativeUtf8();
        try {
          _core = _createCoreWithDbPath!(dbPathPtr);
        } finally {
          calloc.free(dbPathPtr);
        }
      } else {
        _core = _createCore();
      }

      if (_core == nullptr) {
        throw StrollBridgeException(
          code: 'DB_INIT_ERROR',
          message: 'Native core allocation failed',
        );
      }
      _decodeVoid(_initMockData(_core!));
      _initialized = true;
      debugPrint('STROLL bridge initialized');
    } on StrollBridgeException {
      rethrow;
    } catch (error) {
      throw StrollBridgeException(
        code: 'BRIDGE_INIT_FAILED',
        message: error.toString(),
      );
    }
  }

  @override
  Future<AgentResponseModel> processVoiceQuery({
    required String query,
    GeoLocationModel? location,
    String? imageAnalysis,
  }) async {
    _ensureInitialized();

    final queryPtr = query.toNativeUtf8();
    final locationPtr = _toNullableUtf8(
      location == null ? null : jsonEncode(location.toJson()),
    );
    final imagePtr = _toNullableUtf8(imageAnalysis);

    try {
      final data = _decodeData(
        _processVoiceQuery(_core!, queryPtr, locationPtr, imagePtr),
      );
      return AgentResponseModel.fromJson(asJsonMap(data));
    } finally {
      calloc.free(queryPtr);
      _freeNullableUtf8(locationPtr);
      _freeNullableUtf8(imagePtr);
    }
  }

  @override
  Future<FeedResponseModel> getPersonalizedFeed() async {
    _ensureInitialized();
    final data = _decodeData(_getPersonalizedFeed(_core!));
    return FeedResponseModel.fromJson(asJsonMap(data));
  }

  @override
  Future<NetworkResponseModel> getNetwork() async {
    _ensureInitialized();
    final data = _decodeData(_getNetwork(_core!));
    return NetworkResponseModel.fromJson(asJsonMap(data));
  }

  @override
  Future<void> followUser(String userId) async {
    _ensureInitialized();
    final userPtr = userId.toNativeUtf8();

    try {
      _decodeVoid(_followUser(_core!, userPtr));
    } finally {
      calloc.free(userPtr);
    }
  }

  @override
  Future<List<ActivityModel>> getTrending({String? category}) async {
    _ensureInitialized();

    final categoryPtr = _toNullableUtf8(category);
    try {
      final data = _decodeData(_getTrending(_core!, categoryPtr));
      return asJsonMapList(data)
          .map(ActivityModel.fromJson)
          .toList(growable: false);
    } finally {
      _freeNullableUtf8(categoryPtr);
    }
  }

  @override
  Future<void> saveActivity(String activityId) async {
    _ensureInitialized();

    final activityPtr = activityId.toNativeUtf8();
    try {
      _decodeVoid(_saveActivity(_core!, activityPtr));
    } finally {
      calloc.free(activityPtr);
    }
  }

  @override
  Future<List<ActivityModel>> getSavedActivities() async {
    _ensureInitialized();
    final data = _decodeData(_getSavedActivities(_core!));
    return asJsonMapList(data)
        .map(ActivityModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<void> dispose() async {
    if (_core != null) {
      _disposeCore(_core!);
      _core = null;
      _initialized = false;
    }
  }

  void _ensureInitialized() {
    if (!_initialized || _core == null) {
      throw StrollBridgeException(
        code: 'BRIDGE_NOT_INITIALIZED',
        message: 'Bridge has not been initialized',
      );
    }
  }

  dynamic _decodeData(Pointer<Utf8> pointer) {
    final decoded = _decodeEnvelope(pointer);
    return decoded['data'];
  }

  void _decodeVoid(Pointer<Utf8> pointer) {
    _decodeEnvelope(pointer);
  }

  Map<String, dynamic> _decodeEnvelope(Pointer<Utf8> pointer) {
    if (pointer == nullptr) {
      throw StrollBridgeException(
        code: 'NULL_POINTER',
        message: 'Native function returned null pointer',
      );
    }

    final raw = pointer.toDartString();
    _freeString(pointer);

    dynamic decodedJson;
    try {
      decodedJson = jsonDecode(raw);
    } catch (_) {
      throw StrollBridgeException(
        code: 'INVALID_NATIVE_RESPONSE',
        message: raw,
      );
    }

    final envelope = asJsonMap(decodedJson);
    final ok = envelope['ok'] == true;

    if (!ok) {
      final error = envelope['error'];
      final mappedError = StrollErrorModel.fromJson(
        error is Map<String, dynamic> ? error : asJsonMap(error ?? const {}),
      );
      throw StrollBridgeException(
        code: mappedError.code,
        message: mappedError.message,
      );
    }

    return envelope;
  }

  Pointer<Utf8> _toNullableUtf8(String? value) {
    if (value == null || value.isEmpty) {
      return nullptr;
    }
    return value.toNativeUtf8();
  }

  void _freeNullableUtf8(Pointer<Utf8> pointer) {
    if (pointer != nullptr) {
      calloc.free(pointer);
    }
  }
}
