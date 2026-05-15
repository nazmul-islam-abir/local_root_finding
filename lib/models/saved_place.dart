class SavedPlace {
  final String name;
  final double lat;
  final double lon;
  final String address;
  final String type;
  
  SavedPlace({
    required this.name,
    required this.lat,
    required this.lon,
    this.address = '',
    this.type = 'Saved',
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': lat,
    'lon': lon,
    'address': address,
    'type': type,
  };
  
  factory SavedPlace.fromJson(Map<String, dynamic> json) {
    return SavedPlace(
      name: json['name'],
      lat: json['lat'],
      lon: json['lon'],
      address: json['address'] ?? '',
      type: json['type'] ?? 'Saved',
    );
  }
}