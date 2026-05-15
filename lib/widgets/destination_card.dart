import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class DestinationCard extends StatelessWidget {
  final String destinationName;
  final String? destinationAddress;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const DestinationCard({
    super.key,
    required this.destinationName,
    this.destinationAddress,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
                        destinationName,
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
                  onPressed: onSave,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 20),
                  onPressed: onCancel,
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
    );
  }
}