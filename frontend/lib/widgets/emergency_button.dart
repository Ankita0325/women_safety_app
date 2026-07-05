import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/emergency_service.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart';
import '../services/sms_service.dart';

class EmergencyButton extends StatefulWidget {
  final double? size;
  final bool showLabel;
  final VoidCallback? onEmergencyTriggered;
  final VoidCallback? onEmergencyCancelled;
  final VoidCallback? onPressed;

  const EmergencyButton({
    super.key,
    this.size,
    this.showLabel = true,
    this.onEmergencyTriggered,
    this.onEmergencyCancelled,
    this.onPressed,
  });

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emergencyService = Provider.of<EmergencyService>(context);
    final authService = Provider.of<AuthService>(context);
    final locationService = Provider.of<LocationService>(context);
    final smsService = Provider.of<SmsService>(context);

    final isActive = emergencyService.isEmergencyActive;
    final size = widget.size ?? 120;

    return Column(
      children: [
        GestureDetector(
          onTap: _isLoading
              ? null
              : () => _handleEmergencyTap(
                    context,
                    emergencyService,
                    authService,
                    locationService,
                    smsService,
                  ),
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: isActive ? 1.0 : _pulseAnimation.value,
child: Container(
           width: size,
           height: size,
           decoration: BoxDecoration(
             shape: BoxShape.circle,
             gradient: isActive
                 ? LinearGradient(
                     colors: [Colors.grey, Colors.grey.shade700],
                     begin: Alignment.topLeft,
                     end: Alignment.bottomRight,
                   )
                 : const LinearGradient(
                     colors: [Colors.red, Colors.redAccent],
                     begin: Alignment.topLeft,
                     end: Alignment.bottomRight,
                   ),
                    boxShadow: [
                      BoxShadow(
                        color: isActive
                            ? Colors.grey.withOpacity(0.3)
                            : Colors.red.withOpacity(0.4),
                        blurRadius: 30,
                        spreadRadius: 5,
                        offset: const Offset(0, 8),
                      ),
                      if (!isActive)
                        BoxShadow(
                          color: Colors.red.withOpacity(0.2),
                          blurRadius: 50,
                          spreadRadius: 15,
                          offset: const Offset(0, 0),
                        ),
                    ],
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 3,
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isActive ? Icons.cancel : Icons.sos,
                              color: Colors.white,
                              size: size * 0.35,
                            ),
                            if (widget.showLabel) ...[
                              const SizedBox(height: 4),
                              Text(
                                isActive ? 'CANCEL' : 'SOS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: size * 0.12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ],
                        ),
                ),
              );
            },
          ),
        ),
        if (widget.showLabel && !isActive) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.red.withOpacity(0.2)),
            ),
            child: const Text(
              'TAP FOR EMERGENCY',
              style: TextStyle(
                color: Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
        if (isActive) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'EMERGENCY ACTIVE',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleEmergencyTap(
    BuildContext context,
    EmergencyService emergencyService,
    AuthService authService,
    LocationService locationService,
    SmsService smsService,
  ) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      if (emergencyService.isEmergencyActive) {
        // Cancel emergency
        if (emergencyService.currentEmergency != null) {
          await emergencyService.cancelEmergency(
            emergencyService.currentEmergency!.id!,
          );
          _showSnackBar(
            context,
            'Emergency cancelled',
            Colors.grey,
          );
          widget.onEmergencyCancelled?.call();
        }
      } else {
        // Trigger emergency
        final user = authService.currentUser;
        if (user == null) {
          _showSnackBar(
            context,
            'Please login first',
            Colors.orange,
          );
          return;
        }

        // Check location
        final position = await locationService.getCurrentPosition();
        if (position == null) {
          _showSnackBar(
            context,
            'Unable to get location. Please enable GPS.',
            Colors.orange,
          );
          return;
        }

// Trigger emergency
        await emergencyService.triggerEmergency(
          userId: user.uid,
        );

        // Send SOS messages
        await smsService.sendEmergencySMS(
          userId: user.uid,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        _showSnackBar(
          context,
          '🚨 EMERGENCY ACTIVATED! Help is on the way.',
          Colors.red,
        );
        widget.onEmergencyTriggered?.call();
      }
    } catch (e) {
      _showSnackBar(
        context,
        'Error: ${e.toString()}',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
