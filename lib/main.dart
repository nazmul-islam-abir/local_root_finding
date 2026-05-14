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

  LatLng currentLocation = const LatLng(23.8103, 90.4125);
  LatLng? destination;
  List<List<LatLng>> allRoutes = [];
  StreamSubscription<Position>? positionStream;
  bool navigationStarted = false;
  int selectedRouteIndex = 0;
  
  List<NavigationStep> navigationSteps = [];
  RouteInfo? currentRouteInfo;
  
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> allBangladeshAirports = [];
  
  String currentMapLayer = 'standard';
  Timer? _debounceTimer;
  List<Map<String, dynamic>> suggestions = [];
  
  bool isSearching = false;
  bool showRouteSheet = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      startLiveTracking();
    } else {
      _getWebLocation();
    }
    loadBangladeshAirports();
  }
  
  Future<void> loadBangladeshAirports() async {
    allBangladeshAirports = [
      {'name': 'Hazrat Shahjalal International Airport', 'lat': 23.8433, 'lon': 90.3978, 'city': 'Dhaka', 'type': 'International', 'code': 'DAC'},
      {'name': 'Shah Amanat International Airport', 'lat': 22.2496, 'lon': 91.8133, 'city': 'Chattogram', 'type': 'International', 'code': 'CGP'},
      {'name': 'Osmani International Airport', 'lat': 24.9631, 'lon': 91.8669, 'city': 'Sylhet', 'type': 'International', 'code': 'ZYL'},
      {'name': 'Jessore Airport', 'lat': 23.1838, 'lon': 89.1608, 'city': 'Jessore', 'type': 'Domestic', 'code': 'JSR'},
      {'name': 'Cox\'s Bazar Airport', 'lat': 21.4522, 'lon': 91.9639, 'city': 'Cox\'s Bazar', 'type': 'Domestic', 'code': 'CXB'},
      {'name': 'Barisal Airport', 'lat': 22.8010, 'lon': 90.3012, 'city': 'Barisal', 'type': 'Domestic', 'code': 'BZL'},
      {'name': 'Rajshahi Airport', 'lat': 24.4372, 'lon': 88.6165, 'city': 'Rajshahi', 'type': 'Domestic', 'code': 'RJH'},
      {'name': 'Saidpur Airport', 'lat': 25.7592, 'lon': 88.9089, 'city': 'Saidpur', 'type': 'Domestic', 'code': 'SPD'},
    ];
  }
  
  // Smart search with fuzzy matching
  void onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (query.isNotEmpty) {
        getSmartSuggestions(query);
      } else {
        setState(() {
          suggestions.clear();
          searchResults.clear();
          isSearching = false;
        });
      }
    });
  }
  
  // Fuzzy search for misspellings
  Future<void> getSmartSuggestions(String query) async {
    setState(() => isSearching = true);
    
    List<Map<String, dynamic>> localSuggestions = [];
    String lowerQuery = query.toLowerCase();
    
    // Fuzzy matching for local airports
    for (var airport in allBangladeshAirports) {
      double similarity = calculateSimilarity(
        lowerQuery,
        '${airport['name']} ${airport['city']} ${airport['code']}'.toLowerCase()
      );
      
      if (similarity > 0.3 || airport['name'].toLowerCase().contains(lowerQuery) ||
          airport['city'].toLowerCase().contains(lowerQuery) ||
          airport['code'].toLowerCase().contains(lowerQuery)) {
        
        double distance = calculateDistance(
          currentLocation.latitude,
          currentLocation.longitude,
          airport['lat'],
          airport['lon'],
        );
        
        localSuggestions.add({
          'name': airport['name'],
          'lat': airport['lat'],
          'lon': airport['lon'],
          'distance': distance,
          'city': airport['city'],
          'type': airport['type'],
          'code': airport['code'],
          'source': 'local',
          'similarity': similarity,
        });
      }
    }
    
    // Online search for other places
    final url = 'https://nominatim.openstreetmap.org/search?'
        'q=$query+Bangladesh'
        '&format=json'
        '&limit=5'
        '&addressdetails=1';
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {"User-Agent": "Flutter Map App", "Accept-Language": "bn,en"},
      );
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        List<Map<String, dynamic>> onlineSuggestions = [];
        
        for (var item in data) {
          double distance = calculateDistance(
            currentLocation.latitude,
            currentLocation.longitude,
            double.parse(item['lat']),
            double.parse(item['lon']),
          );
          onlineSuggestions.add({
            'name': item['display_name'],
            'lat': double.parse(item['lat']),
            'lon': double.parse(item['lon']),
            'distance': distance,
            'source': 'online',
            'similarity': 1.0,
          });
        }
        
        setState(() {
          suggestions = [...localSuggestions, ...onlineSuggestions];
          suggestions.sort((a, b) {
            // Sort by similarity first, then by distance
            if (a['similarity'] != b['similarity']) {
              return (b['similarity'] as double).compareTo(a['similarity'] as double);
            }
            return (a['distance'] as double).compareTo(b['distance'] as double);
          });
          isSearching = false;
        });
      } else {
        setState(() {
          suggestions = localSuggestions;
          isSearching = false;
        });
      }
    } catch (e) {
      print("Suggestion error: $e");
      setState(() {
        suggestions = localSuggestions;
        isSearching = false;
      });
    }
  }
  
  // Calculate string similarity (Levenshtein distance based)
  double calculateSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;
    
    int longer = a.length > b.length ? a.length : b.length;
    if (longer == 0) return 1.0;
    
    int distance = levenshteinDistance(a, b);
    return 1.0 - (distance / longer);
  }
  
  int levenshteinDistance(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    
    List<List<int>> matrix = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
    
    for (int i = 0; i <= a.length; i++) matrix[i][0] = i;
    for (int j = 0; j <= b.length; j++) matrix[0][j] = j;
    
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        int cost = a[i - 1] == b[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(math.min);
      }
    }
    return matrix[a.length][b.length];
  }

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
    _debounceTimer?.cancel();
    super.dispose();
  }

  void startLiveTracking() async {
    if (kIsWeb) {
      await _getWebLocation();
      return;
    }
    
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) async {
      currentLocation = LatLng(position.latitude, position.longitude);
      if (navigationStarted && destination != null) {
        await getRoutes();
      }
      setState(() {});
    });
  }

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
        headers: {"User-Agent": "Flutter Map App", "Accept-Language": "bn,en"},
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
          suggestions.clear();
        });
      }
    } catch (e) {
      print("Search Error: $e");
    }
  }

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

  void selectDestination(LatLng location, String name) {
    setState(() {
      destination = location;
      suggestions.clear();
      searchResults.clear();
      searchController.clear();
      navigationStarted = false;
      allRoutes.clear();
      navigationSteps.clear();
      selectedRouteIndex = 0;
      showRouteSheet = false;
    });
    
    mapController.move(destination!, 14);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✓ $name selected", style: const TextStyle(color: Colors.white)), 
        backgroundColor: Colors.green, duration: const Duration(seconds: 1)),
    );
  }
  
  void clearDestination() {
    setState(() {
      destination = null;
      navigationStarted = false;
      allRoutes.clear();
      navigationSteps.clear();
      currentRouteInfo = null;
      showRouteSheet = false;
    });
  }

  Future<void> getRoutes() async {
    if (destination == null) return;

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${currentLocation.longitude},${currentLocation.latitude};'
          '${destination!.longitude},${destination!.latitude}'
          '?overview=full&geometries=geojson&steps=true&alternatives=true';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          setState(() {
            allRoutes.clear();
            navigationSteps.clear();
            
            for (int i = 0; i < data['routes'].length && i < 3; i++) {
              final route = data['routes'][i];
              final geometry = route['geometry'];
              
              if (geometry != null && geometry['coordinates'] != null) {
                List<LatLng> routePoints = [];
                for (var coord in geometry['coordinates']) {
                  routePoints.add(LatLng(coord[1], coord[0]));
                }
                allRoutes.add(routePoints);
                
                if (i == selectedRouteIndex) {
                  double distance = route['distance'] / 1000;
                  double duration = route['duration'] / 60;
                  
                  currentRouteInfo = RouteInfo(
                    distance: distance,
                    duration: duration,
                    startAddress: "Your Location",
                    endAddress: "Destination",
                  );
                  
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
          });
          
          // Show route selection sheet automatically
          if (allRoutes.length > 1) {
            showRouteSelectionSheet();
          } else {
            startNavigationAfterRouteSelect();
          }
        }
      }
    } catch (e) {
      print("Route Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Route Error: ${e.toString()}")),
      );
    }
  }
  
  void showRouteSelectionSheet() {
    setState(() => showRouteSheet = true);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => RouteSelectionSheet(
        routes: allRoutes,
        currentRouteInfo: currentRouteInfo,
        navigationSteps: navigationSteps,
        selectedIndex: selectedRouteIndex,
        onRouteSelected: (index) {
          setState(() {
            selectedRouteIndex = index;
          });
          getRoutes();
        },
        onStartNavigation: () {
          Navigator.pop(context);
          startNavigationAfterRouteSelect();
        },
      ),
    ).then((_) {
      setState(() => showRouteSheet = false);
    });
  }
  
  void startNavigationAfterRouteSelect() {
    setState(() {
      navigationStarted = true;
      showRouteSheet = false;
    });
    
    if (allRoutes.isNotEmpty && selectedRouteIndex < allRoutes.length) {
      fitRouteToMap(allRoutes[selectedRouteIndex]);
    }
  }
  
  String _getSimpleInstruction(String type) {
    switch (type) {
      case 'turn': return 'Turn';
      case 'new name': return 'Continue';
      case 'depart': return 'Start';
      case 'arrive': return 'Arrive at destination';
      default: return 'Continue straight';
    }
  }

  Future<void> startNavigation() async {
    if (destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a destination first")),
      );
      return;
    }
    
    await getRoutes();
  }
  
  void fitRouteToMap(List<LatLng> route) {
    if (route.isEmpty) return;
    
    double minLat = route.map((p) => p.latitude).reduce(math.min);
    double maxLat = route.map((p) => p.latitude).reduce(math.max);
    double minLng = route.map((p) => p.longitude).reduce(math.min);
    double maxLng = route.map((p) => p.longitude).reduce(math.max);
    
    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double zoom = 12.0;
    
    if (latDiff > 0 || lngDiff > 0) {
      double maxDiff = math.max(latDiff, lngDiff);
      if (maxDiff < 0.01) zoom = 16;
      else if (maxDiff < 0.02) zoom = 15;
      else if (maxDiff < 0.05) zoom = 14;
      else if (maxDiff < 0.1) zoom = 13;
      else if (maxDiff < 0.2) zoom = 12;
      else if (maxDiff < 0.5) zoom = 11;
      else if (maxDiff < 1.0) zoom = 10;
      else zoom = 9;
      
      LatLng center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
      mapController.move(center, zoom);
    }
  }

  void goToMyLocation() {
    mapController.move(currentLocation, 16);
  }
  
  void changeRoute(int index) {
    setState(() {
      selectedRouteIndex = index;
    });
    getRoutes();
  }
  
  void stopNavigation() {
    setState(() {
      navigationStarted = false;
      allRoutes.clear();
      navigationSteps.clear();
      currentRouteInfo = null;
      showRouteSheet = false;
    });
  }
  
  void changeMapLayer(String layer) {
    setState(() {
      currentMapLayer = layer;
    });
  }
  
  String getTileLayerUrl() {
    switch (currentMapLayer) {
      case 'satellite':
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case 'dark':
        return 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/dark_all/{z}/{x}/{y}.png';
      case 'outdoor':
        return 'https://tile.openstreetmap.de/{z}/{x}/{y}.png';
      default:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
    }
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
                urlTemplate: getTileLayerUrl(),
                userAgentPackageName: 'com.example.app',
              ),
              
              if (allRoutes.isNotEmpty && navigationStarted)
                PolylineLayer(
                  polylines: [
                    for (int i = 0; i < allRoutes.length; i++)
                      Polyline(
                        points: allRoutes[i],
                        strokeWidth: i == selectedRouteIndex ? 6 : 3,
                        color: i == selectedRouteIndex ? Colors.blue : Colors.grey.withOpacity(0.5),
                      ),
                  ],
                ),
              
              MarkerLayer(
                markers: [
                  Marker(
                    point: currentLocation,
                    width: 80,
                    height: 80,
                    child: const Icon(Icons.navigation, color: Colors.blue, size: 40),
                  ),
                  if (destination != null)
                    Marker(
                      point: destination!,
                      width: 80,
                      height: 80,
                      child: const Icon(Icons.location_pin, color: Colors.red, size: 45),
                    ),
                ],
              ),
            ],
          ),
          
          // TOP BAR WITH LAYER BUTTON (Google Maps style)
          Positioned(
            top: 50,
            left: 15,
            right: 15,
            child: Row(
              children: [
                // Search Bar
                Expanded(
                  child: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(30),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: "Search places, airports...",
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 20),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() {
                                    suggestions.clear();
                                    searchResults.clear();
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: onSearchChanged,
                      onSubmitted: (value) async {
                        await searchNearbyPlaces(value);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Layer Button (Top Right)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      currentMapLayer == 'satellite' ? Icons.satellite :
                      currentMapLayer == 'dark' ? Icons.nightlight_round :
                      currentMapLayer == 'outdoor' ? Icons.landscape :
                      Icons.map,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      showLayerMenu(context);
                    },
                    tooltip: 'Map layers',
                  ),
                ),
              ],
            ),
          ),
          
          // Suggestions Dropdown
          if (suggestions.isNotEmpty && !navigationStarted)
            Positioned(
              top: 110,
              left: 15,
              right: 75,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isSearching
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final result = suggestions[index];
                            return ListTile(
                              leading: result['source'] == 'local'
                                  ? const Icon(Icons.local_airport, color: Colors.blue)
                                  : const Icon(Icons.location_on, color: Colors.grey),
                              title: Text(
                                result['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (result['city'] != null)
                                    Text(
                                      '${result['city']} • ${result['type'] ?? ''}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  Text(
                                    "${(result['distance'] as double).toStringAsFixed(1)} km away",
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward, size: 18),
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
          
          // Active Navigation Bar (Top)
          if (navigationStarted && currentRouteInfo != null)
            Positioned(
              top: 15,
              left: 15,
              right: 15,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.navigation, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Navigation",
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "${currentRouteInfo!.distance.toStringAsFixed(1)} km • ${currentRouteInfo!.duration.toStringAsFixed(0)} min",
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.my_location, size: 20),
                                onPressed: goToMyLocation,
                                tooltip: 'Center',
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                onPressed: stopNavigation,
                                tooltip: 'Exit',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (navigationSteps.isNotEmpty)
                      Container(
                        height: 80,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: navigationSteps.length > 5 ? 5 : navigationSteps.length,
                          itemBuilder: (context, index) {
                            final step = navigationSteps[index];
                            return Container(
                              width: 200,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  _getInstructionIcon(step.type),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          step.instruction,
                                          style: const TextStyle(fontSize: 11),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          "${step.distance.toStringAsFixed(1)} km • ${step.duration.toStringAsFixed(0)} min",
                                          style: const TextStyle(fontSize: 9, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          // My Location Button (Bottom Right)
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              mini: true,
              onPressed: goToMyLocation,
              child: const Icon(Icons.my_location, size: 20),
            ),
          ),
        ],
      ),
    );
  }
  
  void showLayerMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Map Style',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            _buildLayerOption('Default', 'standard', Icons.map),
            _buildLayerOption('Satellite', 'satellite', Icons.satellite),
            _buildLayerOption('Dark Mode', 'dark', Icons.nightlight_round),
            _buildLayerOption('Outdoor', 'outdoor', Icons.landscape),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLayerOption(String name, String layerId, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: currentMapLayer == layerId ? Colors.blue : Colors.grey),
      title: Text(name),
      trailing: currentMapLayer == layerId ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () {
        changeMapLayer(layerId);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$name view"), duration: const Duration(seconds: 1)),
        );
      },
    );
  }
  
  Widget _getInstructionIcon(String type) {
    switch (type) {
      case 'turn': return const Icon(Icons.turn_right, color: Colors.blue, size: 18);
      case 'depart': return const Icon(Icons.play_arrow, color: Colors.green, size: 18);
      case 'arrive': return const Icon(Icons.flag, color: Colors.red, size: 18);
      default: return const Icon(Icons.directions, color: Colors.blue, size: 18);
    }
  }
}

// Route Selection Bottom Sheet
class RouteSelectionSheet extends StatelessWidget {
  final List<List<LatLng>> routes;
  final RouteInfo? currentRouteInfo;
  final List<NavigationStep> navigationSteps;
  final int selectedIndex;
  final Function(int) onRouteSelected;
  final VoidCallback onStartNavigation;

  const RouteSelectionSheet({
    super.key,
    required this.routes,
    required this.currentRouteInfo,
    required this.navigationSteps,
    required this.selectedIndex,
    required this.onRouteSelected,
    required this.onStartNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
            // Header
            const Text(
              "Choose a route",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 5),
            if (currentRouteInfo != null)
              Text(
                "${currentRouteInfo!.distance.toStringAsFixed(1)} km • ${currentRouteInfo!.duration.toStringAsFixed(0)} min",
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            const Divider(height: 20),
            // Route options
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: routes.length,
                itemBuilder: (context, index) {
                  bool isSelected = selectedIndex == index;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    elevation: isSelected ? 4 : 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: isSelected ? BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(color: isSelected ? Colors.white : Colors.black),
                        ),
                      ),
                      title: Text(
                        "Route ${index + 1}",
                        style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      ),
                      subtitle: Text("Distance and time optimized"),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: Colors.blue)
                          : OutlinedButton(
                              onPressed: () => onRouteSelected(index),
                              child: const Text("Select"),
                            ),
                    ),
                  );
                },
              ),
            ),
            // Navigation steps preview
            if (navigationSteps.isNotEmpty)
              Container(
                height: 120,
                margin: const EdgeInsets.symmetric(horizontal: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Route preview",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: navigationSteps.length > 3 ? 3 : navigationSteps.length,
                        itemBuilder: (context, i) {
                          final step = navigationSteps[i];
                          return Container(
                            width: 150,
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(step.type == 'turn' ? Icons.turn_right : Icons.directions, size: 16),
                                const SizedBox(height: 4),
                                Text(
                                  step.instruction,
                                  style: const TextStyle(fontSize: 10),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "${step.distance.toStringAsFixed(1)} km • ${step.duration.toStringAsFixed(0)} min",
                                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            // Start button
            Padding(
              padding: const EdgeInsets.all(15),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onStartNavigation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Start Navigation",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

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