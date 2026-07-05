import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import '../models/emergency_model.dart';
import 'api_service.dart';
import 'location_service.dart';
import 'sms_service.dart';

class EmergencyService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final SmsService _smsService = SmsService();

  bool _isEmergencyActive = false;
  Emergency? _currentEmergency;
  List<Emergency> _emergencyHistory = [];

  bool get isEmergencyActive => _isEmergencyActive;
  Emergency? get currentEmergency => _currentEmergency;
  List<Emergency> get emergencyHistory => _emergencyHistory;

  Future<void> triggerEmergency({
    required String userId,
    String? incidentType,
    String? description,
  }) async {
    _isEmergencyActive = true;
    notifyListeners();

    try {
      // Get current location
      final position = await _locationService.getCurrentPosition();
      if (position == null) {
        throw Exception('Unable to get location');
      }

      // Trigger emergency on backend
      final response = await _apiService.post(
        '/emergency/trigger',
        body: {
          'user_id': userId,
          'latitude': position.latitude,
          'longitude': position.longitude,
          'incident_type': incidentType ?? 'general',
          'description': description ?? 'SOS alert triggered',
        },
      );

      _currentEmergency = Emergency.fromJson(response);

      // Vibrate device
      Vibration.vibrate(pattern: [500, 200, 500, 200, 500]);

      // Send emergency SMS
      await _smsService.sendEmergencySMS(
        userId: userId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      notifyListeners();
    } catch (e) {
      print('Emergency trigger error: $e');
      _isEmergencyActive = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> cancelEmergency(String emergencyId) async {
    try {
      await _apiService.put(
        '/emergency/update-status/$emergencyId',
        body: {'status': 'cancelled'},
      );

      _isEmergencyActive = false;
      _currentEmergency = null;
      notifyListeners();

      // Stop vibration
      Vibration.cancel();
    } catch (e) {
      print('Cancel emergency error: $e');
    }
  }

  Future<void> resolveEmergency(String emergencyId) async {
    try {
      await _apiService.put(
        '/emergency/update-status/$emergencyId',
        body: {'status': 'resolved'},
      );

      _isEmergencyActive = false;
      _currentEmergency = null;
      notifyListeners();
    } catch (e) {
      print('Resolve emergency error: $e');
    }
  }

  Future<void> loadEmergencyHistory(String userId) async {
    try {
      final response = await _apiService.get('/emergency/history/$userId');
      _emergencyHistory = (response['history'] as List)
          .map((e) => Emergency.fromJson(e))
          .toList();
      notifyListeners();
    } catch (e) {
      print('Load emergency history error: $e');
    }
  }

  Future<Map<String, dynamic>> getNearbyServices(String userId) async {
    try {
      final response = await _apiService.get(
        '/emergency/nearby-services/$userId',
      );
      return response;
    } catch (e) {
      print('Get nearby services error: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> detectVoiceEmergency(String audioText) async {
    try {
      final response = await _apiService.post(
        '/emergency/voice-detection',
        body: {'audio_text': audioText},
      );
      return response;
    } catch (e) {
      print('Voice detection error: $e');
      return {'emergency_detected': false, 'keywords_detected': []};
    }
  }
}
