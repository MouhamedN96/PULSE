import 'dart:convert';

String _toSnakeCase(String value) {
  final withUnderscore = value.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (m) => '${m[1]}_${m[2]}',
  );
  return withUnderscore.toLowerCase();
}

Map<String, dynamic> asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  throw const FormatException('Expected JSON object');
}

List<Map<String, dynamic>> asJsonMapList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value.map((entry) => asJsonMap(entry)).toList(growable: false);
}

List<String> asStringList(dynamic value) {
  if (value is! List) {
    return const [];
  }

  return value.map((entry) => entry.toString()).toList(growable: false);
}

int asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  final normalized = value?.toString().toLowerCase();
  if (normalized == 'true') return true;
  if (normalized == 'false') return false;
  return fallback;
}

class GeoLocationModel {
  const GeoLocationModel({
    required this.lat,
    required this.lng,
  });

  final double lat;
  final double lng;

  factory GeoLocationModel.fromJson(Map<String, dynamic> json) {
    return GeoLocationModel(
      lat: asDouble(json['lat']),
      lng: asDouble(json['lng']),
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
      };
}

class LocationModel {
  const LocationModel({
    required this.lat,
    required this.lng,
    required this.address,
    required this.neighborhood,
    required this.city,
  });

  final double lat;
  final double lng;
  final String address;
  final String neighborhood;
  final String city;

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      lat: asDouble(json['lat']),
      lng: asDouble(json['lng']),
      address: json['address']?.toString() ?? '',
      neighborhood: json['neighborhood']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'address': address,
        'neighborhood': neighborhood,
        'city': city,
      };
}

class ActivityModel {
  const ActivityModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.subcategories,
    required this.location,
    required this.rating,
    required this.reviewCount,
    required this.priceLevel,
    required this.images,
    required this.openHours,
    required this.phone,
    required this.website,
    required this.tags,
    required this.distance,
    required this.isOpen,
    required this.aiSummary,
    required this.whyRecommended,
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final List<String> subcategories;
  final LocationModel location;
  final double rating;
  final int reviewCount;
  final int priceLevel;
  final List<String> images;
  final String openHours;
  final String? phone;
  final String? website;
  final List<String> tags;
  final String? distance;
  final bool isOpen;
  final String? aiSummary;
  final String? whyRecommended;

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    return ActivityModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      category: _toSnakeCase(json['category']?.toString() ?? ''),
      subcategories: asStringList(json['subcategories'])
          .map(_toSnakeCase)
          .toList(growable: false),
      location: LocationModel.fromJson(asJsonMap(json['location'] ?? const {})),
      rating: asDouble(json['rating']),
      reviewCount: asInt(json['review_count'] ?? json['reviewCount']),
      priceLevel: asInt(json['price_level'] ?? json['priceLevel'], fallback: 1),
      images: asStringList(json['images']),
      openHours: json['open_hours']?.toString() ?? json['openHours']?.toString() ?? '',
      phone: json['phone']?.toString(),
      website: json['website']?.toString(),
      tags: asStringList(json['tags']),
      distance: json['distance']?.toString(),
      isOpen: asBool(json['is_open'] ?? json['isOpen'], fallback: true),
      aiSummary: json['ai_summary']?.toString() ?? json['aiSummary']?.toString(),
      whyRecommended: json['why_recommended']?.toString() ?? json['whyRecommended']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'subcategories': subcategories,
        'location': location.toJson(),
        'rating': rating,
        'review_count': reviewCount,
        'price_level': priceLevel,
        'images': images,
        'open_hours': openHours,
        'phone': phone,
        'website': website,
        'tags': tags,
        'distance': distance,
        'is_open': isOpen,
        'ai_summary': aiSummary,
        'why_recommended': whyRecommended,
      };
}

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.bio,
    required this.location,
    required this.followers,
    required this.following,
    required this.checkins,
    required this.preferences,
    required this.isFollowing,
  });

  final String id;
  final String name;
  final String avatar;
  final String bio;
  final String location;
  final int followers;
  final int following;
  final int checkins;
  final List<String> preferences;
  final bool isFollowing;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      bio: json['bio']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      followers: asInt(json['followers']),
      following: asInt(json['following']),
      checkins: asInt(json['checkins']),
      preferences: asStringList(json['preferences'])
          .map(_toSnakeCase)
          .toList(growable: false),
      isFollowing: asBool(json['is_following'] ?? json['isFollowing']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'bio': bio,
        'location': location,
        'followers': followers,
        'following': following,
        'checkins': checkins,
        'preferences': preferences,
        'is_following': isFollowing,
      };
}

class PostModel {
  const PostModel({
    required this.id,
    required this.user,
    required this.activity,
    required this.image,
    required this.caption,
    required this.likes,
    required this.comments,
    required this.timestamp,
    required this.isLiked,
  });

  final String id;
  final UserModel user;
  final ActivityModel activity;
  final String image;
  final String caption;
  final int likes;
  final int comments;
  final String timestamp;
  final bool isLiked;

  factory PostModel.fromJson(Map<String, dynamic> json) {
    return PostModel(
      id: json['id']?.toString() ?? '',
      user: UserModel.fromJson(asJsonMap(json['user'] ?? const {})),
      activity: ActivityModel.fromJson(asJsonMap(json['activity'] ?? const {})),
      image: json['image']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      likes: asInt(json['likes']),
      comments: asInt(json['comments']),
      timestamp: json['timestamp']?.toString() ?? '',
      isLiked: asBool(json['is_liked'] ?? json['isLiked']),
    );
  }
}

class NetworkRequestModel {
  const NetworkRequestModel({
    required this.id,
    required this.user,
    required this.message,
    required this.timestamp,
    required this.status,
  });

  final String id;
  final UserModel user;
  final String message;
  final String timestamp;
  final String status;

  factory NetworkRequestModel.fromJson(Map<String, dynamic> json) {
    return NetworkRequestModel(
      id: json['id']?.toString() ?? '',
      user: UserModel.fromJson(asJsonMap(json['user'] ?? const {})),
      message: json['message']?.toString() ?? '',
      timestamp: json['timestamp']?.toString() ?? '',
      status: _toSnakeCase(json['status']?.toString() ?? 'pending'),
    );
  }
}

class FilterOptionModel {
  const FilterOptionModel({
    required this.id,
    required this.label,
    required this.icon,
    required this.category,
  });

  final String id;
  final String label;
  final String? icon;
  final String? category;

  factory FilterOptionModel.fromJson(Map<String, dynamic> json) {
    return FilterOptionModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      icon: json['icon']?.toString(),
      category: json['category'] != null
          ? _toSnakeCase(json['category'].toString())
          : null,
    );
  }
}

class VoiceQueryModel {
  const VoiceQueryModel({
    required this.text,
    required this.location,
    required this.timestamp,
  });

  final String text;
  final GeoLocationModel? location;
  final String timestamp;

  factory VoiceQueryModel.fromJson(Map<String, dynamic> json) {
    final locationRaw = json['location'];

    return VoiceQueryModel(
      text: json['text']?.toString() ?? '',
      location: locationRaw == null
          ? null
          : GeoLocationModel.fromJson(asJsonMap(locationRaw)),
      timestamp: json['timestamp']?.toString() ?? '',
    );
  }
}

class AgentResponseModel {
  const AgentResponseModel({
    required this.summary,
    required this.activities,
    required this.filters,
    required this.query,
  });

  final String summary;
  final List<ActivityModel> activities;
  final List<FilterOptionModel> filters;
  final VoiceQueryModel query;

  factory AgentResponseModel.fromJson(Map<String, dynamic> json) {
    return AgentResponseModel(
      summary: json['summary']?.toString() ?? '',
      activities: asJsonMapList(json['activities'])
          .map(ActivityModel.fromJson)
          .toList(growable: false),
      filters: asJsonMapList(json['filters'])
          .map(FilterOptionModel.fromJson)
          .toList(growable: false),
      query: VoiceQueryModel.fromJson(asJsonMap(json['query'] ?? const {})),
    );
  }
}

class FeedResponseModel {
  const FeedResponseModel({
    required this.recommendations,
    required this.posts,
    required this.trendingTags,
  });

  final List<ActivityModel> recommendations;
  final List<PostModel> posts;
  final List<String> trendingTags;

  factory FeedResponseModel.fromJson(Map<String, dynamic> json) {
    return FeedResponseModel(
      recommendations: asJsonMapList(json['recommendations'])
          .map(ActivityModel.fromJson)
          .toList(growable: false),
      posts: asJsonMapList(json['posts'])
          .map(PostModel.fromJson)
          .toList(growable: false),
      trendingTags: asStringList(json['trending_tags'] ?? json['trendingTags']),
    );
  }
}

class NetworkResponseModel {
  const NetworkResponseModel({
    required this.following,
    required this.suggested,
    required this.requests,
  });

  final List<UserModel> following;
  final List<UserModel> suggested;
  final List<NetworkRequestModel> requests;

  factory NetworkResponseModel.fromJson(Map<String, dynamic> json) {
    return NetworkResponseModel(
      following: asJsonMapList(json['following'])
          .map(UserModel.fromJson)
          .toList(growable: false),
      suggested: asJsonMapList(json['suggested'])
          .map(UserModel.fromJson)
          .toList(growable: false),
      requests: asJsonMapList(json['requests'])
          .map(NetworkRequestModel.fromJson)
          .toList(growable: false),
    );
  }
}

class StrollErrorModel {
  const StrollErrorModel({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  factory StrollErrorModel.fromJson(Map<String, dynamic> json) {
    return StrollErrorModel(
      code: json['code']?.toString() ?? 'UNKNOWN',
      message: json['message']?.toString() ?? 'Unknown error',
    );
  }

  @override
  String toString() => jsonEncode({'code': code, 'message': message});
}
