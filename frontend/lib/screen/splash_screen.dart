// lib/screen/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.waitForInit();
      await Future.delayed(const Duration(seconds: 2));

      // Check if user has seen onboarding FIRST
      final prefs = await SharedPreferences.getInstance();
      bool hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

      if (mounted) {
        if (!hasSeenOnboarding) {
          // First time user - show onboarding FIRST
          Navigator.pushReplacementNamed(context, '/onboarding');
        } else if (authService.isAuthenticated) {
          // User has seen onboarding and is logged in
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          // User has seen onboarding but not logged in
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } catch (e) {
      // If anything fails, navigate to onboarding
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E293B),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.security_rounded,
                size: 80,
                color: Color(0xFF7C3AED),
              ),
              const SizedBox(height: 20),
              const Text(
                'Women Safety',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your Safety Matters',
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}