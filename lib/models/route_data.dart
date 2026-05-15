import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

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