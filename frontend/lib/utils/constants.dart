class AppConstants {
  // API URLs
  static const String API_BASE_URL = 'http://localhost:8000/api/v1';
  static const String API_AUTH = '$API_BASE_URL/auth';
  static const String API_EMERGENCY = '$API_BASE_URL/emergency';
  static const String API_REPORTS = '$API_BASE_URL/reports';
  static const String API_ROUTES = '$API_BASE_URL/routes';

  // Emergency Keywords
  static const List<String> EMERGENCY_KEYWORDS = [
    'help',
    'sos',
    'save me',
    'bachao',
    'emergency',
    'danger',
    'attack',
    'kidnap',
    'follow',
    'stalk',
    'help me',
    'save',
    'police',
  ];

  // Shared Preferences Keys
  static const String PREF_USER_ID = 'user_id';
  static const String PREF_USER_NAME = 'user_name';
  static const String PREF_USER_EMAIL = 'user_email';
  static const String PREF_USER_PHONE = 'user_phone';
  static const String PREF_AUTH_TOKEN = 'auth_token';
  static const String PREF_IS_LOGGED_IN = 'is_logged_in';
}
