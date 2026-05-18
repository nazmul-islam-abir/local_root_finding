// widgets/route_detail_panel.dart
import 'package:flutter/material.dart';
import '../models/route_data.dart';
import '../models/route_info.dart';
import '../models/navigation_step.dart';

class RouteDetailPanel extends StatelessWidget {
  final RouteInfo routeInfo;
  final List<NavigationStep> steps;
  final List<RouteData> alternativeRoutes;
  final Function(int) onAlternativeRouteSelected;
  final VoidCallback onStartNavigation;
  final VoidCallback onClose;

  const RouteDetailPanel({
    super.key,
    required this.routeInfo,
    required this.steps,
    required this.alternativeRoutes,
    required this.onAlternativeRouteSelected,
    required this.onStartNavigation,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
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
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header with route summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.route, color: Colors.blue, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Route Details',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${routeInfo.startAddress} → ${routeInfo.endAddress}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.timeline, color: Colors.blue, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              '${routeInfo.distance.toStringAsFixed(1)} km',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Text('Distance', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.access_time, color: Colors.green, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              '${routeInfo.duration.toStringAsFixed(0)} min',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Text('Estimated Time', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Tab bar for steps and alternatives
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Directions'),
                      Tab(text: 'Alternatives'),
                    ],
                    labelColor: Colors.blue,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Directions tab
                        steps.isEmpty
                            ? const Center(child: Text('No step-by-step directions available'))
                            : ListView.builder(
                                itemCount: steps.length,
                                itemBuilder: (context, index) {
                                  final step = steps[index];
                                  return _buildStepTile(step, index);
                                },
                              ),
                        
                        // Alternatives tab
                        alternativeRoutes.isEmpty
                            ? const Center(child: Text('No alternative routes available'))
                            : ListView.builder(
                                itemCount: alternativeRoutes.length,
                                itemBuilder: (context, index) {
                                  final route = alternativeRoutes[index];
                                  return _buildAlternativeTile(route, index);
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Start navigation button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onStartNavigation,
                icon: const Icon(Icons.navigation),
                label: const Text('Start Navigation', style: TextStyle(fontSize: 16)),
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
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile(NavigationStep step, int index) {
    IconData icon;
    Color color;
    
    switch (step.type) {
      case 'turn':
        icon = Icons.turn_right;
        color = Colors.orange;
        break;
      case 'arrive':
        icon = Icons.flag;
        color = Colors.red;
        break;
      case 'depart':
        icon = Icons.play_arrow;
        color = Colors.green;
        break;
      default:
        icon = Icons.directions;
        color = Colors.blue;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction,
                  style: const TextStyle(fontSize: 13),
                ),
                Text(
                  '${step.distance.toStringAsFixed(1)} km • ${step.duration.toStringAsFixed(0)} min',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Text(
            (index + 1).toString(),
            style: TextStyle(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativeTile(RouteData route, int index) {
    return GestureDetector(
      onTap: () => onAlternativeRouteSelected(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: route.isSelected ? route.color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: route.isSelected ? route.color : Colors.grey[300]!,
            width: route.isSelected ? 2 : 1,
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
                  Row(
                    children: [
                      Text(
                        route.routeType,
                        style: TextStyle(
                          fontWeight: route.isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 13,
                          color: route.isSelected ? route.color : Colors.black87,
                        ),
                      ),
                      if (route.isSelected)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Selected',
                            style: TextStyle(fontSize: 9, color: Colors.white),
                          ),
                        ),
                    ],
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
            if (!route.isSelected)
              OutlinedButton(
                onPressed: () => onAlternativeRouteSelected(index),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: route.color),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: const Size(60, 32),
                ),
                child: Text('Select', style: TextStyle(color: route.color, fontSize: 11)),
              ),
            if (route.isSelected)
              const Icon(Icons.check_circle, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }
}