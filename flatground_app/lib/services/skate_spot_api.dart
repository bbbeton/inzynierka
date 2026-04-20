import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/skate_spot.dart';

class SkateSpotApi {
  SkateSpotApi({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = _resolveBaseUrl(override: baseUrl);

  final http.Client _client;
  final String baseUrl;

  static String _resolveBaseUrl({String? override}) {
    if (override != null && override.isNotEmpty) {
      return override.replaceAll(RegExp(r'/$'), '');
    }
    const explicit = String.fromEnvironment('BACKEND_BASE_URL', defaultValue: '');
    if (explicit.isNotEmpty) {
      return explicit.replaceAll(RegExp(r'/$'), '');
    }
    const appEnv = String.fromEnvironment('APP_ENV', defaultValue: 'dev');
    if (appEnv == 'prod') {
      const prodUrl = String.fromEnvironment(
        'PROD_BACKEND_BASE_URL',
        defaultValue: 'https://flatground-map-backend.onrender.com',
      );
      return prodUrl.replaceAll(RegExp(r'/$'), '');
    }
    return 'http://10.0.2.2:8000';
  }

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  String resolvePhotoUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '$baseUrl$path';
  }

  Future<void> healthCheck() async {
    final response = await _client.get(_uri('/health'));
    if (response.statusCode != 200) {
      throw HttpException('Backend health check failed: ${response.statusCode}');
    }
  }

  Future<List<SkateSpot>> fetchSpots() async {
    final response = await _client.get(_uri('/spots'));
    if (response.statusCode != 200) {
      throw HttpException('Failed to load spots: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as List<dynamic>;
    return body
        .map((item) => SkateSpot.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SkateSpot> createSpot(SkateSpot spot) async {
    final response = await _client.post(
      _uri('/spots'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(spot.toCreateJson()),
    );
    if (response.statusCode != 201) {
      throw HttpException(
        'Failed to create spot (${response.statusCode}) at $baseUrl/spots: ${response.body}',
      );
    }

    return SkateSpot.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<SkateSpot> uploadPhotos({
    required String spotId,
    required List<File> files,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/spots/$spotId/photos'));
    for (final file in files) {
      request.files.add(await http.MultipartFile.fromPath('files', file.path));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to upload photos (${response.statusCode}) at $baseUrl/spots/$spotId/photos: ${response.body}',
      );
    }

    return SkateSpot.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<SkateSpot> deletePhoto({
    required String spotId,
    required String photoId,
  }) async {
    final response = await _client.delete(_uri('/spots/$spotId/photos/$photoId'));
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to delete photo (${response.statusCode}) at $baseUrl/spots/$spotId/photos/$photoId: ${response.body}',
      );
    }
    return SkateSpot.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteSpot(String spotId) async {
    final response = await _client.delete(_uri('/spots/$spotId'));
    if (response.statusCode != 204) {
      throw HttpException(
        'Failed to delete spot (${response.statusCode}) at $baseUrl/spots/$spotId: ${response.body}',
      );
    }
  }

  Future<SkateSpot> updateSpot({
    required String spotId,
    required String name,
    required String type,
    required String address,
    required double latitude,
    required double longitude,
    String? description,
    String difficulty = 'beginner',
  }) async {
    final response = await _client.patch(
      _uri('/spots/$spotId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'type': type,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'difficulty': difficulty,
      }),
    );
    if (response.statusCode != 200) {
      throw HttpException(
        'Failed to update spot (${response.statusCode}) at $baseUrl/spots/$spotId: ${response.body}',
      );
    }
    return SkateSpot.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void dispose() {
    _client.close();
  }
}
