import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MapPage(),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();
  final TextEditingController searchController = TextEditingController();

  LatLng currentLocation = const LatLng(23.8103, 90.4125); // Dhaka default
  LatLng? destination;
  List<List<LatLng>> allRoutes = [];
  StreamSubscription<Position>? positionStream;
  bool navigationStarted = false;
  int selectedRouteIndex = 0;
  
  // Navigation instructions
  List<NavigationStep> navigationSteps = [];
  RouteInfo? currentRouteInfo;
  
  List<Map<String, dynamic>> searchResults = [];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      startLiveTracking();
    } else {
      // For web, we'll use a default location since geolocator has limitations
      print("Running on web - using default location");
      _getWebLocation();
    }
  }
  
  // Get location on web
  Future<void> _getWebLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        mapController.move(currentLocation, 15);
      });
    } catch (e) {
      print("Web geolocation error: $e");
    }
  }

  @override
  void dispose() {
    positionStream?.cancel();
    super.dispose();
  }

  // LIVE LOCATION (works on mobile, limited on web)
  void startLiveTracking() async {
    if (kIsWeb) {
      await _getWebLocation();
      return;
    }
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied');
        return;
      }
    }

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
      currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );

      if (navigationStarted && destination != null) {
        await getRoutes();
      }

      setState(() {});
    });
  }

  // SEARCH PLACES NEAR CURRENT LOCATION
  Future<void> searchNearbyPlaces(String query) async {
    if (query.isEmpty) return;

    final url = 'https://nominatim.openstreetmap.org/search?' 
        'q=$query'
        '&format=json'
        '&limit=10'
        '&bounded=1'
        '&viewbox=${currentLocation.longitude - 0.1},${currentLocation.latitude - 0.1},${currentLocation.longitude + 0.1},${currentLocation.latitude + 0.1}'
        '&addressdetails=1';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "User-Agent": "Flutter Map App - Bangladesh",
          "Accept-Language": "bn,en"
        },
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        
        setState(() {
          searchResults = data.map((item) {
            return {
              'name': item['display_name'],
              'lat': double.parse(item['lat']),
              'lon': double.parse(item['lon']),
              'distance': calculateDistance(
                currentLocation.latitude,
                currentLocation.longitude,
                double.parse(item['lat']),
                double.parse(item['lon']),
              ),
            };
          }).toList();
          
          searchResults.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
        });
      }
    } catch (e) {
      print("Search Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Search failed: ${e.toString()}")),
      );
    }
  }

  // Calculate distance between two coordinates in kilometers
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
               math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
               math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degree) {
    return degree * math.pi / 180;
  }

  // SELECT DESTINATION FROM SEARCH RESULTS
  void selectDestination(LatLng location, String name) {
    setState(() {
      destination = location;
      searchResults.clear();
      searchController.clear();
      navigationStarted = false;
      allRoutes.clear();
      navigationSteps.clear();
      selectedRouteIndex = 0;
    });
    
    mapController.move(destination!, 15);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Selected: $name")),
    );
  }

  // GET ROUTES using OSRM (free, no API key needed for testing)
  Future<void> getRoutes() async {
    if (destination == null) return;

    try {
      // Using OSRM API (free, no CORS issues)
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${currentLocation.longitude},${currentLocation.latitude};'
          '${destination!.longitude},${destination!.latitude}'
          '?overview=full&geometries=geojson&steps=true&alternatives=true';
      
      print("Fetching route from: $url");
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          setState(() {
            allRoutes.clear();
            navigationSteps.clear();
            
            // Process each route alternative
            for (int i = 0; i < data['routes'].length && i < 3; i++) {
              final route = data['routes'][i];
              final geometry = route['geometry'];
              
              if (geometry != null && geometry['coordinates'] != null) {
                List<LatLng> routePoints = [];
                for (var coord in geometry['coordinates']) {
                  routePoints.add(LatLng(coord[1], coord[0]));
                }
                allRoutes.add(routePoints);
                
                // Get info for selected route
                if (i == selectedRouteIndex) {
                  // Route summary
                  double distance = route['distance'] / 1000; // km
                  double duration = route['duration'] / 60; // minutes
                  
                  currentRouteInfo = RouteInfo(
                    distance: distance,
                    duration: duration,
                    startAddress: "Your Location",
                    endAddress: "Destination",
                  );
                  
                  // Parse steps for turn-by-turn navigation
                  if (route['legs'] != null && route['legs'].isNotEmpty) {
                    for (var leg in route['legs']) {
                      if (leg['steps'] != null) {
                        for (var step in leg['steps']) {
                          String instruction = step['maneuver']['instruction'] ?? 
                                              _getSimpleInstruction(step['maneuver']['type'] ?? '');
                          double stepDistance = (step['distance'] ?? 0) / 1000;
                          double stepDuration = (step['duration'] ?? 0) / 60;
                          
                          navigationSteps.add(NavigationStep(
                            instruction: instruction,
                            distance: stepDistance,
                            duration: stepDuration,
                            type: step['maneuver']['type'] ?? 'straight',
                          ));
                        }
                      }
                    }
                  }
                }
              }
            }
            
            if (allRoutes.isEmpty) {
              throw Exception("No routes found");
            }
          });
        } else {
          throw Exception("No routes available");
        }
      } else {
        throw Exception("HTTP ${response.statusCode}");
      }
    } catch (e) {
      print("Route Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Route Error: ${e.toString()}")),
      );
    }
  }
  
  String _getSimpleInstruction(String type) {
    switch (type) {
      case 'turn':
        return 'Turn';
      case 'new name':
        return 'Continue';
      case 'depart':
        return 'Start';
      case 'arrive':
        return 'Arrive at destination';
      default:
        return 'Continue straight';
    }
  }

  // START NAVIGATION
  Future<void> startNavigation() async {
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a destination first")),
      );
      return;
    }
    
    setState(() {
      navigationStarted = true;
    });
    
    await getRoutes();
    
    // Fit map to show entire route
    if (allRoutes.isNotEmpty && selectedRouteIndex < allRoutes.length) {
      fitRouteToMap(allRoutes[selectedRouteIndex]);
    }
  }
  
  // Fit map to show the entire route
  void fitRouteToMap(List<LatLng> route) {
    if (route.isEmpty) return;
    
    double minLat = route.map((p) => p.latitude).reduce(math.min);
    double maxLat = route.map((p) => p.latitude).reduce(math.max);
    double minLng = route.map((p) => p.longitude).reduce(math.min);
    double maxLng = route.map((p) => p.longitude).reduce(math.max);
    
    // Create bounds
    final bounds = LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
    
    // Calculate appropriate zoom level based on bounds
    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double zoom = 12.0; // Default zoom
    
    if (latDiff > 0 || lngDiff > 0) {
      // Rough calculation for zoom level
      double maxDiff = math.max(latDiff, lngDiff);
      if (maxDiff < 0.01) zoom = 16;
      else if (maxDiff < 0.02) zoom = 15;
      else if (maxDiff < 0.05) zoom = 14;
      else if (maxDiff < 0.1) zoom = 13;
      else if (maxDiff < 0.2) zoom = 12;
      else if (maxDiff < 0.5) zoom = 11;
      else if (maxDiff < 1.0) zoom = 10;
      else zoom = 9;
      
      // Calculate center of bounds
      LatLng center = LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );
      
      mapController.move(center, zoom);
    }
  }

  // GO TO CURRENT LOCATION
  void goToMyLocation() {
    mapController.move(currentLocation, 16);
  }
  
  // Change selected route
  void changeRoute(int index) {
    setState(() {
      selectedRouteIndex = index;
    });
    getRoutes();
  }
  
  // Stop navigation
  void stopNavigation() {
    setState(() {
      navigationStarted = false;
      allRoutes.clear();
      navigationSteps.clear();
      currentRouteInfo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // MAP
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentLocation,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              
              // MULTIPLE ROUTES
              if (allRoutes.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    for (int i = 0; i < allRoutes.length; i++)
                      Polyline(
                        points: allRoutes[i],
                        strokeWidth: i == selectedRouteIndex ? 6 : 3,
                        color: i == selectedRouteIndex ? Colors.blue : Colors.grey,
                      ),
                  ],
                ),
              
              // MARKERS
              MarkerLayer(
                markers: [
                  Marker(
                    point: currentLocation,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.navigation,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),
                  if (destination != null)
                    Marker(
                      point: destination!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 45,
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          // SEARCH BAR (only when not navigating)
          if (!navigationStarted)
            Positioned(
              top: 50,
              left: 15,
              right: 15,
              child: Material(
                elevation: 5,
                borderRadius: BorderRadius.circular(12),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Search near me (restaurants, hospitals, etc.)",
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        await searchNearbyPlaces(searchController.text);
                      },
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(15),
                  ),
                  onSubmitted: (value) async {
                    await searchNearbyPlaces(value);
                  },
                ),
              ),
            ),
          
          // SEARCH RESULTS LIST
          if (searchResults.isNotEmpty && !navigationStarted)
            Positioned(
              top: 120,
              left: 15,
              right: 15,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: Card(
                  elevation: 8,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final result = searchResults[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on),
                        title: Text(
                          result['name'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          "${(result['distance'] as double).toStringAsFixed(2)} km away",
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: () {
                          selectDestination(
                            LatLng(result['lat'], result['lon']),
                            result['name'],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          
          // DESTINATION CARD (before navigation starts)
          if (destination != null && !navigationStarted && searchResults.isEmpty)
            Positioned(
              bottom: 20,
              left: 15,
              right: 15,
              child: Card(
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_pin, color: Colors.red, size: 30),
                      const SizedBox(height: 5),
                      Text(
                        "Destination Selected",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Lat: ${destination!.latitude.toStringAsFixed(4)}, Lng: ${destination!.longitude.toStringAsFixed(4)}",
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: startNavigation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Start Navigation"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // NAVIGATION PANEL (when navigation is active)
          if (navigationStarted && currentRouteInfo != null)
            Positioned(
              bottom: 20,
              left: 15,
              right: 15,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Route summary header
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Navigation",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  onPressed: stopNavigation,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    const Icon(Icons.route, color: Colors.white),
                                    const SizedBox(height: 5),
                                    Text(
                                      "${currentRouteInfo!.distance.toStringAsFixed(1)} km",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Icon(Icons.access_time, color: Colors.white),
                                    const SizedBox(height: 5),
                                    Text(
                                      "${currentRouteInfo!.duration.toStringAsFixed(0)} min",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  children: [
                                    const Icon(Icons.directions_car, color: Colors.white),
                                    const SizedBox(height: 5),
                                    const Text(
                                      "Driving",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Route options (if multiple routes available)
                      if (allRoutes.length > 1)
                        Container(
                          padding: const EdgeInsets.all(10),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (int i = 0; i < allRoutes.length; i++)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 5),
                                    child: FilterChip(
                                      label: Text("Route ${i + 1}"),
                                      selected: selectedRouteIndex == i,
                                      onSelected: (selected) {
                                        if (selected) changeRoute(i);
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Turn-by-turn instructions
                      if (navigationSteps.isNotEmpty)
                        Container(
                          height: 300,
                          child: ListView.builder(
                            itemCount: navigationSteps.length,
                            itemBuilder: (context, index) {
                              final step = navigationSteps[index];
                              return ListTile(
                                leading: _getInstructionIcon(step.type),
                                title: Text(
                                  step.instruction,
                                  style: const TextStyle(fontSize: 14),
                                ),
                                subtitle: Text(
                                  "${step.distance.toStringAsFixed(1)} km • ${step.duration.toStringAsFixed(0)} min",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: index == 0 
                                    ? const Chip(
                                        label: Text("Next"),
                                        backgroundColor: Colors.green,
                                        labelStyle: TextStyle(color: Colors.white),
                                      )
                                    : null,
                              );
                            },
                          ),
                        ),
                      
                      // Current location button
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: ElevatedButton.icon(
                          onPressed: goToMyLocation,
                          icon: const Icon(Icons.my_location),
                          label: const Text("Center on my location"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // MY LOCATION BUTTON (when not navigating)
          if (!navigationStarted)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton(
                onPressed: goToMyLocation,
                child: const Icon(Icons.my_location),
              ),
            ),
          
          // CLEAR SEARCH BUTTON
          if (searchResults.isNotEmpty)
            Positioned(
              top: 120,
              right: 30,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      searchResults.clear();
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  // Get icon based on instruction type
  Icon _getInstructionIcon(String type) {
    switch (type) {
      case 'turn':
        return const Icon(Icons.turn_right, color: Colors.blue);
      case 'new name':
        return const Icon(Icons.straight, color: Colors.blue);
      case 'depart':
        return const Icon(Icons.directions_car, color: Colors.green);
      case 'arrive':
        return const Icon(Icons.location_on, color: Colors.green);
      default:
        return const Icon(Icons.directions, color: Colors.blue);
    }
  }
}

// Model classes for navigation data
class RouteInfo {
  final double distance;
  final double duration;
  final String startAddress;
  final String endAddress;
  
  RouteInfo({
    required this.distance,
    required this.duration,
    required this.startAddress,
    required this.endAddress,
  });
}

class NavigationStep {
  final String instruction;
  final double distance;
  final double duration;
  final String type;
  
  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.type,
  });
}