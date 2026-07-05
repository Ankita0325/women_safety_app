import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  bool _isServiceEnabled = false;
  LocationPermission? _permission;

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  bool get isServiceEnabled => _isServiceEnabled;

  Future<void> initialize() async {
    await _checkLocationService();
    await _requestPermission();
    await _getCurrentLocation();
  }

  Future<void> _checkLocationService() async {
    _isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    notifyListeners();
  }

  Future<void> _requestPermission() async {
    final status = await Permission.location.request();
    _permission = await Geolocator.checkPermission();
    notifyListeners();
  }

  Future<void> _getCurrentLocation() async {
    if (!_isServiceEnabled) {
      await _checkLocationService();
      if (!_isServiceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      notifyListeners();
    } catch (e) {
      print('Error getting location: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLocation() async {
    await _getCurrentLocation();
  }

  Future<Position?> getCurrentLocation() async {
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
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) /
        1000; // Convert to km
  }

  Future<bool> isLocationEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
