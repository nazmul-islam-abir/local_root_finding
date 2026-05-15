class PlaceDetails {
  final String name;
  final String fullAddress;
  final double lat;
  final double lon;
  final String type;
  final String? phone;
  final String? website;
  final double? rating;
  final String? openingHours;
  
  PlaceDetails({
    required this.name,
    required this.fullAddress,
    required this.lat,
    required this.lon,
    required this.type,
    this.phone,
    this.website,
    this.rating,
    this.openingHours,
  });
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'fullAddress': fullAddress,
    'lat': lat,
    'lon': lon,
    'type': type,
    'phone': phone,
    'website': website,
    'rating': rating,
    'openingHours': openingHours,
  };
  
  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    return PlaceDetails(
      name: json['name'],
      fullAddress: json['fullAddress'],
      lat: json['lat'],
      lon: json['lon'],
      type: json['type'],
      phone: json['phone'],
      website: json['website'],
      rating: json['rating'],
      openingHours: json['openingHours'],
    );
  }
}