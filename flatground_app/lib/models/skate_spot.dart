class SkateSpot {
  final String id;
  final String name;
  final String type;
  final String address;
  final double latitude;
  final double longitude;
  final String? description;
  final String difficulty;
  final List<String> photoUrls;
  final List<SpotPhotoRef> photos;
  final DateTime? createdAt;

  const SkateSpot({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.description,
    this.difficulty = 'beginner',
    this.photoUrls = const [],
    this.photos = const [],
    this.createdAt,
  });

  static const Set<String> _allowedDifficulties = {
    'beginner',
    'intermediate',
    'advanced',
  };

  static String _stringOrDefault(dynamic value, String fallback) {
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return fallback;
  }

  static String _normalizedDifficulty(dynamic value) {
    final raw = (value is String ? value : '').toLowerCase().trim();
    if (_allowedDifficulties.contains(raw)) {
      return raw;
    }
    return 'beginner';
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'type': type,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'difficulty': difficulty,
    };
  }

  factory SkateSpot.fromJson(Map<String, dynamic> json) {
    return SkateSpot(
      id: json['id'].toString(),
      name: _stringOrDefault(json['name'], ''),
      type: _stringOrDefault(json['type'], ''),
      address: _stringOrDefault(json['address'], ''),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      description: json['description'] is String ? json['description'] as String : null,
      difficulty: _normalizedDifficulty(json['difficulty']),
      photoUrls: (json['photo_urls'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .toList(),
      photos: (json['photos'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(SpotPhotoRef.fromJson)
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}

class SpotPhotoRef {
  final String id;
  final String fileName;
  final String url;

  const SpotPhotoRef({
    required this.id,
    required this.fileName,
    required this.url,
  });

  factory SpotPhotoRef.fromJson(Map<String, dynamic> json) {
    return SpotPhotoRef(
      id: json['id'].toString(),
      fileName: (json['file_name'] as String?) ?? '',
      url: (json['url'] as String?) ?? '',
    );
  }
}
