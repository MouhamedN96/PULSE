import 'dart:convert';
import 'package:http/http.dart' as http;
import 'stroll_models.dart';

const _remoteApiBaseUrl = 'https://pulse-production-62b2.up.railway.app/api';

String _defaultApiBaseUrl() {
  if (const bool.fromEnvironment('dart.library.html')) {
    return '/api';
  }

  return _remoteApiBaseUrl;
}

String _normalizeApiBaseUrl(String? rawBaseUrl) {
  final trimmed = rawBaseUrl?.trim() ?? '';
  if (trimmed.isEmpty) {
    return _defaultApiBaseUrl();
  }

  final normalized = trimmed.replaceFirst(RegExp(r'/+$'), '');
  if (normalized.endsWith('/api')) {
    return normalized;
  }

  return '$normalized/api';
}

class StrollAppException implements Exception {
  StrollAppException({required this.code, required this.message});

  final String code;
  final String message;

  @override
  String toString() => '[$code] $message';
}

enum RecommendationBackendMode { api, mock }

class RecommendationBackendStatus {
  const RecommendationBackendStatus({
    required this.mode,
    required this.label,
    this.detail,
  });

  final RecommendationBackendMode mode;
  final String label;
  final String? detail;
}

abstract class StrollRepository {
  RecommendationBackendStatus get recommendationBackendStatus;

  Future<void> initialize({String? recommendationApiBaseUrl});
  Future<FeedResponseModel> getFeed();
  Future<AgentResponseModel> processVoiceQuery({
    required String query,
    GeoLocationModel? location,
    String? imageAnalysis,
    String? provider,
  });
  Future<NetworkResponseModel> getNetwork();
  Future<void> followUser(String userId);
  Future<List<ActivityModel>> getTrending({String? category});
  Future<void> saveActivity(String activityId);
  Future<List<ActivityModel>> getSavedActivities();
  Future<void> dispose();
}

class MockStrollRepository implements StrollRepository {
  @override
  RecommendationBackendStatus get recommendationBackendStatus =>
      const RecommendationBackendStatus(mode: RecommendationBackendMode.mock, label: 'MOCK', detail: 'Local Rich Mock Data');

  @override
  Future<void> initialize({String? recommendationApiBaseUrl}) async {}

  final _mockActivity = const ActivityModel(
    id: 'act1',
    name: 'Osteria Morini Night',
    description: 'Rustic Italian cuisine in a lively, dark-wood setting. Known for their homemade pastas and extensive wine selection.',
    category: 'culinary',
    subcategories: ['italian', 'pasta', 'wine'],
    location: LocationModel(lat: 40.722, lng: -73.997, address: '218 Lafayette St', neighborhood: 'SoHo', city: 'New York'),
    rating: 4.8,
    reviewCount: 1240,
    priceLevel: 3,
    images: [
      'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800&q=80',
      'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=800&q=80',
    ],
    openHours: '5:00 PM - 11:00 PM',
    phone: '',
    website: '',
    tags: ['Dinner', 'Date Night'],
    distance: '0.4 mi',
    isOpen: true,
    aiSummary: 'Top-rated rustic Italian pasta highly recommended by your network.',
    whyRecommended: 'You and 4 friends saved similar Italian spots recently.',
  );

   final _mockActivity2 = const ActivityModel(
    id: 'act2',
    name: 'The Django Jazz Bar',
    description: 'Subterranean jazz club bringing Paris in the 1920s to downtown NYC. Vaulted ceilings and brick walls.',
    category: 'entertainment',
    subcategories: ['live_music', 'jazz', 'cocktails'],
    location: LocationModel(lat: 40.718, lng: -74.004, address: '2 6th Ave', neighborhood: 'Tribeca', city: 'New York'),
    rating: 4.7,
    reviewCount: 890,
    priceLevel: 4,
    images: [
      'https://images.unsplash.com/photo-1543160408-f9bffa8bc7b0?w=800&q=80',
    ],
    openHours: '7:00 PM - 2:00 AM',
    phone: '',
    website: '',
    tags: ['Live Music', 'Vibes'],
    distance: '1.2 mi',
    isOpen: false,
    aiSummary: 'Highly curated underground jazz experience matching your culture preference.',
    whyRecommended: 'Perfect atmospheric pairing for post-dinner drinks.',
  );

  final _mockUser = const UserModel(
    id: 'u1',
    name: 'Alex Chen',
    avatar: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face',
    bio: 'Foodie, traveler, and adventure seeker. Always looking for the next great experience!',
    location: 'New York, NY',
    followers: 342,
    following: 128,
    checkins: 89,
    preferences: ['culinary', 'culture', 'wellness'],
    isFollowing: false,
  );

  @override
  Future<FeedResponseModel> getFeed() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return FeedResponseModel(
      recommendations: [_mockActivity, _mockActivity2],
      posts: [
        PostModel(id: 'p1', user: _mockUser, activity: _mockActivity, image: 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800&q=80', caption: 'The truffle pasta here is absolutely unmatched. A must-try! 🍝🔥 #nyceats', likes: 24, comments: 3, timestamp: '2 hours ago', isLiked: true),
      ],
      trendingTags: ['#nycdining', '#jazznight', '#soho'],
    );
  }

  @override
  Future<AgentResponseModel> processVoiceQuery({
    required String query,
    GeoLocationModel? location,
    String? imageAnalysis,
    String? provider,
  }) async {
    await Future.delayed(const Duration(seconds: 1));
    return AgentResponseModel(
      summary: "I found two highly rated spots in NYC that perfectly match your vibe. Osteria Morini has amazing pasta, while The Django offers an incredible 1920s jazz atmosphere.",
      activities: [_mockActivity, _mockActivity2],
      filters: [
        const FilterOptionModel(id: 'f1', label: 'Culinary', category: 'culinary', icon: ''),
        const FilterOptionModel(id: 'f2', label: 'Entertainment', category: 'entertainment', icon: ''),
      ],
      query: VoiceQueryModel(text: query, location: location, timestamp: DateTime.now().toIso8601String()),
    );
  }

  @override
  Future<NetworkResponseModel> getNetwork() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return NetworkResponseModel(
      following: [_mockUser],
      suggested: [_mockUser],
      requests: [],
    );
  }

  @override
  Future<void> followUser(String userId) async {}

  @override
  Future<List<ActivityModel>> getTrending({String? category}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [_mockActivity2, _mockActivity];
  }

  @override
  Future<void> saveActivity(String activityId) async {}

  @override
  Future<List<ActivityModel>> getSavedActivities() async {
    return [_mockActivity];
  }

  @override
  Future<void> dispose() async {}
}

class ApiStrollRepository implements StrollRepository {
  ApiStrollRepository({
    http.Client? client,
    String? initialBaseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = _normalizeApiBaseUrl(initialBaseUrl);

  final http.Client _client;
  String _baseUrl;

  @override
  RecommendationBackendStatus get recommendationBackendStatus =>
      RecommendationBackendStatus(
        mode: RecommendationBackendMode.api,
        label: 'API',
        detail: _baseUrl,
      );

  @override
  Future<void> initialize({String? recommendationApiBaseUrl}) async {
    _baseUrl = _normalizeApiBaseUrl(recommendationApiBaseUrl);
  }

  Uri _buildUri(String path, {Map<String, String>? queryParameters}) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> _getJsonMap(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _client.get(
      _buildUri(path, queryParameters: queryParameters),
    );

    if (response.statusCode != 200) {
      throw StrollAppException(
        code: 'API_ERROR',
        message: 'GET $path failed: ${response.statusCode}',
      );
    }

    return asJsonMap(jsonDecode(response.body));
  }

  Future<List<dynamic>> _getJsonList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _client.get(
      _buildUri(path, queryParameters: queryParameters),
    );

    if (response.statusCode != 200) {
      throw StrollAppException(
        code: 'API_ERROR',
        message: 'GET $path failed: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw StrollAppException(
        code: 'API_ERROR',
        message: 'GET $path returned an unexpected payload',
      );
    }

    return decoded;
  }

  Future<Map<String, dynamic>> _postJsonMap(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      _buildUri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw StrollAppException(
        code: 'API_ERROR',
        message: 'POST $path failed: ${response.statusCode}',
      );
    }

    return asJsonMap(jsonDecode(response.body));
  }

  Future<void> _postExpectSuccess(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final response = await _client.post(
      _buildUri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw StrollAppException(
        code: 'API_ERROR',
        message: 'POST $path failed: ${response.statusCode}',
      );
    }
  }

  @override
  Future<FeedResponseModel> getFeed() async {
    final decoded = await _getJsonMap(
      '/feed',
      queryParameters: const {
        'lat': '40.7128',
        'lng': '-74.0060',
      },
    );
    return FeedResponseModel.fromJson(decoded);
  }

  @override
  Future<AgentResponseModel> processVoiceQuery({
    required String query,
    GeoLocationModel? location,
    String? imageAnalysis,
    String? provider,
  }) async {
    final body = {
      'query': query,
      'lat': location?.lat ?? 40.7128,
      'lng': location?.lng ?? -74.0060,
      if (provider != null) 'provider': provider,
    };
    final decoded = await _postJsonMap('/recommend', body: body);
    return AgentResponseModel.fromJson(decoded);
  }

  @override
  Future<NetworkResponseModel> getNetwork() async {
    final decoded = await _getJsonMap('/network');
    return NetworkResponseModel.fromJson(decoded);
  }

  @override
  Future<void> followUser(String userId) async {
    await _postExpectSuccess('/users/follow', body: {'user_id': userId});
  }

  @override
  Future<List<ActivityModel>> getTrending({String? category}) async {
    final decoded = await _getJsonList(
      '/trending',
      queryParameters: category != null ? {'category': category} : null,
    );
    return decoded
        .map((entry) => ActivityModel.fromJson(asJsonMap(entry)))
        .toList(growable: false);
  }

  @override
  Future<void> saveActivity(String activityId) async {
    await _postExpectSuccess(
      '/activities/save',
      body: {'activity_id': activityId},
    );
  }

  @override
  Future<List<ActivityModel>> getSavedActivities() async {
    final decoded = await _getJsonList('/activities/saved');
    return decoded
        .map((entry) => ActivityModel.fromJson(asJsonMap(entry)))
        .toList(growable: false);
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }
}

class AppServices {
  static StrollRepository repository = ApiStrollRepository();
}
