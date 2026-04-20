import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flatground_app/services/skate_spot_api.dart';
import 'package:flatground_app/models/skate_spot.dart';

void main() {
  test('fetchSpots parses backend response', () async {
    final api = SkateSpotApi(
      baseUrl: 'http://example.com',
      client: MockClient((request) async {
        expect(request.url.toString(), 'http://example.com/spots');
        return http.Response(
          '''
          [
            {
              "id": 1,
              "name": "Spot A",
              "type": "Street",
              "address": "Warsaw",
              "latitude": 52.0,
              "longitude": 21.0,
              "description": null,
              "photo_urls": ["/uploads/a.jpg"],
              "created_at": "2026-04-14T10:00:00Z"
            }
          ]
          ''',
          200,
        );
      }),
    );

    final spots = await api.fetchSpots();
    expect(spots, hasLength(1));
    expect(spots.first.name, 'Spot A');
    expect(api.resolvePhotoUrl(spots.first.photoUrls.first), 'http://example.com/uploads/a.jpg');
  });

  test('createSpot throws on non-201 response', () async {
    final api = SkateSpotApi(
      baseUrl: 'http://example.com',
      client: MockClient((request) async => http.Response('{}', 500)),
    );

    expect(
      () => api.createSpot(
        const SkateSpot(
          id: '',
          name: 'Spot',
          type: 'Street',
          address: 'Warsaw',
          latitude: 52,
          longitude: 21,
        ),
      ),
      throwsA(isA<HttpException>()),
    );
  });

  test('baseUrl override trims trailing slash', () {
    final api = SkateSpotApi(
      baseUrl: 'https://api.example.com/',
      client: MockClient((request) async => http.Response('[]', 200)),
    );
    expect(api.baseUrl, 'https://api.example.com');
  });
}
