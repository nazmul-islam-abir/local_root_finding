import 'package:latlong2/latlong.dart';

class PlaceLocation {
  final String name;
  final String address;
  final LatLng coordinates;
  final String? type;
  
  PlaceLocation({
    required this.name,
    required this.address,
    required this.coordinates,
    this.type,
  });
}