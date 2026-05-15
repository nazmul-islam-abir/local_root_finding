import 'package:flutter/material.dart';
import '../models/route_info.dart';
import '../models/navigation_step.dart';

class NavigationCard extends StatelessWidget {
  final RouteInfo routeInfo;
  final List<NavigationStep> steps;
  final VoidCallback onMyLocation;
  final VoidCallback onStop;

  const NavigationCard({
    super.key,
    required this.routeInfo,
    required this.steps,
    required this.onMyLocation,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                          "${routeInfo.distance.toStringAsFixed(1)} km • ${routeInfo.duration.toStringAsFixed(0)} min",
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
                      onPressed: onMyLocation,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: onStop,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (steps.isNotEmpty)
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: steps.length > 3 ? 3 : steps.length,
                itemBuilder: (context, index) {
                  final step = steps[index];
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
    );
  }
}