import 'package:flutter/material.dart';
import '../models/route_data.dart';
import '../widgets/route_card.dart';

class RoutesScreen extends StatelessWidget {
  final List<RouteData> routes;
  final int selectedIndex;
  final Function(int) onRouteSelected;
  final VoidCallback onStartNavigation;

  const RoutesScreen({
    super.key,
    required this.routes,
    required this.selectedIndex,
    required this.onRouteSelected,
    required this.onStartNavigation,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
              const Row(
                children: [
                  Icon(Icons.route, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text("All Routes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(),
              ...List.generate(routes.length, (index) {
                final route = routes[index];
                final isSelected = selectedIndex == index;
                
                return RouteCard(
                  route: route,
                  isSelected: isSelected,
                  onTap: () => onRouteSelected(index),
                  onSelect: () => onRouteSelected(index),
                );
              }),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onStartNavigation,
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
    );
  }
}