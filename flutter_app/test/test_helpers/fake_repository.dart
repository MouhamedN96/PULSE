import 'package:stroll/data/stroll_models.dart';
import 'package:stroll/data/stroll_repository.dart';

class FakeStrollRepository implements StrollRepository {
  FakeStrollRepository({this.shouldThrow = false});

  final bool shouldThrow;
  RecommendationBackendStatus _backendStatus = const RecommendationBackendStatus(
    mode: RecommendationBackendMode.ffiFallback,
    label: 'FFI',
    detail: 'Fake repository',
  );

  @override
  RecommendationBackendStatus get recommendationBackendStatus => _backendStatus;

  final List<ActivityModel> _activities = [
    ActivityModel(
      id: 'act-1',
      name: 'The Commune Social',
      description: 'Modern tapas restaurant',
      category: 'food',
      subcategories: const ['spanish'],
      location: const LocationModel(
        lat: 31.2304,
        lng: 121.4737,
        address: '511 Jiangning Rd',
        neighborhood: 'Jingan',
        city: 'Shanghai',
      ),
      rating: 4.6,
      reviewCount: 1243,
      priceLevel: 3,
      images: const [
        'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop',
      ],
      openHours: '11:30 AM - 10:30 PM',
      phone: '+86 21 6047 7638',
      website: null,
      tags: const ['tapas', 'spanish'],
      distance: '0.8 km',
      isOpen: true,
      aiSummary: 'A trendy spot for sharing plates with friends.',
      whyRecommended: 'Based on your love for Spanish cuisine.',
    ),
    ActivityModel(
      id: 'act-2',
      name: 'Pure Yoga',
      description: 'Premium yoga studio',
      category: 'wellness',
      subcategories: const [],
      location: const LocationModel(
        lat: 31.2284,
        lng: 121.4637,
        address: 'Shanghai Centre',
        neighborhood: 'Jingan',
        city: 'Shanghai',
      ),
      rating: 4.8,
      reviewCount: 567,
      priceLevel: 4,
      images: const [
        'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=300&fit=crop',
      ],
      openHours: '6:00 AM - 10:00 PM',
      phone: '+86 21 6279 8778',
      website: null,
      tags: const ['yoga', 'wellness'],
      distance: '0.5 km',
      isOpen: true,
      aiSummary: 'Luxury yoga experience with top instructors.',
      whyRecommended: 'Matches your wellness preferences.',
    ),
  ];

  late final UserModel _user = UserModel(
    id: 'user-1',
    name: 'Sarah Kim',
    avatar:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&h=150&fit=crop&crop=face',
    bio: 'Fashion blogger',
    location: 'Shanghai',
    followers: 120,
    following: 30,
    checkins: 18,
    preferences: const ['food'],
    isFollowing: true,
  );

  @override
  Future<void> initialize({
    String? databasePath,
    String? recommendationApiBaseUrl,
  }) async {
    if (shouldThrow) {
      throw StrollAppException(code: 'INIT_FAILED', message: 'Initialization failed');
    }
  }

  @override
  Future<FeedResponseModel> getFeed() async {
    if (shouldThrow) {
      throw StrollAppException(code: 'FEED_FAILED', message: 'Feed failed');
    }

    return FeedResponseModel(
      recommendations: _activities,
      posts: [
        PostModel(
          id: 'post-1',
          user: _user,
          activity: _activities.first,
          image: _activities.first.images.first,
          caption: 'Amazing tapas night!',
          likes: 45,
          comments: 8,
          timestamp: '2 hours ago',
          isLiked: true,
        ),
      ],
      trendingTags: const ['#ShanghaiEats'],
    );
  }

  @override
  Future<AgentResponseModel> processVoiceQuery({
    required String query,
    GeoLocationModel? location,
    String? imageAnalysis,
    String? provider,
  }) async {
    if (shouldThrow) {
      throw StrollAppException(code: 'VOICE_FAILED', message: 'Voice query failed');
    }

    _backendStatus = const RecommendationBackendStatus(
      mode: RecommendationBackendMode.api,
      label: 'API',
      detail: 'Fake repository',
    );

    return AgentResponseModel(
      summary: 'I found great matches for "$query".',
      activities: _activities,
      filters: const [
        FilterOptionModel(id: 'all', label: 'All', icon: null, category: null),
        FilterOptionModel(id: 'food', label: 'Food', icon: null, category: 'food'),
      ],
      query: VoiceQueryModel(
        text: query,
        location: location,
        timestamp: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Future<NetworkResponseModel> getNetwork() async {
    if (shouldThrow) {
      throw StrollAppException(code: 'NETWORK_FAILED', message: 'Network failed');
    }

    return NetworkResponseModel(
      following: [_user],
      suggested: [
        UserModel(
          id: 'user-2',
          name: 'Mike',
          avatar: _user.avatar,
          bio: 'Traveler',
          location: 'Shanghai',
          followers: 40,
          following: 12,
          checkins: 5,
          preferences: const ['wellness'],
          isFollowing: false,
        ),
      ],
      requests: [
        NetworkRequestModel(
          id: 'req-1',
          user: _user,
          message: 'Let us connect!',
          timestamp: '1 hour ago',
          status: 'pending',
        ),
      ],
    );
  }

  @override
  Future<void> followUser(String userId) async {
    if (shouldThrow) {
      throw StrollAppException(code: 'FOLLOW_FAILED', message: 'Follow failed');
    }
  }

  @override
  Future<List<ActivityModel>> getTrending({String? category}) async {
    if (shouldThrow) {
      throw StrollAppException(code: 'TRENDING_FAILED', message: 'Trending failed');
    }

    if (category == null || category == 'all') {
      return _activities;
    }

    return _activities
        .where((activity) => activity.category == category)
        .toList(growable: false);
  }

  @override
  Future<void> saveActivity(String activityId) async {
    if (shouldThrow) {
      throw StrollAppException(code: 'SAVE_FAILED', message: 'Save failed');
    }
  }

  @override
  Future<List<ActivityModel>> getSavedActivities() async {
    if (shouldThrow) {
      throw StrollAppException(code: 'SAVED_FAILED', message: 'Saved activities failed');
    }

    return _activities.take(1).toList(growable: false);
  }

  @override
  Future<void> dispose() async {}
}
