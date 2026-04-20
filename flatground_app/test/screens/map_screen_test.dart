import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flatground_app/models/skate_spot.dart';
import 'package:flatground_app/screens/map_screen.dart';
import 'package:flatground_app/services/skate_spot_api.dart';

class FakeSkateSpotApi extends SkateSpotApi {
  FakeSkateSpotApi({
    this.spots = const [],
    this.shouldFail = false,
  }) : super(baseUrl: 'http://example.com');

  final List<SkateSpot> spots;
  final bool shouldFail;

  @override
  Future<List<SkateSpot>> fetchSpots() async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (shouldFail) {
      throw Exception('failed');
    }
    return spots;
  }

  @override
  void dispose() {}
}

void main() {
  testWidgets('MapScreen shows loaded spot', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          enableLocation: false,
          spotApi: FakeSkateSpotApi(
            spots: const [
              SkateSpot(
                id: '1',
                name: 'Plac Spot',
                type: 'Street',
                address: 'Warsaw',
                latitude: 52.2,
                longitude: 21.0,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Plac Spot'), findsOneWidget);
  });

  testWidgets('MapScreen shows backend error state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MapScreen(
          enableLocation: false,
          spotApi: FakeSkateSpotApi(shouldFail: true),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Could not load skate spots.'), findsOneWidget);
  });
}
