import 'package:flutter_test/flutter_test.dart';
import 'package:stroll/bridge/stroll_bridge.dart';
import 'package:stroll/data/stroll_models.dart';
import 'package:stroll/data/stroll_repository.dart';

class _FakeBridge implements StrollBridgeClient {
  _FakeBridge({this.throwOnCall = false});

  final bool throwOnCall;
  String? lastDatabasePath;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> followUser(String userId) async {
    if (throwOnCall) {
      throw StrollBridgeException(code: 'FOLLOW_FAIL', message: 'failed');
    }
  }

  @override
  Future<NetworkResponseModel> getNetwork() async {
    if (throwOnCall) {
      throw StrollBridgeException(code: 'NETWORK_FAIL', message: 'failed');
    }

    return const NetworkResponseModel(
      following: [],
      suggested: [],
      requests: [],
    );
  }

  @override
  Future<FeedResponseModel> getPersonalizedFeed() async {
    if (throwOnCall) {
      throw StrollBridgeException(code: 'FEED_FAIL', message: 'failed');
    }

    return const FeedResponseModel(
      recommendations: [],
      posts: [],
      trendingTags: [],
    );
  }

  @override
  Future<List<ActivityModel>> getSavedActivities() async {
    if (throwOnCall) {
      throw StrollBridgeException(code: 'SAVED_FAIL', message: 'failed');
    }
    return const [];
  }

  @override
  Future<List<ActivityModel>> getTrending({String? category}) async {
    if (throwOnCall) {
      throw StrollBridgeException(code: 'TRENDING_FAIL', message: 'failed');
    }
    return const [];
  }

  @override
  Future<void> initialize({String? databasePath}) async {
    lastDatabasePath = databasePath;
    if (throwOnCall) {
      throw StrollBridgeException(code: 'INIT_FAIL', message: 'failed');
    }
  }

  @override
  Future<AgentResponseModel> processVoiceQuery({
    required String query,
    GeoLocationModel? location,
    String? imageAnalysis,
  }) async {
    if (throwOnCall) {
      throw StrollBridgeException(code: 'VOICE_FAIL', message: 'failed');
    }

    return AgentResponseModel(
      summary: 'ok',
      activities: const [],
      filters: const [],
      query: VoiceQueryModel(
        text: query,
        location: location,
        timestamp: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Future<void> saveActivity(String activityId) async {
    if (throwOnCall) {
      throw StrollBridgeException(code: 'SAVE_FAIL', message: 'failed');
    }
  }
}

void main() {
  group('RustStrollRepository', () {
    test('returns typed data on success', () async {
      final bridge = _FakeBridge();
      final repository = RustStrollRepository(bridge: bridge);
      await repository.initialize(databasePath: '/tmp/stroll.sqlite');

      final feed = await repository.getFeed();
      expect(feed.recommendations, isEmpty);

      final network = await repository.getNetwork();
      expect(network.following, isEmpty);
      expect(bridge.lastDatabasePath, '/tmp/stroll.sqlite');
      expect(
        repository.recommendationBackendStatus.mode,
        RecommendationBackendMode.ffiFallback,
      );
    });

    test('reports api backend when recommendation api is configured', () async {
      final repository = RustStrollRepository(bridge: _FakeBridge());
      await repository.initialize(
        databasePath: '/tmp/stroll.sqlite',
        recommendationApiBaseUrl: 'http://127.0.0.1:8787',
      );

      expect(
        repository.recommendationBackendStatus.mode,
        RecommendationBackendMode.api,
      );
    });

    test('maps bridge exception to app exception', () async {
      final repository = RustStrollRepository(bridge: _FakeBridge(throwOnCall: true));

      expect(
        () => repository.initialize(),
        throwsA(isA<StrollAppException>()),
      );
    });
  });
}
