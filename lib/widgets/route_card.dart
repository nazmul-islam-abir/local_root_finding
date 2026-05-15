import 'package:flutter/material.dart';
import '../models/route_data.dart';

class RouteCard extends StatelessWidget {
  final RouteData route;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onSelect;

  const RouteCard({
    super.key,
    required this.route,
    required this.isSelected,
    required this.onTap,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
            if (onSelect != null && !isSelected)
              ElevatedButton(
                onPressed: onSelect,
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
              const Icon(Icons.check_circle, color: Colors.blue, size: 20),
          ],
        ),
      ),
    );
  }
}