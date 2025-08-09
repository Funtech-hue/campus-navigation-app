class Location {
  final String id;
  final String locationName;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String category;

  Location({
    required this.id,
    required this.locationName,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.category,
  });

  factory Location.fromMap(Map<String, dynamic> map, String id) {
    return Location(
      id: id,
      locationName: map['locationName'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      category: map['category'] ?? 'Other',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'locationName': locationName,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
    };
  }
}