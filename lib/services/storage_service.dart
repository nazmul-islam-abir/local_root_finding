import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/saved_place.dart';

class StorageService {
  static Future<void> savePlaces(List<SavedPlace> places) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/saved_places.json');
      final jsonList = places.map((place) => place.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      print("Error saving places: $e");
    }
  }

  static Future<List<SavedPlace>> loadPlaces() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/saved_places.json');
      
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        return jsonList.map((json) => SavedPlace.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print("Error loading places: $e");
      return [];
    }
  }
}