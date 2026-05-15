import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  static Future<Map<String, dynamic>?> fetchRoutes(LatLng start, LatLng end) async {
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${end.longitude},${end.latitude}'
          '?overview=full&geometries=geojson&steps=true&alternatives=true';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          return data;
        }
      }
      return null;
    } catch (e) {
      print("Route Error: $e");
      return null;
    }
  }

  static List<LatLng> decodePolyline(List coordinates) {
    List<LatLng> points = [];
    for (var coord in coordinates) {
      points.add(LatLng(coord[1], coord[0]));
    }
    return points;
  }
}