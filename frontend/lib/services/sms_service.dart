import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class SmsService extends ChangeNotifier {
  bool _isSmsSupported = false;

  bool get isSmsSupported => _isSmsSupported;

  SmsService() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      _isSmsSupported = true;
      notifyListeners();
    } catch (e) {
      print('SMS initialization error: $e');
      _isSmsSupported = false;
    }
  }

  Future<bool> sendEmergencySMS({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Request permission
      final status = await Permission.sms.request();
      if (!status.isGranted) {
        print('SMS permission not granted');
        return false;
      }

      // Get user data
      final prefs = await SharedPreferences.getInstance();
      final userName = prefs.getString(AppConstants.PREF_USER_NAME) ?? 'User';

      String message = '''
🚨 EMERGENCY ALERT! 🚨

$userName may be in danger!

📍 Live Location:
https://maps.google.com/?q=$latitude,$longitude

🕐 Time: ${DateTime.now().toLocal().toString()}

⚠️ Please respond immediately!
''';

      // Get emergency contacts from backend
      // For now, use a sample number
      final contacts = ['+911234567890']; // Replace with actual contacts

      bool success = true;
      for (String phone in contacts) {
        try {
          await _sendSmsFallback(phone, message);
          print('SMS fallback launched for $phone');
        } catch (e) {
          print('Failed to send SMS to $phone: $e');
          success = false;
        }
      }

      return success;
    } catch (e) {
      print('Failed to send emergency SMS: $e');
      return false;
    }
  }

  Future<void> _sendSmsFallback(String phone, String message) async {
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      }
    } catch (e) {
      print('SMS fallback failed: $e');
    }
  }

  Future<bool> sendSms(String phone, String message) async {
    try {
      final status = await Permission.sms.request();
      if (!status.isGranted) {
        print('SMS permission not granted');
        return false;
      }

      await _sendSmsFallback(phone, message);
      return true;
    } catch (e) {
      print('Failed to send SMS: $e');
      return false;
    }
  }
}
