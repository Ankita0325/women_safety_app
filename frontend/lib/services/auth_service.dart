import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';
import '../utils/constants.dart';

class AuthService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _error;
  bool _useMockBackend = true; // Set to false when backend is ready

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _currentUser != null;
  bool get useMockBackend => _useMockBackend;

  bool _isInitialized = false;

  AuthService() {
    _init();
  }

  Future<void> waitForInit() async {
    while (!_isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.PREF_AUTH_TOKEN);

      if (_useMockBackend) {
        // Check if user is already logged in from shared preferences
        final isLoggedIn =
            prefs.getBool(AppConstants.PREF_IS_LOGGED_IN) ?? false;
        if (isLoggedIn) {
          final userId = prefs.getString(AppConstants.PREF_USER_ID) ?? '';
          final userName =
              prefs.getString(AppConstants.PREF_USER_NAME) ?? 'User';
          final userEmail = prefs.getString(AppConstants.PREF_USER_EMAIL) ?? '';
          final userPhone = prefs.getString(AppConstants.PREF_USER_PHONE) ?? '';

          if (userId.isNotEmpty) {
            _currentUser = UserModel(
              uid: userId,
              email: userEmail,
              name: userName,
              phone: userPhone,
              role: 'user',
              emergencyContacts: [],
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              isVerified: false,
            );
          }
        }
      } else if (token != null && token.isNotEmpty) {
        await _apiService.setAuthToken(token);
        await _loadUser();
      }
    } catch (e) {
      print('Error initializing AuthService: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadUser() async {
    try {
      final response = await _apiService.get('${AppConstants.API_AUTH}/me');
      _currentUser = UserModel.fromJson(response);
      notifyListeners();
    } catch (e) {
      print('Error loading user: $e');
      // If token is invalid, clear it
      if (e.toString().contains('401') || e.toString().contains('403')) {
        await logout();
      }
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
      if (_useMockBackend) {
        // Mock registration - bypass backend
        await Future.delayed(const Duration(seconds: 1));

        // Validate input
        if (email.isEmpty ||
            password.isEmpty ||
            name.isEmpty ||
            phone.isEmpty) {
          _error = 'All fields are required';
          _isLoading = false;
          notifyListeners();
          return;
        }

        if (password.length < 6) {
          _error = 'Password must be at least 6 characters';
          _isLoading = false;
          notifyListeners();
          return;
        }

        final now = DateTime.now();

        // Generate a mock user
        _currentUser = UserModel(
          uid: 'mock_${DateTime.now().millisecondsSinceEpoch}',
          email: email,
          name: name,
          phone: phone,
          role: 'user',
          emergencyContacts: [
            EmergencyContact(
              name: 'Police',
              phone: '112',
              relation: 'Emergency',
              isPrimary: true,
            ),
            EmergencyContact(
              name: 'Women Helpline',
              phone: '1091',
              relation: 'Emergency',
              isPrimary: false,
            ),
          ],
          createdAt: now,
          updatedAt: now,
          isVerified: false,
        );

        // Save to shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.PREF_AUTH_TOKEN,
            'mock_token_${DateTime.now().millisecondsSinceEpoch}');
        await prefs.setString(AppConstants.PREF_USER_ID, _currentUser!.uid);
        await prefs.setString(AppConstants.PREF_USER_NAME, _currentUser!.name);
        await prefs.setString(
            AppConstants.PREF_USER_EMAIL, _currentUser!.email);
        await prefs.setString(
            AppConstants.PREF_USER_PHONE, _currentUser!.phone);
        await prefs.setBool(AppConstants.PREF_IS_LOGGED_IN, true);

        notifyListeners();
        print('✅ Mock registration successful for: $email');
        return;
      }

      // Real backend registration
      final response = await _apiService.post(
        '${AppConstants.API_AUTH}/register',
        body: {
          'email': email,
          'password': password,
          'name': name,
          'phone': phone,
        },
      );

      if (response.containsKey('token') && response['token'] != null) {
        await _apiService.setAuthToken(response['token']);
      }

      if (response.containsKey('user')) {
        _currentUser = UserModel.fromJson(response['user']);
      } else {
        _currentUser = UserModel.fromJson(response);
      }

      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      if (response.containsKey('token') && response['token'] != null) {
        await prefs.setString(AppConstants.PREF_AUTH_TOKEN, response['token']);
      }
      if (_currentUser != null) {
        await prefs.setString(AppConstants.PREF_USER_ID, _currentUser!.uid);
        await prefs.setString(AppConstants.PREF_USER_NAME, _currentUser!.name);
        await prefs.setString(
            AppConstants.PREF_USER_EMAIL, _currentUser!.email);
        await prefs.setString(
            AppConstants.PREF_USER_PHONE, _currentUser!.phone);
        await prefs.setBool(AppConstants.PREF_IS_LOGGED_IN, true);
      }

      print('✅ Registration successful for: $email');
    } catch (e) {
      _error = _extractErrorMessage(e);
      print('❌ Registration error: $e');
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
      if (_useMockBackend) {
        // Mock login - bypass backend
        await Future.delayed(const Duration(seconds: 1));

        // Validate credentials
        if (email.isEmpty || password.isEmpty) {
          _error = 'Please enter email and password';
          _isLoading = false;
          notifyListeners();
          return;
        }

        if (password.length < 6) {
          _error = 'Password must be at least 6 characters';
          _isLoading = false;
          notifyListeners();
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        final savedEmail = prefs.getString(AppConstants.PREF_USER_EMAIL);

        final now = DateTime.now();

        if (savedEmail != null && savedEmail.isNotEmpty) {
          // User exists, load from prefs
          final userId =
              prefs.getString(AppConstants.PREF_USER_ID) ?? 'mock_user_123';
          final userName =
              prefs.getString(AppConstants.PREF_USER_NAME) ?? 'User';
          final userPhone = prefs.getString(AppConstants.PREF_USER_PHONE) ?? '';

          _currentUser = UserModel(
            uid: userId,
            email: savedEmail,
            name: userName,
            phone: userPhone,
            role: 'user',
            emergencyContacts: [
              EmergencyContact(
                name: 'Police',
                phone: '112',
                relation: 'Emergency',
                isPrimary: true,
              ),
              EmergencyContact(
                name: 'Women Helpline',
                phone: '1091',
                relation: 'Emergency',
                isPrimary: false,
              ),
            ],
            createdAt: now,
            updatedAt: now,
            isVerified: false,
          );

          // Update login status
          await prefs.setBool(AppConstants.PREF_IS_LOGGED_IN, true);
        } else {
          // Create new mock user (for first-time login)
          _currentUser = UserModel(
            uid: 'mock_${DateTime.now().millisecondsSinceEpoch}',
            email: email,
            name: email.split('@')[0], // Use email prefix as name
            phone: '1234567890',
            role: 'user',
            emergencyContacts: [
              EmergencyContact(
                name: 'Police',
                phone: '112',
                relation: 'Emergency',
                isPrimary: true,
              ),
              EmergencyContact(
                name: 'Women Helpline',
                phone: '1091',
                relation: 'Emergency',
                isPrimary: false,
              ),
            ],
            createdAt: now,
            updatedAt: now,
            isVerified: false,
          );

          // Save to prefs
          await prefs.setString(AppConstants.PREF_AUTH_TOKEN,
              'mock_token_${DateTime.now().millisecondsSinceEpoch}');
          await prefs.setString(AppConstants.PREF_USER_ID, _currentUser!.uid);
          await prefs.setString(
              AppConstants.PREF_USER_NAME, _currentUser!.name);
          await prefs.setString(
              AppConstants.PREF_USER_EMAIL, _currentUser!.email);
          await prefs.setString(
              AppConstants.PREF_USER_PHONE, _currentUser!.phone);
          await prefs.setBool(AppConstants.PREF_IS_LOGGED_IN, true);
          await prefs.setString('mock_password', password); // Store for demo
        }

        notifyListeners();
        print('✅ Mock login successful for: $email');
        return;
      }

      // Real backend login
      final response = await _apiService.post(
        '${AppConstants.API_AUTH}/login',
        body: {'email': email, 'password': password},
      );

      if (response.containsKey('token') && response['token'] != null) {
        await _apiService.setAuthToken(response['token']);
      }

      if (response.containsKey('user')) {
        _currentUser = UserModel.fromJson(response['user']);
      } else {
        _currentUser = UserModel.fromJson(response);
      }

      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      if (response.containsKey('token') && response['token'] != null) {
        await prefs.setString(AppConstants.PREF_AUTH_TOKEN, response['token']);
      }
      if (_currentUser != null) {
        await prefs.setString(AppConstants.PREF_USER_ID, _currentUser!.uid);
        await prefs.setString(AppConstants.PREF_USER_NAME, _currentUser!.name);
        await prefs.setString(
            AppConstants.PREF_USER_EMAIL, _currentUser!.email);
        await prefs.setString(
            AppConstants.PREF_USER_PHONE, _currentUser!.phone);
        await prefs.setBool(AppConstants.PREF_IS_LOGGED_IN, true);
      }

      print('✅ Login successful for: $email');
    } catch (e) {
      _error = _extractErrorMessage(e);
      print('❌ Login error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_useMockBackend) {
        // Mock logout
        await Future.delayed(const Duration(milliseconds: 500));
        _currentUser = null;

        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(AppConstants.PREF_AUTH_TOKEN);
        await prefs.remove(AppConstants.PREF_USER_ID);
        await prefs.remove(AppConstants.PREF_USER_NAME);
        await prefs.remove(AppConstants.PREF_USER_EMAIL);
        await prefs.remove(AppConstants.PREF_USER_PHONE);
        await prefs.remove(AppConstants.PREF_IS_LOGGED_IN);
        await prefs.remove('mock_password'); // Remove stored password

        notifyListeners();
        print('✅ Mock logout successful');
        return;
      }

      // Real backend logout
      await _apiService.clearAuthToken();
      _currentUser = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.PREF_AUTH_TOKEN);
      await prefs.remove(AppConstants.PREF_USER_ID);
      await prefs.remove(AppConstants.PREF_USER_NAME);
      await prefs.remove(AppConstants.PREF_USER_EMAIL);
      await prefs.remove(AppConstants.PREF_USER_PHONE);
      await prefs.remove(AppConstants.PREF_IS_LOGGED_IN);

      print('✅ Logout successful');
    } catch (e) {
      print('❌ Logout error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Helper method to switch between mock and real backend
  void toggleBackendMode(bool useMock) {
    _useMockBackend = useMock;
    notifyListeners();
    print('🔄 Backend mode switched to: ${useMock ? "Mock" : "Real"}');
  }

  // Method to check if user is logged in (for splash screen)
  Future<bool> isUserLoggedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(AppConstants.PREF_IS_LOGGED_IN) ?? false;
    } catch (e) {
      print('Error checking login status: $e');
      return false;
    }
  }

  // Helper method to check if user has completed profile
  bool get hasProfileComplete {
    if (_currentUser == null) return false;
    return _currentUser!.name.isNotEmpty &&
        _currentUser!.email.isNotEmpty &&
        _currentUser!.phone.isNotEmpty;
  }

  // Get emergency contacts
  List<EmergencyContact> getEmergencyContacts() {
    return _currentUser?.emergencyContacts ?? [];
  }

  // Add emergency contact
  Future<void> addEmergencyContact({
    required String name,
    required String phone,
    required String relation,
    bool isPrimary = false,
  }) async {
    if (_currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final newContact = EmergencyContact(
        name: name,
        phone: phone,
        relation: relation,
        isPrimary: isPrimary,
      );

      if (_useMockBackend) {
        // Mock add contact
        await Future.delayed(const Duration(milliseconds: 500));

        // If this is primary, set all others to non-primary
        List<EmergencyContact> updatedContacts =
            List.from(_currentUser!.emergencyContacts);
        if (isPrimary) {
          updatedContacts = updatedContacts.map((contact) {
            return EmergencyContact(
              name: contact.name,
              phone: contact.phone,
              relation: contact.relation,
              isPrimary: false,
            );
          }).toList();
        }

        updatedContacts.add(newContact);

        _currentUser = UserModel(
          uid: _currentUser!.uid,
          email: _currentUser!.email,
          name: _currentUser!.name,
          phone: _currentUser!.phone,
          role: _currentUser!.role,
          emergencyContacts: updatedContacts,
          createdAt: _currentUser!.createdAt,
          updatedAt: DateTime.now(),
          isVerified: _currentUser!.isVerified,
        );

        notifyListeners();
        print('✅ Emergency contact added: $name');
        return;
      }

      // Real backend add contact
      final response = await _apiService.post(
        '${AppConstants.API_EMERGENCY}/contacts',
        body: {
          'name': name,
          'phone': phone,
          'relation': relation,
          'is_primary': isPrimary,
        },
      );

      _currentUser = UserModel.fromJson(response);
      notifyListeners();
      print('✅ Emergency contact added: $name');
    } catch (e) {
      _error = _extractErrorMessage(e);
      print('❌ Error adding emergency contact: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Remove emergency contact
  Future<void> removeEmergencyContact(String phone) async {
    if (_currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      if (_useMockBackend) {
        // Mock remove contact
        await Future.delayed(const Duration(milliseconds: 500));

        final updatedContacts = _currentUser!.emergencyContacts
            .where((contact) => contact.phone != phone)
            .toList();

        _currentUser = UserModel(
          uid: _currentUser!.uid,
          email: _currentUser!.email,
          name: _currentUser!.name,
          phone: _currentUser!.phone,
          role: _currentUser!.role,
          emergencyContacts: updatedContacts,
          createdAt: _currentUser!.createdAt,
          updatedAt: DateTime.now(),
          isVerified: _currentUser!.isVerified,
        );

        notifyListeners();
        print('✅ Emergency contact removed: $phone');
        return;
      }

      // Real backend remove contact
      final response = await _apiService.delete(
        '${AppConstants.API_EMERGENCY}/contacts/$phone',
      );

      _currentUser = UserModel.fromJson(response);
      notifyListeners();
      print('✅ Emergency contact removed: $phone');
    } catch (e) {
      _error = _extractErrorMessage(e);
      print('❌ Error removing emergency contact: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    String? name,
    String? email,
    String? phone,
  }) async {
    if (_currentUser == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      if (_useMockBackend) {
        // Mock update
        await Future.delayed(const Duration(seconds: 1));

        _currentUser = UserModel(
          uid: _currentUser!.uid,
          email: email ?? _currentUser!.email,
          name: name ?? _currentUser!.name,
          phone: phone ?? _currentUser!.phone,
          role: _currentUser!.role,
          emergencyContacts: _currentUser!.emergencyContacts,
          createdAt: _currentUser!.createdAt,
          updatedAt: DateTime.now(),
          isVerified: _currentUser!.isVerified,
        );

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.PREF_USER_NAME, _currentUser!.name);
        await prefs.setString(
            AppConstants.PREF_USER_EMAIL, _currentUser!.email);
        await prefs.setString(
            AppConstants.PREF_USER_PHONE, _currentUser!.phone);

        notifyListeners();
        print('✅ Profile updated successfully');
        return;
      }

      // Real backend update
      final response = await _apiService.put(
        '${AppConstants.API_AUTH}/profile',
        body: {
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
        },
      );

      _currentUser = UserModel.fromJson(response);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.PREF_USER_NAME, _currentUser!.name);
      await prefs.setString(AppConstants.PREF_USER_EMAIL, _currentUser!.email);
      await prefs.setString(AppConstants.PREF_USER_PHONE, _currentUser!.phone);

      notifyListeners();
      print('✅ Profile updated successfully');
    } catch (e) {
      _error = _extractErrorMessage(e);
      print('❌ Profile update error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Extract meaningful error message
  String _extractErrorMessage(dynamic error) {
    String errorString = error.toString();

    if (errorString.contains('SocketException')) {
      return 'Unable to connect to server. Please check your internet connection.';
    } else if (errorString.contains('401')) {
      return 'Invalid email or password. Please try again.';
    } else if (errorString.contains('403')) {
      return 'Access denied. Please login again.';
    } else if (errorString.contains('409')) {
      return 'This email is already registered. Please use a different email or login.';
    } else if (errorString.contains('422')) {
      return 'Invalid data. Please check your input.';
    } else if (errorString.contains('500')) {
      return 'Server error. Please try again later.';
    } else if (errorString.contains('timeout')) {
      return 'Connection timeout. Please check your internet connection.';
    }

    // If error contains 'message' field in JSON
    try {
      if (errorString.contains('message')) {
        final start = errorString.indexOf('message') + 10;
        final end = errorString.indexOf('}', start);
        if (start < end) {
          return errorString.substring(start, end).replaceAll('"', '');
        }
      }
    } catch (e) {
      // Fallback to default message
    }

    return 'An unexpected error occurred. Please try again.';
  }

  @override
  void dispose() {
    // Clean up if needed
    super.dispose();
  }
}
