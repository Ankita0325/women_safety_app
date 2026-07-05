import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/emergency_service.dart';
import '../services/location_service.dart';
import '../services/voice_service.dart';
import '../widgets/emergency_button.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _isListening = false;
  String _voiceStatus = 'Tap microphone to start listening';

  @override
  Widget build(BuildContext context) {
    final locationService = Provider.of<LocationService>(context);
    final voiceService = Provider.of<VoiceService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.green : Colors.white,
            ),
            onPressed: () => _toggleVoiceListening(voiceService),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: EmergencyButton(),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.mic, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Voice Detection',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _voiceStatus,
                      style: const TextStyle(fontSize: 14),
                    ),
                    if (voiceService.recognizedText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          voiceService.recognizedText,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (voiceService
                          .checkForKeywords(voiceService.recognizedText))
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                '🚨 Emergency keyword detected!',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.location_on, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Location Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (locationService.currentPosition != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Latitude: ${locationService.currentPosition!.latitude}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            'Longitude: ${locationService.currentPosition!.longitude}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Location not available. Please enable GPS.',
                        style: TextStyle(fontSize: 14, color: Colors.orange),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleVoiceListening(VoiceService voiceService) async {
    if (_isListening) {
      await voiceService.stopListening();
      setState(() {
        _isListening = false;
        _voiceStatus = 'Voice detection stopped';
      });
    } else {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        await voiceService.startListening(
          onKeywordDetected: (keyword) {
            setState(() {
              _voiceStatus = '🚨 Emergency keyword detected: $keyword';
            });
            _showEmergencyDialog(context);
          },
          onResult: (text) {
            setState(() {
              _voiceStatus = 'Listening...';
            });
          },
        );
        setState(() {
          _isListening = true;
          _voiceStatus = 'Listening for emergency keywords...';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Microphone permission is required for voice detection'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showEmergencyDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '🚨 Emergency Detected!',
          style: TextStyle(color: Colors.red),
        ),
        content: const Text(
          'An emergency keyword was detected. Do you need help?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Help!'),
          ),
        ],
      ),
    );
  }
}
