import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';

class VoiceService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';
  bool _isAvailable = false;

  bool get isListening => _isListening;
  String get recognizedText => _recognizedText;
  bool get isAvailable => _isAvailable;

  Future<void> initialize() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        _isAvailable = await _speech.initialize(
          onStatus: (status) {
            print('Speech status: $status');
          },
          onError: (error) {
            print('Speech error: $error');
            _isListening = false;
            notifyListeners();
          },
        );
      }
      notifyListeners();
    } catch (e) {
      print('Voice service initialization error: $e');
      _isAvailable = false;
    }
  }

  Future<void> startListening({
    Function(String)? onKeywordDetected,
    Function(String)? onResult,
  }) async {
    if (!_isAvailable) {
      await initialize();
    }

    if (_isListening) {
      _speech.stop();
      _isListening = false;
    }

    _isListening = true;
    _recognizedText = '';
    notifyListeners();

    _speech.listen(
      onResult: (result) {
        _recognizedText = result.recognizedWords;
        notifyListeners();

        if (onResult != null) {
          onResult(_recognizedText);
        }

        // Check for emergency keywords
        final lowerText = _recognizedText.toLowerCase();
        for (String keyword in AppConstants.EMERGENCY_KEYWORDS) {
          if (lowerText.contains(keyword)) {
            if (onKeywordDetected != null) {
              onKeywordDetected(keyword);
            }
            // Vibrate for feedback
            break;
          }
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 5),
      partialResults: true,
      localeId: 'en_US',
      onSoundLevelChange: (level) {
        // Handle sound level changes
      },
    );
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
    }
  }

  void clearRecognizedText() {
    _recognizedText = '';
    notifyListeners();
  }

  bool checkForKeywords(String text) {
    final lowerText = text.toLowerCase();
    for (String keyword in AppConstants.EMERGENCY_KEYWORDS) {
      if (lowerText.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  List<String> getDetectedKeywords(String text) {
    final lowerText = text.toLowerCase();
    List<String> detected = [];
    for (String keyword in AppConstants.EMERGENCY_KEYWORDS) {
      if (lowerText.contains(keyword)) {
        detected.add(keyword);
      }
    }
    return detected;
  }
}
