// source_destination_screen.dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/place_location.dart';
import '../models/route_data.dart';
import '../models/route_info.dart';
import '../models/navigation_step.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SourceDestinationScreen extends StatefulWidget {
  final Function(PlaceLocation, PlaceLocation, List<RouteData>, RouteInfo?, List<NavigationStep>) onRouteCalculated;
  
  const SourceDestinationScreen({
    super.key,
    required this.onRouteCalculated,
  });

  @override
  State<SourceDestinationScreen> createState() => _SourceDestinationScreenState();
}

class _SourceDestinationScreenState extends State<SourceDestinationScreen> {
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  
  PlaceLocation? _sourcePlace;
  PlaceLocation? _destinationPlace;
  
  List<Map<String, dynamic>> _sourceSuggestions = [];
  List<Map<String, dynamic>> _destinationSuggestions = [];
  
  bool _isSearchingSource = false;
  bool _isSearchingDestination = false;
  bool _isCalculating = false;
  
  // Saved places for quick access
  List<Map<String, dynamic>> _recentPlaces = [];
  List<Map<String, dynamic>> _suggestedPlaces = [];

  @override
  void initState() {
    super.initState();
    _loadRecentPlaces();
    _loadSuggestedPlaces();
  }

  void _loadRecentPlaces() {
    _recentPlaces = [
      {'name': 'Home', 'icon': Icons.home, 'color': Colors.blue},
      {'name': 'Work', 'icon': Icons.work, 'color': Colors.orange},
      {'name': 'Gym', 'icon': Icons.fitness_center, 'color': Colors.green},
      {'name': 'Cafe', 'icon': Icons.local_cafe, 'color': Colors.brown},
    ];
  }

  void _loadSuggestedPlaces() {
    _suggestedPlaces = [
      {'name': 'Hazrat Shahjalal Airport', 'lat': 23.8433, 'lon': 90.3978, 'address': 'Dhaka'},
      {'name': "Cox's Bazar Sea Beach", 'lat': 21.4272, 'lon': 91.9822, 'address': "Cox's Bazar"},
      {'name': 'Sundarbans', 'lat': 21.9497, 'lon': 89.1833, 'address': 'Khulna'},
      {'name': 'National Parliament House', 'lat': 23.7625, 'lon': 90.3883, 'address': 'Dhaka'},
    ];
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(String query, bool isSource) async {
    if (query.isEmpty) {
      setState(() {
        if (isSource) {
          _sourceSuggestions.clear();
          _isSearchingSource = false;
        } else {
          _destinationSuggestions.clear();
          _isSearchingDestination = false;
        }
      });
      return;
    }

    setState(() {
      if (isSource) {
        _isSearchingSource = true;
      } else {
        _isSearchingDestination = true;
      }
    });

    try {
      final url = 'https://nominatim.openstreetmap.org/search?'
          'q=$query,Bangladesh'
          '&format=json'
          '&limit=8'
          '&addressdetails=1';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {"User-Agent": "Flutter Map App", "Accept-Language": "bn,en"},
      );
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        final suggestions = data.map((item) {
          return {
            'name': item['display_name'].split(',').first,
            'full_address': item['display_name'],
            'lat': double.parse(item['lat']),
            'lon': double.parse(item['lon']),
            'type': item['type'],
            'importance': item['importance'] ?? 0,
          };
        }).toList();
        
        // Sort by importance
        suggestions.sort((a, b) => (b['importance'] as double).compareTo(a['importance'] as double));
        
        setState(() {
          if (isSource) {
            _sourceSuggestions = suggestions;
            _isSearchingSource = false;
          } else {
            _destinationSuggestions = suggestions;
            _isSearchingDestination = false;
          }
        });
      }
    } catch (e) {
      print("Search error: $e");
      setState(() {
        if (isSource) {
          _isSearchingSource = false;
        } else {
          _isSearchingDestination = false;
        }
      });
    }
  }

  void _selectLocation(Map<String, dynamic> location, bool isSource) {
    final place = PlaceLocation(
      name: location['name'],
      address: location['full_address'],
      coordinates: LatLng(location['lat'], location['lon']),
      type: location['type'],
    );
    
    setState(() {
      if (isSource) {
        _sourcePlace = place;
        _sourceController.text = place.name;
        _sourceSuggestions.clear();
      } else {
        _destinationPlace = place;
        _destinationController.text = place.name;
        _destinationSuggestions.clear();
      }
    });
  }

  void _selectQuickPlace(Map<String, dynamic> place, bool isSource) {
    final placeLocation = PlaceLocation(
      name: place['name'],
      address: place['address'] ?? place['name'],
      coordinates: LatLng(place['lat'], place['lon']),
      type: 'Quick Place',
    );
    
    setState(() {
      if (isSource) {
        _sourcePlace = placeLocation;
        _sourceController.text = placeLocation.name;
      } else {
        _destinationPlace = placeLocation;
        _destinationController.text = placeLocation.name;
      }
    });
  }

  void _swapPlaces() {
    if (_sourcePlace != null && _destinationPlace != null) {
      setState(() {
        final temp = _sourcePlace;
        _sourcePlace = _destinationPlace;
        _destinationPlace = temp;
        
        _sourceController.text = _sourcePlace!.name;
        _destinationController.text = _destinationPlace!.name;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 Source and destination swapped'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _useCurrentLocation(bool isSource) async {
    try {
      final position = await LocationService.getCurrentLocation();
      
      // Reverse geocoding to get address
      String address = "Current Location";
      try {
        final url = 'https://nominatim.openstreetmap.org/reverse?'
            'lat=${position.latitude}&lon=${position.longitude}&format=json';
        final response = await http.get(
          Uri.parse(url),
          headers: {"User-Agent": "Flutter Map App"},
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          address = data['display_name'] ?? "Current Location";
        }
      } catch (e) {
        print("Reverse geocoding error: $e");
      }
      
      final place = PlaceLocation(
        name: 'My Location',
        address: address,
        coordinates: LatLng(position.latitude, position.longitude),
        type: 'Current Location',
      );
      
      setState(() {
        if (isSource) {
          _sourcePlace = place;
          _sourceController.text = 'My Location';
        } else {
          _destinationPlace = place;
          _destinationController.text = 'My Location';
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('📍 ${isSource ? "Source" : "Destination"} set to current location'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not get current location'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _calculateAndNavigate() async {
    if (_sourcePlace == null) {
      _showError('Please select a source location');
      return;
    }
    
    if (_destinationPlace == null) {
      _showError('Please select a destination');
      return;
    }

    setState(() {
      _isCalculating = true;
    });

    try {
      // Fetch routes
      final data = await RoutingService.fetchRoutes(
        _sourcePlace!.coordinates,
        _destinationPlace!.coordinates,
      );
      
      if (data != null && data['routes'] != null && data['routes'].isNotEmpty) {
        List<RouteData> routes = [];
        List<Color> routeColors = [
          Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple,
        ];
        
        for (int i = 0; i < data['routes'].length && i < 5; i++) {
          final route = data['routes'][i];
          final geometry = route['geometry'];
          
          if (geometry != null && geometry['coordinates'] != null) {
            List<LatLng> routePoints = RoutingService.decodePolyline(geometry['coordinates']);
            
            double distance = route['distance'] / 1000;
            double duration = route['duration'] / 60;
            
            String routeType = _getRouteType(i);
            String description = _getRouteDescription(i, distance, duration);
            
            routes.add(RouteData(
              id: i,
              points: routePoints,
              distance: distance,
              duration: duration,
              routeType: routeType,
              description: description,
              color: routeColors[i % routeColors.length],
              isSelected: i == 0,
              routeData: route,
            ));
          }
        }
        
        // Extract navigation steps
        List<NavigationStep> steps = [];
        if (data['routes'].isNotEmpty) {
          final routeData = data['routes'][0];
          if (routeData['legs'] != null && routeData['legs'].isNotEmpty) {
            for (var leg in routeData['legs']) {
              if (leg['steps'] != null) {
                for (var step in leg['steps']) {
                  String instruction = step['maneuver']['instruction'] ?? 
                                      _getSimpleInstruction(step['maneuver']['type'] ?? '');
                  double stepDistance = (step['distance'] ?? 0) / 1000;
                  double stepDuration = (step['duration'] ?? 0) / 60;
                  
                  steps.add(NavigationStep(
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
        
        // Create route info
        RouteInfo routeInfo = RouteInfo(
          distance: routes[0].distance,
          duration: routes[0].duration,
          startAddress: _sourcePlace!.address,
          endAddress: _destinationPlace!.address,
        );
        
        widget.onRouteCalculated(_sourcePlace!, _destinationPlace!, routes, routeInfo, steps);
        Navigator.pop(context);
      } else {
        _showError('No routes found between these locations');
      }
    } catch (e) {
      _showError('Error calculating route: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCalculating = false;
        });
      }
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
  
  String _getSimpleInstruction(String type) {
    switch (type) {
      case 'turn': return 'Turn';
      case 'new name': return 'Continue';
      case 'depart': return 'Start';
      case 'arrive': return 'Arrive';
      default: return 'Continue';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Your Route'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _sourcePlace = null;
                _destinationPlace = null;
                _sourceController.clear();
                _destinationController.clear();
              });
            },
            tooltip: 'Clear all',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  
                  // Source Section
                  _buildLocationCard(
                    title: 'Source',
                    icon: Icons.circle,
                    iconColor: Colors.green,
                    controller: _sourceController,
                    place: _sourcePlace,
                    suggestions: _sourceSuggestions,
                    isSearching: _isSearchingSource,
                    onSearch: (value) => _searchLocation(value, true),
                    onSelect: (location) => _selectLocation(location, true),
                    onClear: () {
                      setState(() {
                        _sourcePlace = null;
                        _sourceController.clear();
                      });
                    },
                    onUseCurrent: () => _useCurrentLocation(true),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Swap Button
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.swap_vert, color: Colors.blue, size: 28),
                        onPressed: _swapPlaces,
                        tooltip: 'Swap',
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Destination Section
                  _buildLocationCard(
                    title: 'Destination',
                    icon: Icons.location_on,
                    iconColor: Colors.red,
                    controller: _destinationController,
                    place: _destinationPlace,
                    suggestions: _destinationSuggestions,
                    isSearching: _isSearchingDestination,
                    onSearch: (value) => _searchLocation(value, false),
                    onSelect: (location) => _selectLocation(location, false),
                    onClear: () {
                      setState(() {
                        _destinationPlace = null;
                        _destinationController.clear();
                      });
                    },
                    onUseCurrent: () => _useCurrentLocation(false),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Quick Suggestions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '✨ Suggested Places',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _suggestedPlaces.length,
                            itemBuilder: (context, index) {
                              final place = _suggestedPlaces[index];
                              return GestureDetector(
                                onTap: () {
                                  _showPlaceOptions(place);
                                },
                                child: Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey[300]!),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.place, color: Colors.blue[400], size: 24),
                                      const SizedBox(height: 4),
                                      Text(
                                        place['name'].length > 12 
                                            ? '${place['name'].substring(0, 12)}...' 
                                            : place['name'],
                                        style: const TextStyle(fontSize: 11),
                                        textAlign: TextAlign.center,
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
                  
                  const SizedBox(height: 16),
                  
                  // Recent Places
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🕒 Recent Places',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: _recentPlaces.map((place) {
                            return Chip(
                              avatar: Icon(place['icon'], size: 16, color: place['color']),
                              label: Text(place['name']),
                              onDeleted: () {},
                              deleteIcon: const SizedBox.shrink(),
                              backgroundColor: Colors.grey[100],
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // Calculate Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isCalculating ? null : _calculateAndNavigate,
                    icon: _isCalculating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.route),
                    label: Text(
                      _isCalculating ? 'Calculating Route...' : 'Show Route Details',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'View distance, time, turn-by-turn directions and alternative routes',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required TextEditingController controller,
    required PlaceLocation? place,
    required List<Map<String, dynamic>> suggestions,
    required bool isSearching,
    required Function(String) onSearch,
    required Function(Map<String, dynamic>) onSelect,
    required VoidCallback onClear,
    required VoidCallback onUseCurrent,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                if (place == null)
                  TextButton.icon(
                    onPressed: onUseCurrent,
                    icon: const Icon(Icons.my_location, size: 16),
                    label: const Text('Current', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Search $title...',
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: onClear,
                        padding: EdgeInsets.zero,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
              ),
              onChanged: onSearch,
            ),
          ),
          if (isSearching)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          if (suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: suggestions.length,
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  return ListTile(
                    leading: Icon(icon, color: iconColor, size: 18),
                    title: Text(
                      suggestion['name'],
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      suggestion['full_address'],
                      style: const TextStyle(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
                    onTap: () => onSelect(suggestion),
                    dense: true,
                  );
                },
              ),
            ),
          if (place != null)
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: iconColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: iconColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          place.address,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showPlaceOptions(Map<String, dynamic> place) {
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
              place['name'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _selectQuickPlace(place, true);
                    },
                    icon: const Icon(Icons.circle, color: Colors.green, size: 16),
                    label: const Text('Set as Source'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _selectQuickPlace(place, false);
                    },
                    icon: const Icon(Icons.location_on, color: Colors.red, size: 16),
                    label: const Text('Set as Destination'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}