import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class SafeRoute {
  final List<RouteLatLng> waypoints;
  final double distance;
  final int duration;
  final int safeScore;
  final List<Map<String, dynamic>> steps;
  final List<String> warnings;
  final List<EmergencyService> policeStationsNearby;
  final List<EmergencyService> hospitalsNearby;
  final String? transportMode;
  final List<String>? hazards;
  final List<String>? safeFeatures;

  SafeRoute({
    required this.waypoints,
    required this.distance,
    required this.duration,
    required this.safeScore,
    this.steps = const [],
    this.warnings = const [],
    this.policeStationsNearby = const [],
    this.hospitalsNearby = const [],
    this.transportMode,
    this.hazards,
    this.safeFeatures,
  });

  factory SafeRoute.fromJson(Map<String, dynamic> json) {
    return SafeRoute(
      waypoints: (json['waypoints'] as List?)
              ?.map((e) => RouteLatLng(
                    (e['latitude'] ?? 0.0).toDouble(),
                    (e['longitude'] ?? 0.0).toDouble(),
                  ))
              .toList() ??
          [],
      distance: (json['distance'] ?? 0.0).toDouble(),
      duration: json['duration'] ?? 0,
      safeScore: json['safe_score'] ?? 0,
      steps: (json['steps'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      warnings:
          (json['warnings'] as List?)?.map((e) => e.toString()).toList() ?? [],
      policeStationsNearby: (json['police_stations_nearby'] as List?)
              ?.map((e) => EmergencyService.fromJson(e))
              .toList() ??
          [],
      hospitalsNearby: (json['hospitals_nearby'] as List?)
              ?.map((e) => EmergencyService.fromJson(e))
              .toList() ??
          [],
      transportMode: json['transport_mode'],
      hazards: (json['hazards'] as List?)?.cast<String>(),
      safeFeatures: (json['safe_features'] as List?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'waypoints': waypoints.map((e) => e.toJson()).toList(),
      'distance': distance,
      'duration': duration,
      'safe_score': safeScore,
      'steps': steps,
      'warnings': warnings,
      'police_stations_nearby':
          policeStationsNearby.map((e) => e.toJson()).toList(),
      'hospitals_nearby': hospitalsNearby.map((e) => e.toJson()).toList(),
      'transport_mode': transportMode,
      'hazards': hazards,
      'safe_features': safeFeatures,
    };
  }

  String getSafetyLevel() {
    if (safeScore >= 80) return 'Very Safe';
    if (safeScore >= 60) return 'Moderately Safe';
    if (safeScore >= 40) return 'Somewhat Risky';
    return 'High Risk';
  }

  Color getSafetyColor() {
    if (safeScore >= 80) return Colors.green;
    if (safeScore >= 60) return Colors.orange;
    if (safeScore >= 40) return Colors.orange.shade700;
    return Colors.red;
  }

  IconData getSafetyIcon() {
    if (safeScore >= 80) return Icons.security;
    if (safeScore >= 60) return Icons.shield;
    if (safeScore >= 40) return Icons.warning;
    return Icons.dangerous;
  }

  String getFormattedDistance() {
    if (distance < 1.0) {
      return '${(distance * 1000).round()} m';
    }
    return '${distance.toStringAsFixed(1)} km';
  }

  String getFormattedDuration() {
    if (duration < 60) {
      return '$duration min';
    }
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    if (minutes == 0) {
      return '$hours hr';
    }
    return '$hours hr $minutes min';
  }

  int getTotalNearbyServices() {
    return policeStationsNearby.length + hospitalsNearby.length;
  }

  EmergencyService? getNearestPoliceStation() {
    if (policeStationsNearby.isEmpty) return null;
    return policeStationsNearby.reduce((a, b) =>
        (a.distance ?? double.infinity) < (b.distance ?? double.infinity) ? a : b);
  }

  EmergencyService? getNearestHospital() {
    if (hospitalsNearby.isEmpty) return null;
    return hospitalsNearby.reduce((a, b) =>
        (a.distance ?? double.infinity) < (b.distance ?? double.infinity) ? a : b);
  }

  bool isSafe() {
    return safeScore >= 60 && warnings.isEmpty;
  }

  SafeRoute copyWith({
    List<RouteLatLng>? waypoints,
    double? distance,
    int? duration,
    int? safeScore,
    List<Map<String, dynamic>>? steps,
    List<String>? warnings,
    List<EmergencyService>? policeStationsNearby,
    List<EmergencyService>? hospitalsNearby,
    String? transportMode,
    List<String>? hazards,
    List<String>? safeFeatures,
  }) {
    return SafeRoute(
      waypoints: waypoints ?? this.waypoints,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
      safeScore: safeScore ?? this.safeScore,
      steps: steps ?? this.steps,
      warnings: warnings ?? this.warnings,
      policeStationsNearby: policeStationsNearby ?? this.policeStationsNearby,
      hospitalsNearby: hospitalsNearby ?? this.hospitalsNearby,
      transportMode: transportMode ?? this.transportMode,
      hazards: hazards ?? this.hazards,
      safeFeatures: safeFeatures ?? this.safeFeatures,
    );
  }
}

class RouteLatLng {
  final double latitude;
  final double longitude;

  RouteLatLng(this.latitude, this.longitude);

  factory RouteLatLng.fromJson(Map<String, dynamic> json) {
    return RouteLatLng(
      (json['latitude'] ?? 0.0).toDouble(),
      (json['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }

  double distanceTo(RouteLatLng other) {
    const double earthRadius = 6371;

    final double lat1 = latitude * 3.141592653589793 / 180;
    final double lat2 = other.latitude * 3.141592653589793 / 180;
    final double lon1 = longitude * 3.141592653589793 / 180;
    final double lon2 = other.longitude * 3.141592653589793 / 180;

    final double dlat = lat2 - lat1;
    final double dlon = lon2 - lon1;

    final double a =
        (dlat / 2) * (dlat / 2) + (lat1) * (lat2) * (dlon / 2) * (dlon / 2);
    final double c = 2 * sqrt(a);

    return earthRadius * c;
  }

  @override
  String toString() {
    return 'RouteLatLng(latitude: $latitude, longitude: $longitude)';
  }
}

class EmergencyService {
  final String name;
  final double lat;
  final double lng;
  final String? phone;
  final double? distance;
  final String? type;
  final String? address;
  final bool? isOpen24Hours;

  EmergencyService({
    required this.name,
    required this.lat,
    required this.lng,
    this.phone,
    this.distance,
    this.type,
    this.address,
    this.isOpen24Hours = false,
  });

  factory EmergencyService.fromJson(Map<String, dynamic> json) {
    return EmergencyService(
      name: json['name'] ?? '',
      lat: (json['lat'] ?? json['latitude'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? json['longitude'] ?? 0.0).toDouble(),
      phone: json['phone'],
      distance: (json['distance'] ?? 0.0).toDouble(),
      type: json['type'],
      address: json['address'],
      isOpen24Hours: json['is_open_24_hours'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lat': lat,
      'lng': lng,
      'phone': phone,
      'distance': distance,
      'type': type,
      'address': address,
      'is_open_24_hours': isOpen24Hours,
    };
  }

  LatLng toLatLng() {
    return LatLng(lat, lng);
  }

  String getFormattedDistance() {
    if (distance == null) return 'Unknown';
    if (distance! < 1.0) {
      return '${(distance! * 1000).round()} m';
    }
    return '${distance!.toStringAsFixed(1)} km';
  }

  IconData getMarkerIcon() {
    if (type == 'police') return Icons.local_police;
    if (type == 'hospital') return Icons.local_hospital;
    if (type == 'fire') return Icons.fire_extinguisher;
    return Icons.place;
  }

  Color getMarkerColor() {
    if (type == 'police') return Colors.blue;
    if (type == 'hospital') return Colors.red;
    if (type == 'fire') return Colors.orange;
    return Colors.grey;
  }

  String getGoogleMapsUrl() {
    return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
  }

  @override
  String toString() {
    return 'EmergencyService(name: $name, lat: $lat, lng: $lng, distance: $distance)';
  }
}

extension RouteLatLngListExtension on List<RouteLatLng> {
  double getTotalDistance() {
    if (length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < length - 1; i++) {
      total += this[i].distanceTo(this[i + 1]);
    }
    return total;
  }

  List<LatLng> toLatLngList() {
    return map((point) => point.toLatLng()).toList();
  }

  RouteLatLng getCenter() {
    if (isEmpty) return RouteLatLng(0, 0);

    double totalLat = 0;
    double totalLng = 0;
    for (var point in this) {
      totalLat += point.latitude;
      totalLng += point.longitude;
    }
    return RouteLatLng(totalLat / length, totalLng / length);
  }
}

extension EmergencyServiceListExtension on List<EmergencyService> {
  List<EmergencyService> getByType(String type) {
    return where((service) => service.type == type).toList();
  }

  List<EmergencyService> getSortedByDistance() {
    final list = List<EmergencyService>.from(this);
    list.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
    return list;
  }

  EmergencyService? getNearest() {
    if (isEmpty) return null;
    return reduce((a, b) =>
        (a.distance ?? double.infinity) < (b.distance ?? double.infinity) ? a : b);
  }

  List<EmergencyService> getWithinRadius(double radius) {
    return where((service) => (service.distance ?? 0) <= radius).toList();
  }
}