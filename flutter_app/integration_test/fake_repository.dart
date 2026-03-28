import 'package:stroll/data/stroll_models.dart';
import 'package:stroll/data/stroll_repository.dart';

class IntegrationFakeRepository implements StrollRepository {
  @override
  RecommendationBackendStatus get recommendationBackendStatus =>
      const RecommendationBackendStatus(
        mode: RecommendationBackendMode.ffiFallback,
        label: 'FFI',
        detail: 'Fake repository',
      );

  @override
  Future<void> dispose() async {}

  @override
  Future<void> followUser(String userId) async {}

  @override
  Future<NetworkResponseModel> getNetwork() async {
    return NetworkResponseModel(
      following: const [],
      suggested: const [],
      requests: const [
        NetworkRequestModel(
          id: 'req-1',
          user: UserModel(
            id: 'user-1',
            name: 'Alex',
            avatar: 'https://example.com/avatar.png',
            bio: 'Bio',
            location: 'Shanghai',
            followers: 1,
            following: 1,
            checkins: 1,
            preferences: ['food'],
            isFollowing: false,
          ),
          message: 'hello',
          timestamp: 'today',
          status: 'pending',
        ),
      ],
    );
  }

  @override
  Future<FeedResponseModel> getFeed() async {
    return FeedResponseModel(
      recommendations: const [
        ActivityModel(
          id: 'act-1',
          name: 'Spot',
          description: 'desc',
          category: 'food',
          subcategories: ['italian'],
          location: LocationModel(
            lat: 0,
            lng: 0,
            address: 'addr',
            neighborhood: 'Jingan',
            city: 'Shanghai',
          ),
          rating: 4.4,
          reviewCount: 2,
          priceLevel: 2,
          images: ['https://example.com/image.jpg'],
          openHours: '9-5',
          phone: null,
          website: null,
          tags: ['tag'],
          distance: '0.5 km',
          isOpen: true,
          aiSummary: null,
          whyRecommended: null,
        ),
      ],
      posts: const [],
      trendingTags: const ['#tag'],
    );
  }

  @override
  Future<List<ActivityModel>> getSavedActivities() async => const [];

  @override
  Future<List<ActivityModel>> getTrending({String? category}) async => const [];

  @override
  Future<void> initialize({
    String? databasePath,
    String? recommendationApiBaseUrl,
  }) async {}

  @override
  Future<AgentResponseModel> processVoiceQuery({
    required String query,
    GeoLocationModel? location,
    String? imageAnalysis,
    String? provider,
  }) async {
    return AgentResponseModel(
      summary: 'summary',
      activities: const [],
      filters: const [
        FilterOptionModel(id: 'all', label: 'All', icon: null, category: null),
      ],
      query: VoiceQueryModel(
        text: query,
        location: location,
        timestamp: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Future<void> saveActivity(String activityId) async {}
}
