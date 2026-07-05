import 'dart:io';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class FlashlightService {
  static const MethodChannel _channel = MethodChannel('com.example.flashlight');

  static Future<void> turnOn() async {
    try {
      if (Platform.isAndroid) {
        await _channel.invokeMethod('turnOn');
      } else if (Platform.isIOS) {
        // iOS implementation using AVFoundation
        await _channel.invokeMethod('turnOn');
      }
    } catch (e) {
      print('Error turning on flashlight: $e');
    }
  }

  static Future<void> turnOff() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await _channel.invokeMethod('turnOff');
      }
    } catch (e) {
      print('Error turning off flashlight: $e');
    }
  }

  static Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod('isAvailable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }
}
