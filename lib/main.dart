import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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
  List<RouteData> allRoutes = [];
  StreamSubscription<Position>? positionStream;
  bool navigationStarted = false;
  int selectedRouteIndex = 0;
  int currentTabIndex = 0;
  
  List<NavigationStep> navigationSteps = [];
  RouteInfo? currentRouteInfo;
  
  List<Map<String, dynamic>> searchResults = [];
  List<Map<String, dynamic>> allBangladeshAirports = [];
  List<SavedPlace> savedPlaces = [];
  
  String currentMapLayer = 'standard';
  Timer? _debounceTimer;
  List<Map<String, dynamic>> suggestions = [];
  
  bool isSearching = false;
  bool isLoadingRoutes = false;
  double currentZoom = 13;
  
  bool isFetchingRoutes = false;
  DateTime? lastRouteRequest;
  
  String? destinationName;
  String? destinationAddress;
  bool showRouteSelectionPanel = false;

  // Map rotation only (no 3D tilt)
  double currentRotation = 0.0;
  bool showCompass = false;
  double compassHeading = 0.0;

  @override
  void initState() {
    super.initState();
    
    if (!kIsWeb) {
      startLiveTracking();
    } else {
      _getWebLocation();
    }
    loadBangladeshAirports();
    loadSavedPlaces();
  }
  
  Future<void> loadSavedPlaces() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/saved_places.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        
        setState(() {
          savedPlaces = jsonList.map((json) => SavedPlace.fromJson(json)).toList();
        });
      } else {
        setState(() {
          savedPlaces = [
            SavedPlace(name: 'National Parliament House', lat: 23.7625, lon: 90.3883, type: 'Landmark', address: 'Sher-e-Bangla Nagar, Dhaka'),
            SavedPlace(name: 'Cox\'s Bazar Sea Beach', lat: 21.4272, lon: 91.9822, type: 'Beach', address: 'Cox\'s Bazar, Bangladesh'),
            SavedPlace(name: 'Sundarbans', lat: 21.9497, lon: 89.1833, type: 'Forest', address: 'Khulna Division'),
            SavedPlace(name: 'Lalbagh Fort', lat: 23.7184, lon: 90.3878, type: 'Historical', address: 'Old Dhaka'),
            SavedPlace(name: 'Ahsan Manzil', lat: 23.7089, lon: 90.4061, type: 'Museum', address: 'Old Dhaka'),
          ];
        });
        await savePlacesToStorage();
      }
    } catch (e) {
      print("Error loading saved places: $e");
    }
  }
  
  Future<void> savePlacesToStorage() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/saved_places.json');
      final jsonList = savedPlaces.map((place) => place.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print("Error saving places: $e");
    }
  }
  
  Future<void> addSavedPlace(SavedPlace place) async {
    setState(() {
      savedPlaces.add(place);
    });
    await savePlacesToStorage();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ "${place.name}" saved to your places'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  Future<void> removeSavedPlace(int index) async {
    final place = savedPlaces[index];
    setState(() {
      savedPlaces.removeAt(index);
    });
    await savePlacesToStorage();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed "${place.name}" from saved places'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  void showSaveLocationDialog(LatLng location, String name, {String? address}) {
    final TextEditingController nameController = TextEditingController(text: name);
    final TextEditingController typeController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Place Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: typeController,
              decoration: const InputDecoration(
                labelText: 'Type (e.g., Restaurant, Park, Home)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Location:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Lat: ${location.latitude.toStringAsFixed(6)}'),
                  Text('Lng: ${location.longitude.toStringAsFixed(6)}'),
                  if (address != null) 
                    Text('Address: ${address.length > 50 ? address.substring(0, 50) + '...' : address}'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final newPlace = SavedPlace(
                name: nameController.text.trim(),
                lat: location.latitude,
                lon: location.longitude,
                address: address ?? '',
                type: typeController.text.trim().isEmpty ? 'Saved' : typeController.text.trim(),
              );
              addSavedPlace(newPlace);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.save),
            label: const Text('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  void showLocationOptions(LatLng location, String name, {String? address}) {
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
            Text(
              name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (address != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  address,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      selectDestination(location, name, address: address);
                    },
                    icon: const Icon(Icons.directions),
                    label: const Text('Navigate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showSaveLocationDialog(location, name, address: address);
                    },
                    icon: const Icon(Icons.bookmark_add),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                mapController.move(location, 15);
              },
              icon: const Icon(Icons.visibility),
              label: const Text('View on Map'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> loadBangladeshAirports() async {
    allBangladeshAirports = [
      {'name': 'Hazrat Shahjalal International Airport', 'lat': 23.8433, 'lon': 90.3978, 'city': 'Dhaka', 'type': 'International', 'code': 'DAC', 'address': 'Kurmitola, Dhaka'},
      {'name': 'Shah Amanat International Airport', 'lat': 22.2496, 'lon': 91.8133, 'city': 'Chattogram', 'type': 'International', 'code': 'CGP', 'address': 'Patenga, Chattogram'},
      {'name': 'Osmani International Airport', 'lat': 24.9631, 'lon': 91.8669, 'city': 'Sylhet', 'type': 'International', 'code': 'ZYL', 'address': 'Sylhet'},
      {'name': 'Jessore Airport', 'lat': 23.1838, 'lon': 89.1608, 'city': 'Jessore', 'type': 'Domestic', 'code': 'JSR', 'address': 'Jessore'},
      {'name': "Cox's Bazar Airport", 'lat': 21.4522, 'lon': 91.9639, 'city': "Cox's Bazar", 'type': 'Domestic', 'code': 'CXB', 'address': "Cox's Bazar"},
    ];
  }
  
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
  
  Future<void> getSmartSuggestions(String query) async {
    setState(() => isSearching = true);
    
    List<Map<String, dynamic>> localSuggestions = [];
    String lowerQuery = query.toLowerCase();
    
    for (var place in savedPlaces) {
      if (place.name.toLowerCase().contains(lowerQuery) ||
          place.type.toLowerCase().contains(lowerQuery)) {
        double distance = calculateDistance(
          currentLocation.latitude,
          currentLocation.longitude,
          place.lat,
          place.lon,
        );
        
        localSuggestions.add({
          'name': place.name,
          'lat': place.lat,
          'lon': place.lon,
          'distance': distance,
          'address': place.address,
          'type': place.type,
          'source': 'saved',
        });
      }
    }
    
    for (var airport in allBangladeshAirports) {
      if (airport['name'].toLowerCase().contains(lowerQuery) ||
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
          'address': airport['address'],
          'type': airport['type'],
          'source': 'local',
        });
      }
    }
    
    final url = 'https://nominatim.openstreetmap.org/search?'
        'q=$query+Bangladesh'
        '&format=json'
        '&limit=8'
        '&addressdetails=1';
    
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {"User-Agent": "Flutter Map App", "Accept-Language": "bn,en"},
      );
      
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        
        for (var item in data) {
          double distance = calculateDistance(
            currentLocation.latitude,
            currentLocation.longitude,
            double.parse(item['lat']),
            double.parse(item['lon']),
          );
          
          String address = item['display_name'] ?? '';
          String shortName = item['name'] ?? '';
          String type = item['type'] ?? 'place';
          
          localSuggestions.add({
            'name': shortName.length > 50 ? shortName.substring(0, 50) + '...' : shortName,
            'lat': double.parse(item['lat']),
            'lon': double.parse(item['lon']),
            'distance': distance,
            'address': address.length > 80 ? address.substring(0, 80) + '...' : address,
            'type': type,
            'source': 'online',
          });
        }
        
        setState(() {
          suggestions = localSuggestions;
          suggestions.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
          isSearching = false;
        });
      } else {
        setState(() {
          suggestions = localSuggestions;
          isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        suggestions = localSuggestions;
        isSearching = false;
      });
    }
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
        distanceFilter: 10,
      ),
    ).listen((Position position) async {
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
        
        if (position.speed > 0) {
          compassHeading = position.heading;
        }
      });
      
      if (navigationStarted && destination != null) {
        await fetchAllRoutes();
      }
    });
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

  void selectDestination(LatLng location, String name, {String? address}) {
    if (isFetchingRoutes) return;
    
    setState(() {
      destination = location;
      destinationName = name;
      destinationAddress = address;
      suggestions.clear();
      searchResults.clear();
      searchController.clear();
      navigationStarted = false;
      allRoutes.clear();
      navigationSteps.clear();
      selectedRouteIndex = 0;
      isLoadingRoutes = false;
      isFetchingRoutes = false;
      showRouteSelectionPanel = false;
      
      resetMapRotation();
    });
    
    mapController.move(destination!, 12);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("✓ ${name.length > 40 ? name.substring(0, 40) + '...' : name}"),
            if (address != null) 
              Text(address, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    Future.delayed(const Duration(milliseconds: 500), () {
      fetchAllRoutes();
    });
  }
  
  void clearDestination() {
    setState(() {
      destination = null;
      destinationName = null;
      destinationAddress = null;
      navigationStarted = false;
      allRoutes.clear();
      navigationSteps.clear();
      currentRouteInfo = null;
      isLoadingRoutes = false;
      isFetchingRoutes = false;
      showRouteSelectionPanel = false;
      selectedRouteIndex = 0;
      
      resetMapRotation();
    });
    
    mapController.move(currentLocation, 14);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Destination cleared"),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void cancelRouteSelection() {
    setState(() {
      showRouteSelectionPanel = false;
      allRoutes.clear();
      navigationSteps.clear();
      currentRouteInfo = null;
      selectedRouteIndex = 0;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Route selection cancelled"),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> fetchAllRoutes() async {
    if (destination == null) return;
    
    if (isFetchingRoutes) return;
    
    if (lastRouteRequest != null && 
        DateTime.now().difference(lastRouteRequest!).inSeconds < 2) {
      return;
    }
    
    setState(() {
      isLoadingRoutes = true;
      isFetchingRoutes = true;
      showRouteSelectionPanel = false;
    });
    
    lastRouteRequest = DateTime.now();

    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${currentLocation.longitude},${currentLocation.latitude};'
          '${destination!.longitude},${destination!.latitude}'
          '?overview=full&geometries=geojson&steps=true&alternatives=true';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          List<RouteData> newRoutes = [];
          
          List<Color> routeColors = [
            Colors.blue,
            Colors.red,
            Colors.green,
            Colors.orange,
            Colors.purple,
            Colors.teal,
            Colors.pink,
            Colors.indigo,
          ];
          
          for (int i = 0; i < data['routes'].length && i < 5; i++) {
            final route = data['routes'][i];
            final geometry = route['geometry'];
            
            if (geometry != null && geometry['coordinates'] != null) {
              List<LatLng> routePoints = [];
              for (var coord in geometry['coordinates']) {
                routePoints.add(LatLng(coord[1], coord[0]));
              }
              
              double distance = route['distance'] / 1000;
              double duration = route['duration'] / 60;
              
              String routeType = _getRouteType(i);
              String description = _getRouteDescription(i, distance, duration);
              
              newRoutes.add(RouteData(
                id: i,
                points: routePoints,
                distance: distance,
                duration: duration,
                routeType: routeType,
                description: description,
                color: routeColors[i % routeColors.length],
                isSelected: i == selectedRouteIndex,
                routeData: route,
              ));
            }
          }
          
          setState(() {
            allRoutes = newRoutes;
            isLoadingRoutes = false;
            isFetchingRoutes = false;
            showRouteSelectionPanel = true;
            
            if (allRoutes.isNotEmpty && selectedRouteIndex < allRoutes.length) {
              currentRouteInfo = RouteInfo(
                distance: allRoutes[selectedRouteIndex].distance,
                duration: allRoutes[selectedRouteIndex].duration,
                startAddress: "Your Location",
                endAddress: destinationName ?? "Destination",
              );
              
              _extractNavigationSteps(allRoutes[selectedRouteIndex].routeData);
            }
          });
          
          if (allRoutes.isNotEmpty) {
            fitAllRoutesToMap();
          }
        } else {
          setState(() {
            isLoadingRoutes = false;
            isFetchingRoutes = false;
          });
          _showErrorSnackbar("No routes found");
        }
      } else {
        setState(() {
          isLoadingRoutes = false;
          isFetchingRoutes = false;
        });
        _showErrorSnackbar("Failed to fetch routes");
      }
    } catch (e) {
      print("Route Error: $e");
      setState(() {
        isLoadingRoutes = false;
        isFetchingRoutes = false;
      });
      _showErrorSnackbar("Error loading routes");
    }
  }
  
  String _getRouteType(int index) {
    switch(index) {
      case 0: return "Recommended";
      case 1: return "Fastest";
      case 2: return "Economy";
      case 3: return "Scenic";
      default: return "Route ${index + 1}";
    }
  }
  
  String _getRouteDescription(int index, double distance, double duration) {
    switch(index) {
      case 0: return "Best balance of time and distance";
      case 1: return "${duration.toStringAsFixed(0)} min • Fastest option";
      case 2: return "Fuel efficient route";
      case 3: return "Most scenic views";
      default: return "${distance.toStringAsFixed(1)} km • ${duration.toStringAsFixed(0)} min";
    }
  }
  
  void _extractNavigationSteps(dynamic routeData) {
    navigationSteps.clear();
    if (routeData != null && routeData['legs'] != null && routeData['legs'].isNotEmpty) {
      for (var leg in routeData['legs']) {
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
  
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  void fitAllRoutesToMap() {
    if (allRoutes.isEmpty) return;
    
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    
    minLat = math.min(minLat, currentLocation.latitude);
    maxLat = math.max(maxLat, currentLocation.latitude);
    minLng = math.min(minLng, currentLocation.longitude);
    maxLng = math.max(maxLng, currentLocation.longitude);
    
    if (destination != null) {
      minLat = math.min(minLat, destination!.latitude);
      maxLat = math.max(maxLat, destination!.latitude);
      minLng = math.min(minLng, destination!.longitude);
      maxLng = math.max(maxLng, destination!.longitude);
    }
    
    for (var route in allRoutes) {
      for (var point in route.points) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }
    }
    
    double latPadding = (maxLat - minLat) * 0.15;
    double lngPadding = (maxLng - minLng) * 0.15;
    
    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;
    
    LatLng center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );
    
    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double zoom = 12.0;
    
    if (latDiff > 0 || lngDiff > 0) {
      double maxDiff = math.max(latDiff, lngDiff);
      if (maxDiff < 0.01) zoom = 16;
      else if (maxDiff < 0.02) zoom = 15.5;
      else if (maxDiff < 0.05) zoom = 14.5;
      else if (maxDiff < 0.1) zoom = 13.5;
      else if (maxDiff < 0.2) zoom = 12.5;
      else if (maxDiff < 0.5) zoom = 11.5;
      else if (maxDiff < 1.0) zoom = 10.5;
      else zoom = 9.5;
    }
    
    mapController.move(center, zoom);
    resetMapRotation();
  }
  
  void selectRoute(int index) {
    setState(() {
      selectedRouteIndex = index;
      for (int i = 0; i < allRoutes.length; i++) {
        allRoutes[i].isSelected = (i == index);
      }
      currentRouteInfo = RouteInfo(
        distance: allRoutes[index].distance,
        duration: allRoutes[index].duration,
        startAddress: "Your Location",
        endAddress: destinationName ?? "Destination",
      );
      
      _extractNavigationSteps(allRoutes[index].routeData);
    });
    
    if (allRoutes[index].points.isNotEmpty) {
      fitSingleRouteToMap(allRoutes[index].points);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${allRoutes[index].routeType} route selected"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void startNavigationWithSelectedRoute() {
    if (allRoutes.isEmpty) return;
    
    setState(() {
      navigationStarted = true;
      showRouteSelectionPanel = false;
      currentTabIndex = 1;
    });
    
    if (allRoutes.isNotEmpty && selectedRouteIndex < allRoutes.length) {
      fitSingleRouteToMap(allRoutes[selectedRouteIndex].points);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Navigation started! Use two fingers to rotate the map."), 
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void fitSingleRouteToMap(List<LatLng> route) {
    if (route.isEmpty) return;
    
    double minLat = route.map((p) => p.latitude).reduce(math.min);
    double maxLat = route.map((p) => p.latitude).reduce(math.max);
    double minLng = route.map((p) => p.longitude).reduce(math.min);
    double maxLng = route.map((p) => p.longitude).reduce(math.max);
    
    minLat = math.min(minLat, currentLocation.latitude);
    maxLat = math.max(maxLat, currentLocation.latitude);
    minLng = math.min(minLng, currentLocation.longitude);
    maxLng = math.max(maxLng, currentLocation.longitude);
    
    if (destination != null) {
      minLat = math.min(minLat, destination!.latitude);
      maxLat = math.max(maxLat, destination!.latitude);
      minLng = math.min(minLng, destination!.longitude);
      maxLng = math.max(maxLng, destination!.longitude);
    }
    
    double latPadding = (maxLat - minLat) * 0.1;
    double lngPadding = (maxLng - minLng) * 0.1;
    
    minLat -= latPadding;
    maxLat += latPadding;
    minLng -= lngPadding;
    maxLng += lngPadding;
    
    LatLng center = LatLng(
      (minLat + maxLat) / 2,
      (minLng + maxLng) / 2,
    );
    
    double latDiff = maxLat - minLat;
    double lngDiff = maxLng - minLng;
    double zoom = 13.0;
    
    if (latDiff > 0 || lngDiff > 0) {
      double maxDiff = math.max(latDiff, lngDiff);
      if (maxDiff < 0.01) zoom = 16;
      else if (maxDiff < 0.02) zoom = 15;
      else if (maxDiff < 0.05) zoom = 14;
      else if (maxDiff < 0.1) zoom = 13;
      else if (maxDiff < 0.2) zoom = 12;
      else if (maxDiff < 0.5) zoom = 11;
      else zoom = 10;
    }
    
    mapController.move(center, zoom);
  }
  
  // Map Rotation Functions (no tilt)
  void rotateMap(double angle) {
    setState(() {
      currentRotation = angle % 360;
      showCompass = currentRotation.abs() > 5;
    });
  }
  
  void resetMapRotation() {
    setState(() {
      currentRotation = 0.0;
      showCompass = false;
    });
  }
  
  void resetToNorth() {
    rotateMap(0.0);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Map rotated to North"),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  void followUserDirection() {
    if (compassHeading > 0) {
      rotateMap(compassHeading);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Following device direction"),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getSimpleInstruction(String type) {
    switch (type) {
      case 'turn': return 'Turn';
      case 'new name': return 'Continue';
      case 'depart': return 'Start';
      case 'arrive': return 'Arrive';
      default: return 'Continue';
    }
  }

  void goToMyLocation() {
    mapController.move(currentLocation, 16);
    setState(() {
      currentZoom = 16;
    });
    resetMapRotation();
  }
  
  void stopNavigation() {
    setState(() {
      navigationStarted = false;
      navigationSteps.clear();
      currentRouteInfo = null;
    });
    resetMapRotation();
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
          // Map with rotation only (no 3D tilt)
          Transform.rotate(
            angle: currentRotation * math.pi / 180,
            child: FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: currentLocation,
                initialZoom: 13,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture) {
                    setState(() {
                      currentZoom = position.zoom;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: getTileLayerUrl(),
                  userAgentPackageName: 'com.example.app',
                ),
                
                if (allRoutes.isNotEmpty && !navigationStarted)
                  for (int i = 0; i < allRoutes.length; i++)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: allRoutes[i].points,
                          strokeWidth: selectedRouteIndex == i ? 8 : 4,
                          color: allRoutes[i].isSelected 
                              ? Colors.blue 
                              : allRoutes[i].color.withOpacity(0.7),
                          borderStrokeWidth: selectedRouteIndex == i ? 2 : 0,
                          borderColor: selectedRouteIndex == i ? Colors.white : Colors.transparent,
                        ),
                      ],
                    ),
                
                if (navigationStarted && allRoutes.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: allRoutes[selectedRouteIndex].points,
                        strokeWidth: 6,
                        color: Colors.blue,
                        borderStrokeWidth: 1,
                        borderColor: Colors.white,
                      ),
                    ],
                  ),
                
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation,
                      width: 80,
                      height: 80,
                      child: Transform.rotate(
                        angle: navigationStarted ? compassHeading * math.pi / 180 : 0,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.5),
                                blurRadius: 10,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.navigation, color: Colors.blue, size: 40),
                        ),
                      ),
                    ),
                    if (destination != null)
                      Marker(
                        point: destination!,
                        width: 80,
                        height: 80,
                        child: GestureDetector(
                          onTap: () => showLocationOptions(destination!, destinationName ?? "Destination", address: destinationAddress),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.location_pin, color: Colors.red, size: 45),
                          ),
                        ),
                      ),
                  ],
                ),
                
                if (isLoadingRoutes)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ),
              ],
            ),
          ),
          
          // Cancel Destination Button
          if (destination != null && !navigationStarted && !showRouteSelectionPanel)
            Positioned(
              top: 60,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  onPressed: clearDestination,
                  tooltip: "Cancel destination",
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          
          // Compass Button
          if (showCompass && !navigationStarted)
            Positioned(
              top: 120,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                onPressed: resetToNorth,
                backgroundColor: Colors.white,
                child: Transform.rotate(
                  angle: -currentRotation * math.pi / 180,
                  child: const Icon(Icons.compass_calibration, color: Colors.blue, size: 20),
                ),
              ),
            ),
          
          // Follow Direction Button (during navigation)
          if (navigationStarted)
            Positioned(
              bottom: 160,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                onPressed: followUserDirection,
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Colors.green, size: 20),
              ),
            ),
          
          // Top Search Bar - Fixed UI with proper boundaries
          if (currentTabIndex == 0 && !navigationStarted && !showRouteSelectionPanel && destination == null)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(30),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: "Search destinations...",
                            hintStyle: const TextStyle(fontSize: 14),
                            prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      searchController.clear();
                                      setState(() {
                                        suggestions.clear();
                                        searchResults.clear();
                                      });
                                    },
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 40),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                          ),
                          onChanged: onSearchChanged,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              FocusScope.of(context).unfocus();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          currentMapLayer == 'satellite' ? Icons.satellite :
                          currentMapLayer == 'dark' ? Icons.nightlight_round :
                          Icons.map,
                          color: Colors.blue,
                          size: 20,
                        ),
                        onPressed: () => showLayerMenu(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // Suggestions Dropdown - Fixed position and boundaries
          if (suggestions.isNotEmpty && currentTabIndex == 0 && !navigationStarted && !showRouteSelectionPanel && destination == null)
            Positioned(
              top: 108,
              left: 16,
              right: 80,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                  maxWidth: MediaQuery.of(context).size.width - 96,
                ),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: isSearching
                      ? const Center(child: Padding(
                          padding: EdgeInsets.all(20),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: suggestions.length,
                          itemBuilder: (context, index) {
                            final result = suggestions[index];
                            return ListTile(
                              dense: true,
                              leading: result['source'] == 'local'
                                  ? const Icon(Icons.local_airport, color: Colors.blue, size: 20)
                                  : result['source'] == 'saved'
                                  ? const Icon(Icons.bookmark, color: Colors.green, size: 20)
                                  : const Icon(Icons.location_on, color: Colors.grey, size: 20),
                              title: Text(
                                result['name'],
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                result['address'] ?? "${(result['distance'] as double).toStringAsFixed(1)} km away",
                                style: const TextStyle(fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: SizedBox(
                                width: 68,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.save, size: 18, color: Colors.green),
                                      onPressed: () {
                                        showSaveLocationDialog(
                                          LatLng(result['lat'], result['lon']),
                                          result['name'],
                                          address: result['address'],
                                        );
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.arrow_forward, size: 18, color: Colors.blue),
                                      onPressed: () {
                                        showLocationOptions(
                                          LatLng(result['lat'], result['lon']),
                                          result['name'],
                                          address: result['address'],
                                        );
                                      },
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 32),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          
          // Destination Info Card
          if (destination != null && !navigationStarted && !showRouteSelectionPanel && allRoutes.isEmpty && !isLoadingRoutes)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_pin, color: Colors.red, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  destinationName ?? "Destination",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (destinationAddress != null)
                                  Text(
                                    destinationAddress!,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.save, color: Colors.green, size: 20),
                            onPressed: () {
                              showSaveLocationDialog(
                                destination!,
                                destinationName ?? "Destination",
                                address: destinationAddress,
                              );
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red, size: 20),
                            onPressed: clearDestination,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 2),
                      const SizedBox(height: 8),
                      const Text(
                        "Finding routes...",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // ROUTE SELECTION PANEL
          if (showRouteSelectionPanel && allRoutes.isNotEmpty && !navigationStarted)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  destinationName ?? "Destination",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (destinationAddress != null)
                                  Text(
                                    destinationAddress!,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.save, color: Colors.green, size: 20),
                            onPressed: () {
                              showSaveLocationDialog(
                                destination!,
                                destinationName ?? "Destination",
                                address: destinationAddress,
                              );
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red, size: 20),
                            onPressed: cancelRouteSelection,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40),
                          ),
                        ],
                      ),
                    ),
                    
                    Expanded(
                      child: ListView.builder(
                        itemCount: allRoutes.length,
                        itemBuilder: (context, index) {
                          final route = allRoutes[index];
                          final isSelected = selectedRouteIndex == index;
                          
                          return GestureDetector(
                            onTap: () => selectRoute(index),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected ? route.color.withOpacity(0.1) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? route.color : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: route.color,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          route.routeType,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 13,
                                            color: isSelected ? route.color : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          route.description,
                                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.timeline, size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${route.distance.toStringAsFixed(1)} km",
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            const SizedBox(width: 12),
                                            const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                            const SizedBox(width: 4),
                                            Text(
                                              "${route.duration.toStringAsFixed(0)} min",
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  if (isSelected)
                                    const Icon(Icons.check_circle, color: Colors.blue, size: 20),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: cancelRouteSelection,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: const BorderSide(color: Colors.red),
                              ),
                              child: const Text("Cancel", style: TextStyle(color: Colors.red)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: startNavigationWithSelectedRoute,
                              icon: const Icon(Icons.navigation, size: 18),
                              label: const Text("Start", style: TextStyle(fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          // NAVIGATION ACTIVE CARD
          if (navigationStarted && currentRouteInfo != null)
            Positioned(
              top: 15,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.navigation, color: Colors.blue, size: 20),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Navigation Active", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
                                icon: const Icon(Icons.my_location, size: 18),
                                onPressed: goToMyLocation,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: stopNavigation,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 32),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (navigationSteps.isNotEmpty)
                      Container(
                        height: 70,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: navigationSteps.length > 3 ? 3 : navigationSteps.length,
                          itemBuilder: (context, index) {
                            final step = navigationSteps[index];
                            return Container(
                              width: 160,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Icon(step.type == 'turn' ? Icons.turn_right : Icons.directions, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(step.instruction, style: const TextStyle(fontSize: 10), maxLines: 2),
                                        Text(
                                          "${step.distance.toStringAsFixed(1)} km",
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
          
          // BOTTOM NAVIGATION BAR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: BottomNavigationBar(
                  currentIndex: currentTabIndex,
                  onTap: (index) {
                    setState(() {
                      currentTabIndex = index;
                    });
                    
                    if (index == 1 && allRoutes.isNotEmpty) {
                      if (allRoutes.isNotEmpty && selectedRouteIndex < allRoutes.length) {
                        fitSingleRouteToMap(allRoutes[selectedRouteIndex].points);
                      }
                    } else if (index == 0) {
                      mapController.move(currentLocation, currentZoom);
                      resetMapRotation();
                    }
                  },
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: Colors.blue,
                  unselectedItemColor: Colors.grey,
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.explore, size: 22),
                      label: 'Explore',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.route, size: 22),
                      label: 'Routes',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.bookmark, size: 22),
                      label: 'Saved',
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // ROUTES TAB
          if (currentTabIndex == 1 && allRoutes.isNotEmpty && !navigationStarted)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  padding: const EdgeInsets.all(15),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.route, color: Colors.blue, size: 20),
                                SizedBox(width: 8),
                                Text("All Routes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  currentTabIndex = 0;
                                  showRouteSelectionPanel = true;
                                });
                              },
                              icon: const Icon(Icons.visibility, size: 16),
                              label: const Text("View on Map", style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        ...List.generate(allRoutes.length, (index) {
                          final route = allRoutes[index];
                          final isSelected = selectedRouteIndex == index;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected ? route.color.withOpacity(0.1) : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? route.color : Colors.grey[300]!,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 50,
                                  color: route.color,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        route.routeType,
                                        style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          fontSize: 14,
                                          color: isSelected ? route.color : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        route.description,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 12,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.timeline, size: 12, color: Colors.grey),
                                              const SizedBox(width: 2),
                                              Text(
                                                "${route.distance.toStringAsFixed(1)} km",
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                              const SizedBox(width: 2),
                                              Text(
                                                "${route.duration.toStringAsFixed(0)} min",
                                                style: const TextStyle(fontSize: 11),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isSelected)
                                  ElevatedButton(
                                    onPressed: () => selectRoute(index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: route.color,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      minimumSize: const Size(60, 32),
                                      textStyle: const TextStyle(fontSize: 11),
                                    ),
                                    child: const Text("Select"),
                                  ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: Colors.blue, size: 24),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: startNavigationWithSelectedRoute,
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text("Start Navigation", style: TextStyle(fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // SAVED PLACES TAB
          if (currentTabIndex == 2 && !navigationStarted)
            Positioned(
              bottom: 80,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  padding: const EdgeInsets.all(15),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bookmark, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text("Saved Places", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(),
                      Expanded(
                        child: savedPlaces.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.bookmark_border, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text("No saved places yet", style: TextStyle(fontSize: 12, color: Colors.grey)),
                                    Text("Tap the save button on any location", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: savedPlaces.length,
                                itemBuilder: (context, index) {
                                  final place = savedPlaces[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    child: ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.blue[100],
                                        child: const Icon(Icons.place, color: Colors.blue, size: 16),
                                      ),
                                      title: Text(place.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      subtitle: Text(place.type, style: const TextStyle(fontSize: 11)),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                            onPressed: () => removeSavedPlace(index),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 32),
                                          ),
                                          const SizedBox(width: 4),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              selectDestination(
                                                LatLng(place.lat, place.lon),
                                                place.name,
                                                address: place.address,
                                              );
                                              setState(() {
                                                currentTabIndex = 0;
                                              });
                                            },
                                            icon: const Icon(Icons.navigation, size: 14),
                                            label: const Text("Go", style: TextStyle(fontSize: 11)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              minimumSize: const Size(50, 32),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // MY LOCATION BUTTON
          if (!navigationStarted)
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                onPressed: goToMyLocation,
                backgroundColor: Colors.white,
                child: const Icon(Icons.my_location, color: Colors.blue, size: 18),
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
            const Text('Map Style', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            _buildLayerOption('Default', 'standard', Icons.map),
            _buildLayerOption('Satellite', 'satellite', Icons.satellite),
            _buildLayerOption('Dark Mode', 'dark', Icons.nightlight_round),
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
          SnackBar(content: Text("$name view activated"), duration: const Duration(seconds: 1)),
        );
      },
    );
  }
}

class RouteData {
  final int id;
  final List<LatLng> points;
  final double distance;
  final double duration;
  final String routeType;
  final String description;
  final Color color;
  bool isSelected;
  final dynamic routeData;
  
  RouteData({
    required this.id,
    required this.points,
    required this.distance,
    required this.duration,
    required this.routeType,
    required this.description,
    required this.color,
    this.isSelected = false,
    this.routeData,
  });
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