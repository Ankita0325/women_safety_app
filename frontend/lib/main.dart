import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Import services
import 'services/auth_service.dart';
import 'services/location_service.dart';
import 'services/emergency_service.dart';
import 'services/voice_service.dart';
import 'services/sms_service.dart';
import 'services/route_service.dart';

// Import screens
import 'screen/splash_screen.dart';
import 'screen/home_screen.dart';
import 'screen/login_screen.dart';
import 'screen/register_screen.dart';
import 'screen/emergency_screen.dart';
import 'screen/heatmap_screen.dart';
import 'screen/route_screen.dart';
import 'screen/community_screen.dart';
import 'screen/support_screen.dart';
import 'screen/profile_screen.dart';

// Import utils
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => EmergencyService()),
        ChangeNotifierProvider(create: (_) => VoiceService()),
        ChangeNotifierProvider(create: (_) => SmsService()),
        ChangeNotifierProvider(create: (_) => RouteService()),
      ],
      child: MaterialApp(
        title: 'Women Safety App',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/home': (context) => const HomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/emergency': (context) => const EmergencyScreen(),
          '/heatmap': (context) => const HeatmapScreen(),
          '/route': (context) => const RouteScreen(),
          '/community': (context) => const CommunityScreen(),
          '/support': (context) => const SupportScreen(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
  }
}
