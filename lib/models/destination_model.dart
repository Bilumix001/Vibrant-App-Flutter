// ════════════════════════════════════════════════════════
// lib/models/destination_model.dart
// ════════════════════════════════════════════════════════

import 'package:latlong2/latlong.dart';

class RouteModel {
  final int    id;
  final String name;
  final String description;
  final String color;
  final List<LatLng> coordinates;

  const RouteModel({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.coordinates,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final rawCoords = json['coordinates'] as List<dynamic>? ?? [];
    final coords = rawCoords.map((c) => LatLng(
      (c['lat'] as num).toDouble(),
      (c['lng'] as num).toDouble(),
    )).toList();

    return RouteModel(
      id:          json['id']          as int,
      name:        json['name']        as String,
      description: json['description'] as String? ?? '',
      color:       json['color']       as String? ?? '#05c46b',
      coordinates: coords,
    );
  }
}

class DestinationModel {
  final int        id;
  final String     name;
  final String     description;
  final double     latitude;
  final double     longitude;
  final String     department;
  final String     province;
  final String     district;
  final String     imageUrl;
  final bool       isPopular;   // ← controla el tamaño del marcador
  final RouteModel? route;

  const DestinationModel({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.department,
    required this.province,
    required this.district,
    required this.imageUrl,
    required this.isPopular,
    this.route,
  });

  bool get hasRoute => route != null && route!.coordinates.isNotEmpty;

  /// Texto de ubicación formateado para mostrar en la card
  String get locationLabel {
    final parts = <String>[];
    if (district.isNotEmpty)   parts.add(district);
    if (department.isNotEmpty) parts.add(department);
    return parts.join(', ');
  }

  factory DestinationModel.fromJson(Map<String, dynamic> json) {
    return DestinationModel(
      id:          json['id']          as int,
      name:        json['name']        as String,
      description: json['description'] as String? ?? '',
      latitude:    (json['latitude']   as num).toDouble(),
      longitude:   (json['longitude']  as num).toDouble(),
      department:  json['department']  as String? ?? '',
      province:    json['province']    as String? ?? '',
      district:    json['district']    as String? ?? '',
      imageUrl:    json['image_url']   as String? ?? '',
      isPopular:   json['is_popular']  as bool? ?? false,
      route: json['route'] != null
          ? RouteModel.fromJson(json['route'] as Map<String, dynamic>)
          : null,
    );
  }
}