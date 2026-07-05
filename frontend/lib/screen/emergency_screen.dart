import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/emergency_service.dart';
import '../services/location_service.dart';
import '../services/voice_service.dart';
import '../services/sms_service.dart';
import '../widgets/emergency_button.dart';
import '../widgets/loading_widget.dart';
import 'location_picker_screen.dart'; // Add this import

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _isListening = false;
  bool _isSendingSOS = false;
  String _voiceStatus = 'Tap microphone to start listening';
  String _sosStatus = 'Ready';
  bool _isFlashlightOn = false;
  int _emergencyCount = 0;
  bool _isDisposed = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();

    // Stop voice listening if active
    if (_isListening) {
      try {
        final voiceService = Provider.of<VoiceService>(context, listen: false);
        voiceService.stopListening();
      } catch (e) {
        // Ignore
      }
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Stop voice detection when app goes to background
      if (_isListening && !_isDisposed) {
        try {
          final voiceService =
              Provider.of<VoiceService>(context, listen: false);
          voiceService.stopListening();
          setState(() {
            _isListening = false;
            _voiceStatus = 'Voice detection paused';
          });
        } catch (e) {
          // Ignore
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationService = Provider.of<LocationService>(context);
    final voiceService = Provider.of<VoiceService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SOS Emergency',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                key: ValueKey(_isListening),
                color: _isListening ? Colors.green : Colors.white,
              ),
            ),
            onPressed: () => _toggleVoiceListening(voiceService),
            tooltip: 'Voice Detection',
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => _showEmergencyHistory(context),
            tooltip: 'Emergency History',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SOS Button
            Center(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isSendingSOS ? 1.0 : _pulseAnimation.value,
                        child: EmergencyButton(
                          onPressed:
                              _isSendingSOS ? null : () => _sendSOS(context),
                          size: 160,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  if (_isSendingSOS)
                    const LoadingWidget()
                  else
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _sosStatus,
                        key: ValueKey(_sosStatus),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _sosStatus.contains('Sent')
                              ? Colors.green
                              : _sosStatus.contains('Error')
                                  ? Colors.red
                                  : Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Emergency Actions
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.flash_on, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Quick Actions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.phone,
                            label: 'Call 100',
                            color: Colors.blue,
                            onTap: () => _makeEmergencyCall('100'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.share_location,
                            label: 'Share Location',
                            color: Colors.green,
                            onTap: () => _shareLocation(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.message,
                            label: 'SOS Alert',
                            color: Colors.red,
                            onTap: () => _sendSOS(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickAction(
                            icon: _isFlashlightOn
                                ? Icons.flash_off
                                : Icons.flash_on,
                            label: _isFlashlightOn ? 'Flash Off' : 'Flash On',
                            color:
                                _isFlashlightOn ? Colors.grey : Colors.orange,
                            onTap: _toggleFlashlight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.pin_drop,
                            label: 'Pick Location',
                            color: Colors.purple,
                            onTap: _openLocationPicker,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickAction(
                            icon: Icons.route,
                            label: 'Safe Route',
                            color: Colors.teal,
                            onTap: () {
                              Navigator.pushNamed(context, '/route');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Voice Detection Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_off,
                            key: ValueKey(_isListening),
                            color: _isListening ? Colors.green : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Voice Detection',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _isListening
                                ? Colors.green.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _isListening
                                  ? Colors.green.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isListening)
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (_isListening) const SizedBox(width: 4),
                              Text(
                                _isListening ? 'Listening' : 'Stopped',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      _isListening ? Colors.green : Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _voiceStatus,
                      style: TextStyle(
                        fontSize: 14,
                        color: _voiceStatus.contains('Emergency')
                            ? Colors.red
                            : Colors.grey.shade700,
                      ),
                    ),
                    if (voiceService.recognizedText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.text_fields,
                                size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                voiceService.recognizedText,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (voiceService
                          .checkForKeywords(voiceService.recognizedText))
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade300),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Row(
                            children: const [
                              Icon(Icons.warning, color: Colors.red),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '🚨 Emergency keyword detected! Auto-SOS will be triggered.',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (!_isListening && voiceService.recognizedText.isEmpty)
                      const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'Tap the microphone icon above to start voice detection',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Location Status Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.green),
                        const SizedBox(width: 8),
                        const Text(
                          'Location Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: () => _refreshLocation(context),
                          tooltip: 'Refresh Location',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (locationService.currentPosition != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.pin_drop,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Lat: ${locationService.currentPosition!.latitude.toStringAsFixed(6)}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.pin_drop,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Lng: ${locationService.currentPosition!.longitude.toStringAsFixed(6)}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.green.withOpacity(0.2),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                            size: 14,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Location active',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Colors.blue.withOpacity(0.2),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.gps_fixed,
                                            color: Colors.blue,
                                            size: 14,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'GPS enabled',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning, color: Colors.orange),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Location not available. Please enable GPS.',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _refreshLocation(context),
                                icon: const Icon(Icons.gps_fixed),
                                label: const Text('Enable Location'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendSOS(BuildContext context) async {
    if (_isSendingSOS || !mounted) return;

    setState(() {
      _isSendingSOS = true;
      _sosStatus = 'Sending SOS...';
    });

    try {
      final smsService = Provider.of<SmsService>(context, listen: false);
      final locationService =
          Provider.of<LocationService>(context, listen: false);

      final position = await locationService.getCurrentPosition();
      if (position == null) {
        throw Exception('Location not available. Please enable GPS.');
      }

      final success = await smsService.sendEmergencySMS(
        userId: 'emergency',
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (mounted) {
        setState(() {
          _sosStatus = success
              ? '✅ SOS Alert Sent Successfully!'
              : '❌ Failed to send SOS';
          _emergencyCount++;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sosStatus = '❌ Error: ${e.toString()}';
        });
        _showErrorDialog(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingSOS = false;
        });
      }
    }
  }

  Future<void> _toggleVoiceListening(VoiceService voiceService) async {
    if (!mounted) return;

    if (_isListening) {
      await voiceService.stopListening();
      if (mounted) {
        setState(() {
          _isListening = false;
          _voiceStatus = 'Voice detection stopped';
        });
      }
    } else {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        try {
          await voiceService.startListening(
            onKeywordDetected: (keyword) {
              if (mounted) {
                setState(() {
                  _voiceStatus = '🚨 Emergency keyword detected: $keyword';
                });
                _sendSOS(context);
              }
            },
            onResult: (text) {
              if (mounted) {
                setState(() {
                  _voiceStatus = 'Listening...';
                });
              }
            },
          );
          if (mounted) {
            setState(() {
              _isListening = true;
              _voiceStatus = 'Listening for emergency keywords...';
            });
          }
        } catch (e) {
          if (mounted) {
            _showSnackBar(
              'Error starting voice detection: ${e.toString()}',
              Colors.red,
            );
          }
        }
      } else {
        if (mounted) {
          _showSnackBar(
            'Microphone permission is required for voice detection',
            Colors.red,
          );
        }
      }
    }
  }

  void _makeEmergencyCall(String number) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: number);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          _showSnackBar('Cannot make call to $number', Colors.red);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error making call', Colors.red);
      }
    }
  }

  Future<void> _shareLocation(BuildContext context) async {
    if (!mounted) return;

    try {
      final locationService =
          Provider.of<LocationService>(context, listen: false);
      final position = await locationService.getCurrentPosition();

      if (position != null) {
        final message = '🚨 I need help! My current location:\n'
            'https://www.google.com/maps?q=${position.latitude},${position.longitude}';

        final shareUri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(shareUri)) {
          await launchUrl(shareUri);
        } else {
          if (mounted) {
            _showSnackBar('Unable to share location', Colors.orange);
          }
        }
      } else {
        if (mounted) {
          _showSnackBar('Location not available', Colors.orange);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error sharing location: ${e.toString()}', Colors.red);
      }
    }
  }

  void _toggleFlashlight() {
    setState(() {
      _isFlashlightOn = !_isFlashlightOn;
    });
    if (mounted) {
      _showSnackBar(
        _isFlashlightOn ? '🔦 Flashlight turned on' : 'Flashlight turned off',
        _isFlashlightOn ? Colors.orange : Colors.grey,
      );
    }
  }

  void _openLocationPicker() async {
    if (!mounted) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          onLocationSelected: (lat, lng, address) {
            if (mounted) {
              _showSnackBar(
                '📍 Location selected: ${address.substring(0, address.length > 30 ? 30 : address.length)}...',
                Colors.green,
              );
              // You can use this location for route or share
              print('Selected Location: $lat, $lng');
              print('Address: $address');
            }
          },
        ),
      ),
    );
  }

  Future<void> _refreshLocation(BuildContext context) async {
    if (!mounted) return;

    try {
      final locationService =
          Provider.of<LocationService>(context, listen: false);
      final position = await locationService.getCurrentPosition();
      if (mounted) {
        setState(() {});
        if (position != null) {
          _showSnackBar('📍 Location updated successfully', Colors.green);
        } else {
          _showSnackBar(
            'Unable to get location. Please enable GPS.',
            Colors.orange,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error updating location: ${e.toString()}', Colors.red);
      }
    }
  }

  void _showEmergencyDialog(BuildContext context, int contactsCount) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: const [
            Icon(Icons.sos, color: Colors.red, size: 30),
            SizedBox(width: 8),
            Text(
              'SOS Alert Sent!',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$contactsCount emergency contacts have been notified with your current location.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Stay safe and stay calm. Help is on the way!',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String error) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.red),
        ),
        content: Text('Failed to send SOS: $error'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyHistory(BuildContext context) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.history, color: Colors.red),
                SizedBox(width: 8),
                Text(
                  'Emergency History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _emergencyCount > 0
                  ? ListView.builder(
                      itemCount: _emergencyCount,
                      itemBuilder: (context, index) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const Icon(Icons.sos, color: Colors.red),
                            title:
                                Text('Emergency #${_emergencyCount - index}'),
                            subtitle: Text(
                              'Triggered at ${DateTime.now().subtract(Duration(hours: index)).toString().substring(0, 16)}',
                            ),
                            trailing: const Icon(Icons.check_circle,
                                color: Colors.green),
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.history,
                            size: 64,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No emergency history',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 16,
                            ),
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

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
