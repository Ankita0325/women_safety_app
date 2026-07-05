import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/emergency_service.dart';
import '../services/auth_service.dart';

class EmergencyButton extends StatelessWidget {
  const EmergencyButton({super.key});

  @override
  Widget build(BuildContext context) {
    final emergencyService = Provider.of<EmergencyService>(context);
    final authService = Provider.of<AuthService>(context);

    return GestureDetector(
      onTap: () async {
        if (emergencyService.isEmergencyActive) {
          // Cancel emergency
          if (emergencyService.currentEmergency != null) {
            await emergencyService.cancelEmergency(
              emergencyService.currentEmergency!.id!,
            );
          }
        } else {
          // Trigger emergency
          try {
            await emergencyService.triggerEmergency(
              userId: authService.currentUser!.uid,
            );
            // Show success message
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🚨 Emergency triggered! Help is on the way.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error triggering emergency: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      },
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: emergencyService.isEmergencyActive
                ? [Colors.grey, Colors.grey.shade700]
                : [Colors.red, Colors.red.shade700],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              emergencyService.isEmergencyActive ? Icons.cancel : Icons.sos,
              color: Colors.white,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(
              emergencyService.isEmergencyActive
                  ? 'CANCEL EMERGENCY'
                  : 'SOS EMERGENCY',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
