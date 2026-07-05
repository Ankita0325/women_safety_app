import 'package:flutter/material.dart';
import '../models/route_model.dart';
import 'api_service.dart';

class RouteService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  SafeRoute? _currentRoute;
  List<SafeRoute> _routeHistory = [];

  bool get isLoading => _isLoading;
  SafeRoute? get currentRoute => _currentRoute;
  List<SafeRoute> get routeHistory => _routeHistory;

  Future<SafeRoute> getSafeRoute({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
    bool avoidUnsafeAreas = true,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/routes/safe-route',
        body: {
          'start_lat': startLat,
          'start_lng': startLng,
          'end_lat': endLat,
          'end_lng': endLng,
          'avoid_unsafe_areas': avoidUnsafeAreas,
        },
      );

      _currentRoute = SafeRoute.fromJson(response);
      notifyListeners();
      return _currentRoute!;
    } catch (e) {
      print('Get safe route error: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> getNearbySafeZones({
    required double lat,
    required double lng,
    double radius = 5,
  }) async {
    try {
      final response = await _apiService.get(
        '/routes/nearby-safe-zones?lat=$lat&lng=$lng&radius=$radius',
      );
      return response;
    } catch (e) {
      print('Get nearby safe zones error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> getRouteSafetyScore({
    required double lat,
    required double lng,
  }) async {
    try {
      final response = await _apiService.get(
        '/routes/route-safety-score?lat=$lat&lng=$lng',
      );
      return response;
    } catch (e) {
      print('Get route safety score error: $e');
      return {'safety_score': 50, 'risk_level': 'medium'};
    }
  }
}
