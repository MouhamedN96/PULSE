import 'dart:math' as math;

import '../../data/stroll_models.dart';

enum DiscoverWorldInputKind {
  text,
  voice,
}

enum DiscoverWorldOverlayKind {
  cluster,
  activity,
}

String _titleCase(String value) {
  if (value.isEmpty) {
    return value;
  }

  return value
      .split(RegExp(r'[_\-\s]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

String _safeLabel(String value, {String fallback = 'Unknown'}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return fallback;
  }
  return trimmed;
}

String _categoryLabel(String value) {
  return _safeLabel(_titleCase(value), fallback: 'Discover');
}

String _neighborhoodLabel(ActivityModel activity) {
  final location = activity.location;
  if (location.neighborhood.trim().isNotEmpty) {
    return location.neighborhood.trim();
  }
  if (location.city.trim().isNotEmpty) {
    return location.city.trim();
  }
  return 'Citywide';
}

String _clusterLabel(ActivityModel activity) {
  final neighborhood = _neighborhoodLabel(activity);
  return '${_categoryLabel(activity.category)} in $neighborhood';
}

double _clampUnit(double value) => value.clamp(0.0, 1.0).toDouble();

Map<String, dynamic> _stringListMap(List<String> value) => {
      'items': value,
      'count': value.length,
    };

class DiscoverWorldQueryRecord {
  const DiscoverWorldQueryRecord({
    required this.text,
    required this.kind,
    required this.submittedAt,
    this.provider,
    this.summary,
    this.resultCount = 0,
  });

  final String text;
  final DiscoverWorldInputKind kind;
  final DateTime submittedAt;
  final String? provider;
  final String? summary;
  final int resultCount;

  Map<String, dynamic> toJson() => {
        'text': text,
        'kind': kind.name,
        'provider': provider,
        'submitted_at': submittedAt.toIso8601String(),
        'summary': summary,
        'result_count': resultCount,
      };
}

class DiscoverWorldActivityView {
  const DiscoverWorldActivityView({
    required this.activity,
    required this.rank,
    required this.score,
    required this.clusterId,
    required this.clusterLabel,
    required this.signals,
    required this.isSaved,
    required this.isTrending,
    required this.isQueryMatch,
    required this.isPersonalized,
    required this.overlayX,
    required this.overlayY,
  });

  final ActivityModel activity;
  final int rank;
  final double score;
  final String clusterId;
  final String clusterLabel;
  final List<String> signals;
  final bool isSaved;
  final bool isTrending;
  final bool isQueryMatch;
  final bool isPersonalized;
  final double overlayX;
  final double overlayY;

  Map<String, dynamic> toJson({bool selected = false}) => {
        'id': activity.id,
        'name': activity.name,
        'description': activity.description,
        'category': activity.category,
        'subcategories': activity.subcategories,
        'location': activity.location.toJson(),
        'rating': activity.rating,
        'review_count': activity.reviewCount,
        'price_level': activity.priceLevel,
        'images': activity.images,
        'open_hours': activity.openHours,
        'phone': activity.phone,
        'website': activity.website,
        'tags': activity.tags,
        'distance': activity.distance,
        'is_open': activity.isOpen,
        'ai_summary': activity.aiSummary,
        'why_recommended': activity.whyRecommended,
        'rank': rank,
        'score': score,
        'cluster_id': clusterId,
        'cluster_label': clusterLabel,
        'signals': signals,
        'is_saved': isSaved,
        'is_trending': isTrending,
        'is_query_match': isQueryMatch,
        'is_personalized': isPersonalized,
        'overlay_x': overlayX,
        'overlay_y': overlayY,
        'selected': selected,
      };
}

class DiscoverWorldCluster {
  const DiscoverWorldCluster({
    required this.id,
    required this.label,
    required this.category,
    required this.neighborhood,
    required this.activityIds,
    required this.centerLat,
    required this.centerLng,
    required this.score,
    required this.topActivityId,
    required this.topActivityName,
  });

  final String id;
  final String label;
  final String category;
  final String neighborhood;
  final List<String> activityIds;
  final double centerLat;
  final double centerLng;
  final double score;
  final String topActivityId;
  final String topActivityName;

  Map<String, dynamic> toJson({bool selected = false}) => {
        'id': id,
        'label': label,
        'category': category,
        'neighborhood': neighborhood,
        'activity_ids': activityIds,
        'center': {
          'lat': centerLat,
          'lng': centerLng,
        },
        'score': score,
        'top_activity_id': topActivityId,
        'top_activity_name': topActivityName,
        'selected': selected,
      };
}

class DiscoverWorldOverlay {
  const DiscoverWorldOverlay({
    required this.id,
    required this.kind,
    required this.label,
    required this.subtitle,
    required this.clusterId,
    required this.activityId,
    required this.x,
    required this.y,
    required this.score,
    required this.count,
  });

  final String id;
  final DiscoverWorldOverlayKind kind;
  final String label;
  final String subtitle;
  final String clusterId;
  final String? activityId;
  final double x;
  final double y;
  final double score;
  final int count;

  Map<String, dynamic> toJson({bool selected = false}) => {
        'id': id,
        'kind': kind.name,
        'label': label,
        'subtitle': subtitle,
        'cluster_id': clusterId,
        'activity_id': activityId,
        'x': x,
        'y': y,
        'score': score,
        'count': count,
        'selected': selected,
      };
}

class DiscoverWorldPersonalizationProfile {
  const DiscoverWorldPersonalizationProfile({
    required this.preferredCategories,
    required this.preferredTags,
    required this.savedActivityIds,
    required this.seenActivityIds,
    required this.queryHistory,
    required this.followingUserNames,
  });

  final List<String> preferredCategories;
  final List<String> preferredTags;
  final List<String> savedActivityIds;
  final List<String> seenActivityIds;
  final List<DiscoverWorldQueryRecord> queryHistory;
  final List<String> followingUserNames;

  Map<String, dynamic> toJson() => {
        'preferred_categories': _stringListMap(preferredCategories),
        'preferred_tags': _stringListMap(preferredTags),
        'saved_activity_ids': savedActivityIds,
        'seen_activity_ids': seenActivityIds,
        'following_user_names': followingUserNames,
        'query_history': queryHistory
            .map((record) => record.toJson())
            .toList(growable: false),
      };
}

class DiscoverWorldState {
  const DiscoverWorldState({
    required this.isLoading,
    required this.isRefreshing,
    required this.backendLabel,
    required this.backendDetail,
    required this.errorMessage,
    required this.warnings,
    required this.lastUpdated,
    required this.activities,
    required this.clusters,
    required this.overlays,
    required this.personalization,
    required this.query,
    required this.selectedActivityId,
    required this.selectedClusterId,
  });

  final bool isLoading;
  final bool isRefreshing;
  final String backendLabel;
  final String? backendDetail;
  final String? errorMessage;
  final List<String> warnings;
  final DateTime? lastUpdated;
  final List<DiscoverWorldActivityView> activities;
  final List<DiscoverWorldCluster> clusters;
  final List<DiscoverWorldOverlay> overlays;
  final DiscoverWorldPersonalizationProfile personalization;
  final DiscoverWorldQueryRecord? query;
  final String? selectedActivityId;
  final String? selectedClusterId;

  factory DiscoverWorldState.initial({
    required String backendLabel,
    String? backendDetail,
  }) {
    return DiscoverWorldState(
      isLoading: true,
      isRefreshing: false,
      backendLabel: backendLabel,
      backendDetail: backendDetail,
      errorMessage: null,
      warnings: const [],
      lastUpdated: null,
      activities: const [],
      clusters: const [],
      overlays: const [],
      personalization: const DiscoverWorldPersonalizationProfile(
        preferredCategories: [],
        preferredTags: [],
        savedActivityIds: [],
        seenActivityIds: [],
        queryHistory: [],
        followingUserNames: [],
      ),
      query: null,
      selectedActivityId: null,
      selectedClusterId: null,
    );
  }

  int get activityCount => activities.length;

  int get clusterCount => clusters.length;

  DiscoverWorldActivityView? get selectedActivity {
    final selectedId = selectedActivityId;
    if (selectedId == null) {
      return null;
    }
    for (final activity in activities) {
      if (activity.activity.id == selectedId) {
        return activity;
      }
    }
    return null;
  }

  DiscoverWorldCluster? get selectedCluster {
    final selectedId = selectedClusterId;
    if (selectedId == null) {
      return null;
    }
    for (final cluster in clusters) {
      if (cluster.id == selectedId) {
        return cluster;
      }
    }
    return null;
  }

  DiscoverWorldState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? backendLabel,
    String? backendDetail,
    String? errorMessage,
    List<String>? warnings,
    DateTime? lastUpdated,
    List<DiscoverWorldActivityView>? activities,
    List<DiscoverWorldCluster>? clusters,
    List<DiscoverWorldOverlay>? overlays,
    DiscoverWorldPersonalizationProfile? personalization,
    DiscoverWorldQueryRecord? query,
    String? selectedActivityId,
    String? selectedClusterId,
    bool clearError = false,
    bool clearQuery = false,
    bool clearSelectedActivity = false,
    bool clearSelectedCluster = false,
  }) {
    return DiscoverWorldState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      backendLabel: backendLabel ?? this.backendLabel,
      backendDetail: backendDetail ?? this.backendDetail,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      warnings: warnings ?? this.warnings,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      activities: activities ?? this.activities,
      clusters: clusters ?? this.clusters,
      overlays: overlays ?? this.overlays,
      personalization: personalization ?? this.personalization,
      query: clearQuery ? null : (query ?? this.query),
      selectedActivityId: clearSelectedActivity
          ? null
          : (selectedActivityId ?? this.selectedActivityId),
      selectedClusterId: clearSelectedCluster
          ? null
          : (selectedClusterId ?? this.selectedClusterId),
    );
  }

  Map<String, dynamic> toBridgeJson() => {
        'is_loading': isLoading,
        'is_refreshing': isRefreshing,
        'backend_label': backendLabel,
        'backend_detail': backendDetail,
        'error_message': errorMessage,
        'warnings': warnings,
        'last_updated': lastUpdated?.toIso8601String(),
        'activity_count': activityCount,
        'cluster_count': clusterCount,
        'selected_activity_id': selectedActivityId,
        'selected_cluster_id': selectedClusterId,
        'query': query?.toJson(),
        'personalization': personalization.toJson(),
        'activities': activities
            .map((activity) => activity.toJson(
                selected: activity.activity.id == selectedActivityId))
            .toList(growable: false),
        'clusters': clusters
            .map((cluster) =>
                cluster.toJson(selected: cluster.id == selectedClusterId))
            .toList(growable: false),
        'overlays': overlays
            .map((overlay) => overlay.toJson(
                selected: overlay.activityId == selectedActivityId ||
                    overlay.clusterId == selectedClusterId))
            .toList(growable: false),
      };
}

double scoreOpenNow(bool isOpen) => isOpen ? 1.0 : 0.15;

double scoreRating(double rating) => _clampUnit((rating - 3.0) / 2.0);

double scoreReviewCount(int reviewCount, int maxReviewCount) {
  if (reviewCount <= 0 || maxReviewCount <= 0) {
    return 0.0;
  }
  final normalized = (math.log(reviewCount + 1) / math.log(maxReviewCount + 1));
  return _clampUnit(normalized);
}
