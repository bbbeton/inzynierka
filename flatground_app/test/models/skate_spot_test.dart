import 'package:flutter_test/flutter_test.dart';
import 'package:flatground_app/models/skate_spot.dart';

void main() {
  test('SkateSpot.fromJson parses backend payload', () {
    final spot = SkateSpot.fromJson({
      'id': 7,
      'name': 'Plac',
      'type': 'Street',
      'address': 'Warsaw',
      'latitude': 52.2,
      'longitude': 21.0,
      'description': 'Nice ledges',
      'difficulty': 'intermediate',
      'photo_urls': ['/uploads/a.jpg'],
      'created_at': '2026-04-14T10:00:00Z',
    });

    expect(spot.id, '7');
    expect(spot.name, 'Plac');
    expect(spot.difficulty, 'intermediate');
    expect(spot.photoUrls, ['/uploads/a.jpg']);
    expect(spot.createdAt, isNotNull);
  });

  test('toCreateJson omits derived fields', () {
    const spot = SkateSpot(
      id: '1',
      name: 'Spot',
      type: 'Bowl',
      address: 'Address',
      latitude: 52.1,
      longitude: 21.1,
      description: 'Desc',
    );

    expect(spot.toCreateJson(), {
      'name': 'Spot',
      'type': 'Bowl',
      'address': 'Address',
      'latitude': 52.1,
      'longitude': 21.1,
      'description': 'Desc',
      'difficulty': 'beginner',
    });
  });
}
