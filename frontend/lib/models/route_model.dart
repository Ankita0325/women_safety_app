class SafeRoute {
  final List<RouteLatLng> waypoints;
  final double distance;
  final int duration;
  final int safeScore;
  final List<Map<String, dynamic>> steps;
  final List<String> warnings;
  final List<EmergencyService> policeStationsNearby;
  final List<EmergencyService> hospitalsNearby;

  SafeRoute({
    required this.waypoints,
    required this.distance,
    required this.duration,
    required this.safeScore,
    this.steps = const [],
    this.warnings = const [],
    this.policeStationsNearby = const [],
    this.hospitalsNearby = const [],
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
    );
  }
}

class RouteLatLng {
  final double latitude;
  final double longitude;

  RouteLatLng(this.latitude, this.longitude);

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class EmergencyService {
  final String name;
  final double lat;
  final double lng;
  final String? phone;
  final double? distance;

  EmergencyService({
    required this.name,
    required this.lat,
    required this.lng,
    this.phone,
    this.distance,
  });

  factory EmergencyService.fromJson(Map<String, dynamic> json) {
    return EmergencyService(
      name: json['name'] ?? '',
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      phone: json['phone'],
      distance: (json['distance'] ?? 0.0).toDouble(),
    );
  }
}
