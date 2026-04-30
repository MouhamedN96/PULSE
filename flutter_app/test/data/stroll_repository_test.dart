import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:stroll/data/stroll_repository.dart';

void main() {
  group('ApiStrollRepository', () {
    test('uses the configured local API base URL for feed requests', () async {
      late Uri requestedUri;
      final repository = ApiStrollRepository(
        client: MockClient((request) async {
          requestedUri = request.url;
          return http.Response(
            jsonEncode({
              'recommendations': const [],
              'posts': const [],
              'trending_tags': const ['#test'],
            }),
            200,
          );
        }),
      );

      await repository.initialize(
        recommendationApiBaseUrl: 'http://127.0.0.1:8787',
      );
      final feed = await repository.getFeed();

      expect(
        requestedUri.toString(),
        'http://127.0.0.1:8787/api/feed?lat=40.7128&lng=-74.0060',
      );
      expect(feed.trendingTags, ['#test']);
      expect(
        repository.recommendationBackendStatus.detail,
        'http://127.0.0.1:8787/api',
      );

      await repository.dispose();
    });

    test('maps non-200 responses to app exceptions', () async {
      final repository = ApiStrollRepository(
        client: MockClient((_) async => http.Response('boom', 500)),
      );

      expect(
        repository.getNetwork,
        throwsA(
          isA<StrollAppException>()
              .having((error) => error.code, 'code', 'API_ERROR')
              .having(
                (error) => error.message,
                'message',
                contains('GET /network failed: 500'),
              ),
        ),
      );

      await repository.dispose();
    });
  });
}
