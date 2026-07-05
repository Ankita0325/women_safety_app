import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import '../utils/constants.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        await _apiService.setAuthToken(token);
        await _loadUser();
      }
    } catch (e) {
      print('Error loading user: $e');
    }
  }

  Future<void> _loadUser() async {
    try {
      final response = await _apiService.get('/auth/me');
      _currentUser = UserModel.fromJson(response);
      notifyListeners();
    } catch (e) {
      print('Error loading user: $e');
    }
  }

  Future<void> register({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/auth/register',
        body: {
          'email': email,
          'password': password,
          'name': name,
          'phone': phone,
        },
      );

      if (response.containsKey('token')) {
        await _apiService.setAuthToken(response['token']);
      }

      _currentUser = UserModel.fromJson(response['user']);
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.PREF_USER_ID, _currentUser!.uid);
      await prefs.setString(AppConstants.PREF_USER_NAME, _currentUser!.name);
      await prefs.setString(AppConstants.PREF_USER_EMAIL, _currentUser!.email);
      await prefs.setString(AppConstants.PREF_USER_PHONE, _currentUser!.phone);
      await prefs.setBool(AppConstants.PREF_IS_LOGGED_IN, true);
    } catch (e) {
      _error = e.toString();
      print('Registration error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      );

      if (response.containsKey('token')) {
        await _apiService.setAuthToken(response['token']);
      }

      _currentUser = UserModel.fromJson(response['user']);
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.PREF_USER_ID, _currentUser!.uid);
      await prefs.setString(AppConstants.PREF_USER_NAME, _currentUser!.name);
      await prefs.setString(AppConstants.PREF_USER_EMAIL, _currentUser!.email);
      await prefs.setString(AppConstants.PREF_USER_PHONE, _currentUser!.phone);
      await prefs.setBool(AppConstants.PREF_IS_LOGGED_IN, true);
    } catch (e) {
      _error = e.toString();
      print('Login error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _apiService.clearAuthToken();
      _currentUser = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.PREF_USER_ID);
      await prefs.remove(AppConstants.PREF_USER_NAME);
      await prefs.remove(AppConstants.PREF_USER_EMAIL);
      await prefs.remove(AppConstants.PREF_USER_PHONE);
      await prefs.remove(AppConstants.PREF_IS_LOGGED_IN);
    } catch (e) {
      print('Logout error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
