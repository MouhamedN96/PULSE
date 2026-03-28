import 'package:flutter_test/flutter_test.dart';
import 'package:stroll/data/stroll_models.dart';

void main() {
  group('ActivityModel', () {
    test('parses rust snake_case payload', () {
      final model = ActivityModel.fromJson({
        'id': 'act-1',
        'name': 'The Commune Social',
        'description': 'Modern tapas',
        'category': 'Food',
        'subcategories': ['Spanish', 'Dinner'],
        'location': {
          'lat': 31.2304,
          'lng': 121.4737,
          'address': '511 Jiangning Rd',
          'neighborhood': 'Jingan',
          'city': 'Shanghai',
        },
        'rating': 4.6,
        'review_count': 1243,
        'price_level': 3,
        'images': ['https://example.com/image.jpg'],
        'open_hours': '11:30 AM - 10:30 PM',
        'tags': ['tapas', 'spanish'],
        'distance': '0.8 km',
        'is_open': true,
      });

      expect(model.category, 'food');
      expect(model.subcategories, contains('spanish'));
      expect(model.reviewCount, 1243);
      expect(model.isOpen, isTrue);
    });
  });

  group('NetworkRequestModel', () {
    test('normalizes status casing', () {
      final request = NetworkRequestModel.fromJson({
        'id': 'req-1',
        'user': {
          'id': 'user-1',
          'name': 'Alex',
          'avatar': 'https://example.com/avatar.jpg',
          'bio': 'bio',
          'location': 'Shanghai',
          'followers': 1,
          'following': 1,
          'checkins': 1,
          'preferences': ['Food'],
          'is_following': false,
        },
        'message': 'hello',
        'timestamp': 'today',
        'status': 'Pending',
      });

      expect(request.status, 'pending');
    });
  });
}
