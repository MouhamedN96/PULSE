import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/stroll_models.dart';
import '../../data/stroll_repository.dart';
import 'discover_world_models.dart';

class DiscoverWorldController extends ChangeNotifier {
  DiscoverWorldController({
    required StrollRepository repository,
  }) : _repository = repository {
    final backendStatus = repository.recommendationBackendStatus;
    _state = DiscoverWorldState.initial(
      backendLabel: backendStatus.label,
      backendDetail: backendStatus.detail,
    );
  }

  final StrollRepository _repository;

  DiscoverWorldState _state =
      DiscoverWorldState.initial(backendLabel: 'Loading');
  DiscoverWorldState get state => _state;

  final Map<String, ActivityModel> _catalog = <String, ActivityModel>{};
  final List<DiscoverWorldQueryRecord> _queryHistory =
      <DiscoverWorldQueryRecord>[];
  final Set<String> _seenActivityIds = <String>{};
  final Set<String> _savedActivityIds = <String>{};
  final Set<String> _preferredCategories = <String>{};
  final Set<String> _preferredTags = <String>{};
  final Set<String> _followingUserNames = <String>{};
  final List<String> _warnings = <String>[];
  String? _currentQueryText;
  DiscoverWorldInputKind? _currentQueryKind;
  String? _currentQueryProvider;
  GeoLocationModel? _currentLocation;
  String? _latestSummary;

  Future<void> load() async {
    _setState(_state.copyWith(
      isLoading: true,
      isRefreshing: false,
      clearError: true,
      warnings: const [],
    ));

    final feedResult = await _safe(() => _repository.getFeed());
    final networkResult = await _safe(() => _repository.getNetwork());
    final trendingResult = await _safe(() => _repository.getTrending());
    final savedResult = await _safe(() => _repository.getSavedActivities());

    final failures = <String>[
      if (feedResult.error != null) 'feed: ${feedResult.error}',
      if (networkResult.error != null) 'network: ${networkResult.error}',
      if (trendingResult.error != null) 'trending: ${trendingResult.error}',
      if (savedResult.error != null) 'saved: ${savedResult.error}',
    ];

    _ingestRepositoryData(
      feed: feedResult.value,
      network: networkResult.value,
      trending: trendingResult.value,
      savedActivities: savedResult.value,
    );

    final derived = _deriveWorld();
    _setState(
      derived.copyWith(
        isLoading: false,
        isRefreshing: false,
        warnings: failures,
        errorMessage: failures.isEmpty ? null : derived.errorMessage,
      ),
    );
  }

  Future<void> refresh() async {
    if (_state.isLoading) {
      return load();
    }

    _setState(_state.copyWith(isRefreshing: true, clearError: true));
    await load();
  }

  Future<void> submitText(String text, {String? provider}) {
    return _submitQuery(
      text: text,
      kind: DiscoverWorldInputKind.text,
      provider: provider,
    );
  }

  Future<void> submitVoice(String text, {String? provider}) {
    return _submitQuery(
      text: text,
      kind: DiscoverWorldInputKind.voice,
      provider: provider,
    );
  }

  Future<void> saveActivity(String activityId) async {
    final activity = _catalog[activityId];
    if (activity == null) {
      return;
    }

    try {
      await _repository.saveActivity(activityId);
    } catch (error) {
      _setState(_state.copyWith(errorMessage: error.toString()));
      return;
    }

    _savedActivityIds.add(activityId);
    _preferredCategories
      ..add(activity.category)
      ..addAll(activity.subcategories);
    _preferredTags.addAll(activity.tags.map((tag) => tag.toLowerCase()));

    final derived = _deriveWorld();
    _setState(
      derived.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: null,
        selectedActivityId: activityId,
        selectedClusterId: _clusterIdFor(activity),
      ),
    );
  }

  Future<void> _submitQuery({
    required String text,
    required DiscoverWorldInputKind kind,
    String? provider,
  }) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return;
    }

    _currentQueryText = normalized;
    _currentQueryKind = kind;
    _currentQueryProvider = provider;
    _currentLocation =
        _currentLocation ?? const GeoLocationModel(lat: 40.7128, lng: -74.0060);

    _setState(_state.copyWith(
      isLoading: _state.activities.isEmpty,
      isRefreshing: _state.activities.isNotEmpty,
      clearError: true,
    ));

    try {
      final response = await _repository.processVoiceQuery(
        query: normalized,
        location: _currentLocation,
        provider: provider,
      );

      _ingestVoiceResponse(response);
      _latestSummary = response.summary;
      _queryHistory.add(
        DiscoverWorldQueryRecord(
          text: normalized,
          kind: kind,
          provider: provider,
          submittedAt: DateTime.now(),
          summary: response.summary,
          resultCount: response.activities.length,
        ),
      );

      final derived = _deriveWorld();
      _setState(
        derived.copyWith(
          isLoading: false,
          isRefreshing: false,
          errorMessage: null,
        ),
      );
    } catch (error) {
      _setState(_state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: error.toString(),
      ));
    }
  }

  void selectActivity(String? activityId) {
    if (activityId != null) {
      _seenActivityIds.add(activityId);
      final activity = _catalog[activityId];
      if (activity != null) {
        _preferredCategories.add(activity.category);
        _preferredTags.addAll(activity.tags.map((tag) => tag.toLowerCase()));
      }
    }
    _setState(_state.copyWith(selectedActivityId: activityId));
  }

  void selectCluster(String? clusterId) {
    _setState(_state.copyWith(selectedClusterId: clusterId));
  }

  void clearSelection() {
    _setState(_state.copyWith(
      clearSelectedActivity: true,
      clearSelectedCluster: true,
    ));
  }

  Map<String, dynamic> toBridgeJson() => _state.toBridgeJson();

  void _ingestRepositoryData({
    FeedResponseModel? feed,
    NetworkResponseModel? network,
    List<ActivityModel>? trending,
    List<ActivityModel>? savedActivities,
  }) {
    _catalog.clear();
    _warnings.clear();
    _savedActivityIds.clear();
    _preferredCategories.clear();
    _preferredTags.clear();
    _followingUserNames.clear();

    final activities = <ActivityModel>[
      ...?feed?.recommendations,
      ...?trending,
      ...?savedActivities,
      ...?feed?.posts.map((post) => post.activity),
    ];

    for (final activity in activities) {
      _catalog[activity.id] = activity;
    }

    if (savedActivities != null) {
      _savedActivityIds.addAll(savedActivities.map((activity) => activity.id));
    }

    if (feed != null) {
      _preferredTags.addAll(feed.trendingTags);
      for (final activity in feed.recommendations) {
        _preferredCategories.add(activity.category);
      }
      for (final post in feed.posts) {
        _preferredCategories.add(post.activity.category);
      }
    }

    if (trending != null) {
      for (final activity in trending) {
        _preferredCategories.add(activity.category);
      }
    }

    if (network != null) {
      for (final user in network.following) {
        _preferredCategories.addAll(user.preferences);
        _followingUserNames.add(user.name);
      }
      for (final user in network.suggested) {
        _preferredCategories.addAll(user.preferences);
      }
    }

    _seenActivityIds.addAll(_catalog.keys);
  }

  void _ingestVoiceResponse(AgentResponseModel response) {
    for (final activity in response.activities) {
      _catalog[activity.id] = activity;
      _seenActivityIds.add(activity.id);
    }

    for (final filter in response.filters) {
      if (filter.category != null) {
        _preferredCategories.add(filter.category!);
      }
    }

    _preferredTags.addAll(_tokenize(response.summary));
  }

  DiscoverWorldState _deriveWorld() {
    final queryText = _currentQueryText ?? _state.query?.text ?? '';
    final kind =
        _currentQueryKind ?? _state.query?.kind ?? DiscoverWorldInputKind.text;
    final provider = _currentQueryProvider ?? _state.query?.provider;
    final latestRecord = _queryHistory.isEmpty ? null : _queryHistory.last;
    final queryRecord = latestRecord ??
        (queryText.isEmpty
            ? null
            : DiscoverWorldQueryRecord(
                text: queryText,
                kind: kind,
                provider: provider,
                submittedAt: DateTime.now(),
                summary: _latestSummary,
                resultCount: _catalog.length,
              ));

    final queryTokens = _tokenize(queryText);
    final maxReviewCount = math.max(
        1,
        _catalog.values.isEmpty
            ? 1
            : _catalog.values
                .map((activity) => activity.reviewCount)
                .reduce(math.max));
    final catalogValues = _catalog.values.toList(growable: false);

    final scored = <_ScoredActivity>[
      for (final activity in catalogValues)
        _ScoredActivity(
          activity: activity,
          score: _scoreActivity(
            activity,
            queryTokens: queryTokens,
            maxReviewCount: maxReviewCount,
          ),
        ),
    ]..sort((a, b) => b.score.compareTo(a.score));

    final activities = <DiscoverWorldActivityView>[];
    for (var index = 0; index < scored.length; index++) {
      final item = scored[index];
      activities.add(
        DiscoverWorldActivityView(
          activity: item.activity,
          rank: index + 1,
          score: item.score,
          clusterId: _clusterIdFor(item.activity),
          clusterLabel: _clusterLabelFor(item.activity),
          signals: _buildSignals(item.activity, queryTokens),
          isSaved: _savedActivityIds.contains(item.activity.id),
          isTrending:
              _preferredTags.any((tag) => _matchesField(tag, item.activity)),
          isQueryMatch: queryTokens.isNotEmpty &&
              _matchesQuery(item.activity, queryTokens),
          isPersonalized: _preferredCategories
                  .contains(item.activity.category) ||
              item.activity.subcategories.any(_preferredCategories.contains) ||
              item.activity.tags.any(_preferredTags.contains),
          overlayX: 0,
          overlayY: 0,
        ),
      );
    }

    final clusters = _buildClusters(activities);
    final overlays = _buildOverlays(activities, clusters);
    final selectedActivityId =
        _state.selectedActivityId ?? activities.firstOrNull?.activity.id;
    final selectedClusterId =
        _state.selectedClusterId ?? clusters.firstOrNull?.id;

    final personalization = DiscoverWorldPersonalizationProfile(
      preferredCategories: _preferredCategories.toList(growable: false)..sort(),
      preferredTags: _preferredTags.toList(growable: false)..sort(),
      savedActivityIds: _savedActivityIds.toList(growable: false)..sort(),
      seenActivityIds: _seenActivityIds.toList(growable: false)..sort(),
      queryHistory: _queryHistory.toList(growable: false),
      followingUserNames: _followingUserNames.toList(growable: false)..sort(),
    );

    final warnings = List<String>.from(_state.warnings);

    return DiscoverWorldState(
      isLoading: false,
      isRefreshing: false,
      backendLabel: _repository.recommendationBackendStatus.label,
      backendDetail: _repository.recommendationBackendStatus.detail,
      errorMessage: _state.errorMessage,
      warnings: warnings,
      lastUpdated: DateTime.now(),
      activities: activities,
      clusters: clusters,
      overlays: overlays,
      personalization: personalization,
      query: queryRecord,
      selectedActivityId: selectedActivityId,
      selectedClusterId: selectedClusterId,
    );
  }

  String _clusterIdFor(ActivityModel activity) {
    final neighborhood = activity.location.neighborhood.trim().isNotEmpty
        ? activity.location.neighborhood
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), '-')
        : activity.location.city.trim().isNotEmpty
            ? activity.location.city
                .trim()
                .toLowerCase()
                .replaceAll(RegExp(r'\s+'), '-')
            : 'citywide';
    final category = activity.category.trim().isEmpty
        ? 'discover'
        : activity.category.trim();
    return '$category::$neighborhood';
  }

  String _clusterLabelFor(ActivityModel activity) {
    return '${_categoryLabelFor(activity.category)} in ${_neighborhoodLabelFor(activity)}';
  }

  String _categoryLabelFor(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Discover';
    }

    return trimmed
        .split(RegExp(r'[_\-\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _neighborhoodLabelFor(ActivityModel activity) {
    final neighborhood = activity.location.neighborhood.trim();
    if (neighborhood.isNotEmpty) {
      return neighborhood;
    }

    final city = activity.location.city.trim();
    if (city.isNotEmpty) {
      return city;
    }

    return 'Citywide';
  }

  List<DiscoverWorldCluster> _buildClusters(
      List<DiscoverWorldActivityView> activities) {
    final grouped = <String, List<DiscoverWorldActivityView>>{};
    for (final activity in activities) {
      grouped
          .putIfAbsent(activity.clusterId, () => <DiscoverWorldActivityView>[])
          .add(activity);
    }

    final clusters = <DiscoverWorldCluster>[];
    grouped.forEach((clusterId, items) {
      final first = items.first.activity;
      final top = items.reduce(
          (best, current) => current.score > best.score ? current : best);
      final lat = items
              .map((item) => item.activity.location.lat)
              .reduce((a, b) => a + b) /
          items.length;
      final lng = items
              .map((item) => item.activity.location.lng)
              .reduce((a, b) => a + b) /
          items.length;
      clusters.add(
        DiscoverWorldCluster(
          id: clusterId,
          label: _clusterLabelFor(first),
          category: first.category,
          neighborhood: _neighborhoodLabelFor(first),
          activityIds:
              items.map((item) => item.activity.id).toList(growable: false),
          centerLat: lat,
          centerLng: lng,
          score: items.map((item) => item.score).reduce((a, b) => a + b) /
              items.length,
          topActivityId: top.activity.id,
          topActivityName: top.activity.name,
        ),
      );
    });

    clusters.sort((a, b) => b.score.compareTo(a.score));
    return clusters;
  }

  List<DiscoverWorldOverlay> _buildOverlays(
    List<DiscoverWorldActivityView> activities,
    List<DiscoverWorldCluster> clusters,
  ) {
    if (activities.isEmpty) {
      return const [];
    }

    final latitudes = activities
        .map((item) => item.activity.location.lat)
        .toList(growable: false);
    final longitudes = activities
        .map((item) => item.activity.location.lng)
        .toList(growable: false);
    final minLat = latitudes.reduce(math.min);
    final maxLat = latitudes.reduce(math.max);
    final minLng = longitudes.reduce(math.min);
    final maxLng = longitudes.reduce(math.max);
    final latSpan = (maxLat - minLat).abs().clamp(0.000001, 9999.0);
    final lngSpan = (maxLng - minLng).abs().clamp(0.000001, 9999.0);

    final overlays = <DiscoverWorldOverlay>[];
    for (final cluster in clusters) {
      final normalizedX = _normalize(cluster.centerLng, minLng, lngSpan);
      final normalizedY = 1.0 - _normalize(cluster.centerLat, minLat, latSpan);
      overlays.add(
        DiscoverWorldOverlay(
          id: 'cluster:${cluster.id}',
          kind: DiscoverWorldOverlayKind.cluster,
          label: cluster.label,
          subtitle: '${cluster.activityIds.length} places',
          clusterId: cluster.id,
          activityId: cluster.topActivityId,
          x: normalizedX,
          y: normalizedY,
          score: cluster.score,
          count: cluster.activityIds.length,
        ),
      );
    }

    for (final item in activities) {
      overlays.add(
        DiscoverWorldOverlay(
          id: 'activity:${item.activity.id}',
          kind: DiscoverWorldOverlayKind.activity,
          label: item.activity.name,
          subtitle: item.clusterLabel,
          clusterId: item.clusterId,
          activityId: item.activity.id,
          x: _normalize(item.activity.location.lng, minLng, lngSpan),
          y: 1.0 - _normalize(item.activity.location.lat, minLat, latSpan),
          score: item.score,
          count: 1,
        ),
      );
    }

    overlays.sort((a, b) => b.score.compareTo(a.score));
    return overlays;
  }

  double _normalize(double value, double min, double span) {
    if (span <= 0.000001) {
      return 0.5;
    }
    return ((value - min) / span).clamp(0.08, 0.92).toDouble();
  }

  double _scoreActivity(
    ActivityModel activity, {
    required List<String> queryTokens,
    required int maxReviewCount,
  }) {
    final rating = scoreRating(activity.rating);
    final reviews = scoreReviewCount(activity.reviewCount, maxReviewCount);
    final openNow = scoreOpenNow(activity.isOpen);
    final saved = _savedActivityIds.contains(activity.id) ? 1.0 : 0.0;
    final preferredCategory =
        _preferredCategories.contains(activity.category) ? 1.0 : 0.0;
    final preferredTags =
        _preferredTags.where((tag) => _matchesField(tag, activity)).isNotEmpty
            ? 1.0
            : 0.0;
    final queryAffinity =
        queryTokens.isEmpty ? 0.0 : _queryAffinity(activity, queryTokens);
    final distance = _distanceAffinity(activity.distance);
    final networkAffinity = _networkAffinity(activity);

    final score = (rating * 0.24) +
        (reviews * 0.12) +
        (openNow * 0.14) +
        (saved * 0.14) +
        (preferredCategory * 0.11) +
        (preferredTags * 0.08) +
        (queryAffinity * 0.14) +
        (distance * 0.07) +
        (networkAffinity * 0.06);

    return score.clamp(0.0, 1.0).toDouble();
  }

  double _queryAffinity(ActivityModel activity, List<String> queryTokens) {
    final haystack = [
      activity.name,
      activity.description,
      activity.category,
      ...activity.subcategories,
      ...activity.tags,
      activity.location.neighborhood,
      activity.location.city,
    ].join(' ').toLowerCase();

    var matches = 0;
    for (final token in queryTokens) {
      if (haystack.contains(token)) {
        matches++;
      }
    }

    if (queryTokens.isEmpty) {
      return 0.0;
    }
    return (matches / queryTokens.length).clamp(0.0, 1.0).toDouble();
  }

  double _distanceAffinity(String? distance) {
    if (distance == null || distance.trim().isEmpty) {
      return 0.5;
    }

    final lower = distance.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^0-9\.]+'), ' ').trim();
    final first = cleaned.split(RegExp(r'\s+')).firstOrNull;
    final parsed = first == null ? null : double.tryParse(first);
    if (parsed == null) {
      return 0.5;
    }

    if (lower.contains('mi')) {
      return (1.0 / (1.0 + parsed)).clamp(0.0, 1.0).toDouble();
    }
    return (1.0 / (1.0 + parsed / 1000.0)).clamp(0.0, 1.0).toDouble();
  }

  double _networkAffinity(ActivityModel activity) {
    var score = 0.0;
    if (_preferredCategories.contains(activity.category)) {
      score += 0.5;
    }
    if (activity.subcategories.any(_preferredCategories.contains)) {
      score += 0.25;
    }
    if (activity.tags.any(_preferredTags.contains)) {
      score += 0.25;
    }
    return score.clamp(0.0, 1.0).toDouble();
  }

  List<String> _buildSignals(ActivityModel activity, List<String> queryTokens) {
    final signals = <String>[];
    if (_savedActivityIds.contains(activity.id)) {
      signals.add('Saved');
    }
    if (activity.isOpen) {
      signals.add('Open now');
    }
    if (_preferredCategories.contains(activity.category)) {
      signals.add('Matches interest');
    }
    if (queryTokens.isNotEmpty && _matchesQuery(activity, queryTokens)) {
      signals.add('Query match');
    }
    if (activity.aiSummary != null && activity.aiSummary!.isNotEmpty) {
      signals.add('AI brief ready');
    }
    return signals;
  }

  bool _matchesField(String token, ActivityModel activity) {
    final normalizedToken = token.toLowerCase();
    final haystack = [
      activity.name,
      activity.description,
      activity.category,
      ...activity.subcategories,
      ...activity.tags,
      activity.location.neighborhood,
      activity.location.city,
    ].join(' ').toLowerCase();
    return haystack.contains(normalizedToken);
  }

  bool _matchesQuery(ActivityModel activity, List<String> queryTokens) {
    return _queryAffinity(activity, queryTokens) > 0;
  }

  List<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
  }

  Future<_LoadResult<T>> _safe<T>(Future<T> Function() loader) async {
    try {
      return _LoadResult<T>(value: await loader());
    } catch (error) {
      return _LoadResult<T>(error: error.toString());
    }
  }

  void _setState(DiscoverWorldState next) {
    _state = next;
    notifyListeners();
  }
}

class _LoadResult<T> {
  const _LoadResult({this.value, this.error});

  final T? value;
  final String? error;
}

class _ScoredActivity {
  const _ScoredActivity({
    required this.activity,
    required this.score,
  });

  final ActivityModel activity;
  final double score;
}

extension _FirstOrNullExtension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
