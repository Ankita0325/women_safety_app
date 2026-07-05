import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  bool _isServiceEnabled = false;
  LocationPermission? _permission;
  String? _error;
  List<Position> _locationHistory = [];
  bool _isTracking = false;
  StreamSubscription<Position>? _positionStream;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  bool get isServiceEnabled => _isServiceEnabled;
  String? get error => _error;
  List<Position> get locationHistory => _locationHistory;
  bool get isTracking => _isTracking;

  LocationService() {
    initialize();
  }

  Future<void> initialize() async {
    await _checkLocationService();
    await _requestPermission();
    await _getCurrentLocation();
  }

  Future<void> _checkLocationService() async {
    try {
      _isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      notifyListeners();
    } catch (e) {
      _setError('Error checking location service: $e');
    }
  }

  Future<void> _requestPermission() async {
    try {
      final status = await Permission.location.request();
      _permission = await Geolocator.checkPermission();

      if (_permission == LocationPermission.denied) {
        _setError('Location permission denied');
      } else if (_permission == LocationPermission.deniedForever) {
        _setError('Location permission permanently denied');
      }

      notifyListeners();
    } catch (e) {
      _setError('Error requesting permission: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    if (!_isServiceEnabled) {
      await _checkLocationService();
      if (!_isServiceEnabled) {
        _setError('Location services are disabled');
        await Geolocator.openLocationSettings();
        return;
      }
    }

    if (_permission == LocationPermission.denied ||
        _permission == LocationPermission.deniedForever) {
      await _requestPermission();
      if (_permission != LocationPermission.whileInUse &&
          _permission != LocationPermission.always) {
        _setError('Location permission not granted');
        return;
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      if (_currentPosition != null) {
        _addToHistory(_currentPosition!);
      }

      notifyListeners();
    } catch (e) {
      _setError('Error getting location: $e');
      print('Error getting location: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLocation() async {
    await _getCurrentLocation();
  }

  Future<Position?> getCurrentPosition() async {
    if (_currentPosition != null) {
      return _currentPosition;
    }
    await _getCurrentLocation();
    return _currentPosition;
  }

  Future<double> calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) async {
    try {
      final distance = await Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
      return distance / 1000; // Convert to km
    } catch (e) {
      _setError('Error calculating distance: $e');
      return 0.0;
    }
  }

  Future<bool> isLocationEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      _setError('Error checking location enabled: $e');
      return false;
    }
  }

  // Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      _setError('Error checking permission: $e');
      return false;
    }
  }

  // Open app settings
  Future<void> openAppSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (e) {
      _setError('Error opening app settings: $e');
    }
  }

  // Start tracking location changes
  Future<void> startTracking({
    Function(Position)? onLocationChanged,
    Duration interval = const Duration(seconds: 5),
  }) async {
    if (_isTracking) return;

    _isTracking = true;
    _locationHistory.clear();
    notifyListeners();

    try {
      final settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10 meters
        timeLimit: interval,
      );

      _positionStream = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen((Position position) {
        _currentPosition = position;
        _addToHistory(position);
        notifyListeners();

        if (onLocationChanged != null) {
          onLocationChanged(position);
        }
      });
    } catch (e) {
      _setError('Error starting location tracking: $e');
      _isTracking = false;
      notifyListeners();
    }
  }

  // Stop tracking location changes
  void stopTracking() {
    if (_positionStream != null) {
      _positionStream!.cancel();
      _positionStream = null;
    }
    _isTracking = false;
    _locationHistory.clear();
    notifyListeners();
  }

  // Add position to history
  void _addToHistory(Position position) {
    _locationHistory.add(position);
    // Keep only last 100 positions
    if (_locationHistory.length > 100) {
      _locationHistory.removeAt(0);
    }
  }

  // Get last N locations from history
  List<Position> getLastLocations(int count) {
    if (_locationHistory.isEmpty) return [];
    final start = _locationHistory.length - count;
    if (start < 0) return _locationHistory.toList();
    return _locationHistory.sublist(start);
  }

  // Get average speed from recent locations
  double getAverageSpeed() {
    if (_locationHistory.length < 2) return 0.0;

    double totalSpeed = 0.0;
    int count = 0;

    for (int i = _locationHistory.length - 1; i > 0; i--) {
      final current = _locationHistory[i];
      final previous = _locationHistory[i - 1];
      if (current.speed != null && previous.speed != null) {
        totalSpeed += current.speed!;
        count++;
      }
    }

    return count > 0 ? totalSpeed / count : 0.0;
  }

  // Get distance traveled from history
  double getDistanceTraveled() {
    if (_locationHistory.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 1; i < _locationHistory.length; i++) {
      final current = _locationHistory[i];
      final previous = _locationHistory[i - 1];

      final distance = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        current.latitude,
        current.longitude,
      );
      totalDistance += distance;
    }

    return totalDistance / 1000; // Convert to km
  }

  // Get accuracy level
  String getAccuracyString() {
    if (_currentPosition == null) return 'Unknown';

    final accuracy = _currentPosition!.accuracy;
    if (accuracy < 10) return 'High (±${accuracy.toStringAsFixed(0)}m)';
    if (accuracy < 50) return 'Medium (±${accuracy.toStringAsFixed(0)}m)';
    if (accuracy < 100) return 'Low (±${accuracy.toStringAsFixed(0)}m)';
    return 'Poor (±${accuracy.toStringAsFixed(0)}m)';
  }

  // Get altitude
  double? getAltitude() {
    return _currentPosition?.altitude;
  }

  // Get speed
  double? getSpeed() {
    return _currentPosition?.speed;
  }

  // Get bearing
  double? getBearing() {
    return _currentPosition?.heading;
  }

  // Check if location is accurate enough
  bool isLocationAccurate() {
    if (_currentPosition == null) return false;
    return _currentPosition!.accuracy < 50; // Less than 50 meters accuracy
  }

  // Get location as string
  String getLocationString() {
    if (_currentPosition == null) return 'No location';
    return '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}';
  }

  // Get location with address (requires geocoding)
  Future<String?> getAddressFromLocation() async {
    if (_currentPosition == null) return null;

    try {
      // Note: placemarkFromCoordinates requires geocoding package
      // For now, return a basic location string
      return '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}';
    } catch (e) {
      _setError('Error getting address: $e');
      return null;
    }
  }

  // Get location with full details
  Future<Map<String, dynamic>> getLocationDetails() async {
    if (_currentPosition == null) {
      return {'error': 'No location available'};
    }

    try {
      Map<String, dynamic> details = {
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'accuracy': _currentPosition!.accuracy,
        'altitude': _currentPosition!.altitude,
        'speed': _currentPosition!.speed,
        'heading': _currentPosition!.heading,
        'timestamp': _currentPosition!.timestamp,
      };

      return details;
    } catch (e) {
      _setError('Error getting location details: $e');
      return {'error': e.toString()};
    }
  }

  // Clear history
  void clearHistory() {
    _locationHistory.clear();
    notifyListeners();
  }

  // Set error
  void _setError(String error) {
    _error = error;
    print('LocationService Error: $error');
    notifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Request location permission (external)
  Future<bool> requestPermission() async {
    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        _permission = await Geolocator.checkPermission();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _setError('Error requesting permission: $e');
      return false;
    }
  }

  // Check if we have all required permissions
  Future<bool> hasAllPermissions() async {
    final locationEnabled = await isLocationEnabled();
    final permissionGranted = await hasLocationPermission();
    return locationEnabled && permissionGranted;
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

// Extension methods for Position
extension PositionExtension on Position {
  // Get formatted location string
  String get formattedLocation {
    return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
  }

  // Get Google Maps URL
  String get googleMapsUrl {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  // Get distance to another position in meters
  double distanceTo(Position other) {
    return Geolocator.distanceBetween(
      latitude,
      longitude,
      other.latitude,
      other.longitude,
    );
  }

  // Get distance to another position in kilometers
  double distanceToKm(Position other) {
    return distanceTo(other) / 1000;
  }

  // Check if position is within radius
  bool isWithinRadius(Position center, double radiusInMeters) {
    return distanceTo(center) <= radiusInMeters;
  }

  // Get formatted altitude
  String get formattedAltitude {
    if (altitude == null) return 'N/A';
    return '${altitude!.toStringAsFixed(1)}m';
  }

  // Get formatted speed
  String get formattedSpeed {
    if (speed == null) return 'N/A';
    return '${(speed! * 3.6).toStringAsFixed(1)} km/h';
  }

  // Get formatted accuracy
  String get formattedAccuracy {
    if (accuracy == null) return 'N/A';
    return '±${accuracy!.toStringAsFixed(1)}m';
  }

  // Get formatted heading
  String get formattedHeading {
    if (heading == null) return 'N/A';
    return '${heading!.toStringAsFixed(1)}°';
  }

  // Get direction from heading
  String get headingDirection {
    if (heading == null) return 'N/A';
    final h = heading!;
    if (h >= 337.5 || h < 22.5) return 'North';
    if (h >= 22.5 && h < 67.5) return 'Northeast';
    if (h >= 67.5 && h < 112.5) return 'East';
    if (h >= 112.5 && h < 157.5) return 'Southeast';
    if (h >= 157.5 && h < 202.5) return 'South';
    if (h >= 202.5 && h < 247.5) return 'Southwest';
    if (h >= 247.5 && h < 292.5) return 'West';
    return 'Northwest';
  }
}
