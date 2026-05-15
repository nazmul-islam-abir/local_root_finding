import 'package:flutter/material.dart';
import '../models/saved_place.dart';

class SavedPlacesScreen extends StatelessWidget {
  final List<SavedPlace> places;
  final Function(int) onRemove;
  final Function(SavedPlace) onNavigate;

  const SavedPlacesScreen({
    super.key,
    required this.places,
    required this.onRemove,
    required this.onNavigate,
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
              child: places.isEmpty
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
                      itemCount: places.length,
                      itemBuilder: (context, index) {
                        final place = places[index];
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
                                  onPressed: () => onRemove(index),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 32),
                                ),
                                const SizedBox(width: 4),
                                ElevatedButton.icon(
                                  onPressed: () => onNavigate(place),
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
    );
  }
}