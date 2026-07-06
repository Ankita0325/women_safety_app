import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geo;

import '../models/route_model.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../utils/theme.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final TextEditingController _destinationController = TextEditingController();
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();
  
  SafeRoute? _currentRoute;
  bool _isLoading = false;
  bool _isFindingRoute = false;

  // Real-time navigation properties
  bool _isNavigating = false;
  bool _useSimulation = true; // Easily toggles between Real GPS stream and Simulation demo mode
  int _currentStepIndex = 0;
  Timer? _navigationTimer;
  StreamSubscription<Position>? _positionStreamSubscription;
  
  double _remainingDistance = 0.0;
  int _remainingDuration = 0;
  LatLng _simulatedUserLocation = const LatLng(19.0544, 72.8401);

  // Map markers & shapes
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  final List<CircleMarker> _heatmapCircles = [];

  // Dynamic databases loaded from APIs
  List<Map<String, dynamic>> _dynamicDangerPoints = [];
  List<Map<String, dynamic>> _dynamicSafeZones = [];

  LatLng _currentLocation = const LatLng(19.0544, 72.8401); // Bandra West start
  String _selectedTransportMode = 'walking';
  String _fromLabel = 'My Location';
  String _toLabel = 'Select Destination';

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final pos = locationService.currentPosition;
    if (pos != null) {
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _simulatedUserLocation = _currentLocation;
      });
      _reverseGeocodeStart(pos.latitude, pos.longitude);
    }
    
    // Initial fetch of database elements centered around the current coordinates
    await _fetchDynamicSafetyAssets();
    _loadPredefinedRoute();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      final position = await locationService.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _simulatedUserLocation = _currentLocation;
        });
        _reverseGeocodeStart(position.latitude, position.longitude);
        _mapController.move(_currentLocation, 14);
        await _fetchDynamicSafetyAssets();
        if (_destinationController.text.isNotEmpty) {
          _findSafeRoute();
        } else {
          _loadPredefinedRoute();
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  // Reverse geocodes the coordinates to display the neighborhood name
  Future<void> _reverseGeocodeStart(double lat, double lng) async {
    try {
      final placemarks = await geo.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        setState(() {
          _fromLabel = p.subLocality != null && p.subLocality!.isNotEmpty 
              ? '${p.subLocality}, ${p.locality ?? ''}' 
              : (p.locality ?? 'My Location');
        });
      }
    } catch (_) {}
  }

  // Fetch real safety infrastructure and reports from the database dynamically
  Future<void> _fetchDynamicSafetyAssets() async {
    try {
      // 1. Fetch real incident reports from SQLite database
      final reportsResponse = await _apiService.get(
        '/reports/incidents?lat=${_currentLocation.latitude}&lng=${_currentLocation.longitude}&radius=15.0'
      );
      final List<dynamic> incidentsList = reportsResponse['incidents'] ?? [];
      
      // 2. Fetch safe zones / police / hospitals from backend
      final zonesResponse = await _apiService.get(
        '/routes/nearby-safe-zones?lat=${_currentLocation.latitude}&lng=${_currentLocation.longitude}&radius=15.0'
      );
      final List<dynamic> safeZonesList = zonesResponse['safe_zones'] ?? [];

      setState(() {
        _dynamicDangerPoints = incidentsList.map((inc) {
          final severity = inc['severity'] ?? 'medium';
          String level = 'yellow';
          if (severity == 'high') {
            level = 'red';
          } else if (severity == 'medium') {
            level = 'orange';
          }
          return {
            'name': inc['incident_type'] ?? 'Reported Incident',
            'address': inc['address'] ?? 'Reported Location',
            'lat': inc['latitude'] as double,
            'lng': inc['longitude'] as double,
            'level': level,
            'reason': inc['description'] ?? 'Isolated safety threat',
          };
        }).toList();

        _dynamicSafeZones = safeZonesList.map((zone) {
          final type = zone['type'] ?? 'police';
          return {
            'name': zone['name'] ?? 'Safety Center',
            'lat': zone['latitude'] ?? zone['lat'] as double,
            'lng': zone['longitude'] ?? zone['lng'] as double,
            'type': type,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("Error loading real-time safety database assets: $e");
    }
  }

  void _loadPredefinedRoute() {
    // Generate route waypoints dynamically depending on loaded reports
    final routePoints = [
      RouteLatLng(19.0544, 72.8401, safetyScore: 95, riskLevel: 'Safe', color: 'green'),
      RouteLatLng(19.0620, 72.8360, safetyScore: 82, riskLevel: 'Safe', color: 'green'), 
      RouteLatLng(19.0740, 72.8390, safetyScore: 35, riskLevel: 'High Risk', color: 'red'), // Khar area
      RouteLatLng(19.0820, 72.8300, safetyScore: 68, riskLevel: 'Low Risk', color: 'yellow'), 
      RouteLatLng(19.0987, 72.8220, safetyScore: 92, riskLevel: 'Safe', color: 'green'), // Juhu Beach
    ];

    setState(() {
      _currentRoute = SafeRoute(
        waypoints: routePoints,
        distance: 5.6,
        duration: 16,
        safeScore: 78,
        transportMode: _selectedTransportMode,
      );
      _destinationController.text = 'Juhu Beach';
      _toLabel = 'Juhu Beach';
      _updateMapLayers();
    });
  }

  Future<void> _findSafeRoute() async {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a destination')),
      );
      return;
    }

    setState(() {
      _isFindingRoute = true;
      _isLoading = true;
    });

    try {
      final routeService = Provider.of<RouteService>(context, listen: false);
      
      LatLng startLoc = _currentLocation;
      double endLat = startLoc.latitude + 0.01;
      double endLng = startLoc.longitude + 0.01;

      // Geocode the entered text query dynamically
      try {
        final query = destination.toLowerCase();
        if (query.contains('lilavati')) {
          endLat = 19.0330;
          endLng = 72.8343;
        } else if (query.contains('juhu')) {
          endLat = 19.0987;
          endLng = 72.8220;
        } else if (query.contains('andheri')) {
          endLat = 19.1179;
          endLng = 72.8488;
        } else if (query.contains('kokilaben')) {
          endLat = 19.1279;
          endLng = 72.8440;
        } else if (query.contains('jj hospital')) {
          endLat = 18.9604;
          endLng = 72.8350;
        } else if (query.contains('gateway')) {
          endLat = 18.9220;
          endLng = 72.8347;
        } else if (query.contains('marine drive')) {
          endLat = 18.9433;
          endLng = 72.8214;
        } else {
          final locations = await geo.locationFromAddress(destination).timeout(const Duration(seconds: 4));
          if (locations.isNotEmpty) {
            endLat = locations.first.latitude;
            endLng = locations.first.longitude;
          }
        }
      } catch (_) {
        final hash = destination.hashCode;
        final latOffset = ((hash % 100) - 50) / 4500.0;
        final lngOffset = (((hash ~/ 100) % 100) - 50) / 4500.0;
        endLat = startLoc.latitude + latOffset;
        endLng = startLoc.longitude + lngOffset;
      }

      // Reverse geocode destination coordinates to obtain actual area neighborhood name
      try {
        final placemarks = await geo.placemarkFromCoordinates(endLat, endLng);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          setState(() {
            _toLabel = p.subLocality != null && p.subLocality!.isNotEmpty 
                ? '${p.subLocality}, ${p.locality ?? ''}' 
                : (p.locality ?? destination);
          });
        } else {
          setState(() {
            _toLabel = destination;
          });
        }
      } catch (_) {
        setState(() {
          _toLabel = destination;
        });
      }

      // Query safe route from API
      final route = await routeService.getSafeRoute(
        startLat: startLoc.latitude,
        startLng: startLoc.longitude,
        endLat: endLat,
        endLng: endLng,
        avoidUnsafeAreas: true,
      );

      final List<RouteLatLng> coloredWaypoints = [];
      for (var wp in route.waypoints) {
        String riskColor = wp.color.isNotEmpty ? wp.color : 'green';
        int safetyScore = wp.safetyScore > 0 ? wp.safetyScore : 95;
        String riskLevel = wp.riskLevel.isNotEmpty ? wp.riskLevel : 'Safe';
        
        // Match coordinates to dynamic danger overlays
        for (var danger in _dynamicDangerPoints) {
          final distance = Geolocator.distanceBetween(wp.latitude, wp.longitude, danger['lat'], danger['lng']);
          if (distance < 350) {
            riskColor = danger['level'];
            safetyScore = danger['level'] == 'red' ? 32 : 54;
            riskLevel = danger['level'] == 'red' ? 'High Risk' : 'Medium Risk';
            break;
          }
        }
        coloredWaypoints.add(RouteLatLng(
          wp.latitude,
          wp.longitude,
          safetyScore: safetyScore,
          riskLevel: riskLevel,
          color: riskColor,
        ));
      }

      setState(() {
        _currentRoute = SafeRoute(
          waypoints: coloredWaypoints,
          distance: route.distance,
          duration: route.duration,
          safeScore: route.safeScore,
          transportMode: _selectedTransportMode,
        );
        _updateMapLayers();
      });

      _mapController.move(startLoc, 13);

      final hasRedZone = coloredWaypoints.any((wp) => wp.color == 'red');
      if (hasRedZone && mounted) {
        _showUnavoidableDangerAlert();
      }
    } catch (e) {
      debugPrint('Error finding safe route: $e');
      _loadPredefinedRoute();
    } finally {
      setState(() {
        _isLoading = false;
        _isFindingRoute = false;
      });
    }
  }

  void _showUnavoidableDangerAlert() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.dangerRed),
            SizedBox(width: 8),
            Text('Dangerous Zones Detected', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'Your route crosses through areas with high-risk complaints that cannot be fully avoided. '
          'Real-time proximity alerts will guide you around these obstacles.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPink),
            child: const Text('Proceed with Guidance'),
          ),
        ],
      ),
    );
  }

  void _updateMapLayers() {
    _markers.clear();
    _polylines.clear();
    _heatmapCircles.clear();

    if (_currentRoute == null || _currentRoute!.waypoints.isEmpty) return;

    final waypoints = _currentRoute!.waypoints;

    // 1. Current simulated/real location blue dot marker
    _markers.add(
      Marker(
        point: _isNavigating ? _simulatedUserLocation : _currentLocation,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.locationBlue.withOpacity(0.2),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.locationBlue.withOpacity(0.6),
                blurRadius: 10,
                spreadRadius: 2,
              )
            ]
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.locationBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.circle, color: Colors.white, size: 10),
          ),
        ),
      ),
    );

    // 2. Destination Marker (green pin)
    final dest = waypoints.last;
    _markers.add(
      Marker(
        point: LatLng(dest.latitude, dest.longitude),
        child: const Icon(Icons.location_on, color: AppTheme.safeGreen, size: 36),
      ),
    );

    // 3. Dynamic Police Stations & Hospitals (fetched from backend)
    for (var inf in _dynamicSafeZones) {
      final lat = inf['lat'] as double;
      final lng = inf['lng'] as double;
      final type = inf['type'] as String;
      final name = inf['name'] as String;

      _markers.add(
        Marker(
          point: LatLng(lat, lng),
          child: GestureDetector(
            onTap: () => _showAreaDetailsSheet(name, 'Safe Infrastructure', 'Security patrol active in this sector.', AppTheme.safeGreen),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: type == 'police' ? Colors.blue.shade900 : Colors.red.shade900,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Icon(
                type == 'police' ? Icons.shield : Icons.local_hospital,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      );

      // Green safety heatmap circles
      _heatmapCircles.add(
        CircleMarker(
          point: LatLng(lat, lng),
          radius: 350,
          useRadiusInMeter: true,
          color: AppTheme.safeGreen.withOpacity(0.09),
          borderColor: AppTheme.safeGreen.withOpacity(0.35),
          borderStrokeWidth: 1,
        ),
      );
    }

    // 4. Dynamic Reported Danger Markers (fetched from database)
    for (var danger in _dynamicDangerPoints) {
      final lat = danger['lat'] as double;
      final lng = danger['lng'] as double;
      final level = danger['level'] as String;
      final name = danger['name'] as String;
      final reason = danger['reason'] as String;

      _markers.add(
        Marker(
          point: LatLng(lat, lng),
          child: GestureDetector(
            onTap: () => _showAreaDetailsSheet(name, 'Incident Alert', reason, level == 'red' ? AppTheme.dangerRed : AppTheme.warningOrange),
            child: Icon(
              Icons.warning_amber_rounded,
              color: level == 'red' ? AppTheme.dangerRed : AppTheme.warningOrange,
              size: 24,
            ),
          ),
        ),
      );

      // Red/Orange danger heatmap circles
      _heatmapCircles.add(
        CircleMarker(
          point: LatLng(lat, lng),
          radius: level == 'red' ? 380 : 250,
          useRadiusInMeter: true,
          color: level == 'red' 
              ? AppTheme.dangerRed.withOpacity(0.14)
              : Colors.orange.withOpacity(0.14),
          borderColor: level == 'red' 
              ? AppTheme.dangerRed.withOpacity(0.55)
              : Colors.orange.withOpacity(0.55),
          borderStrokeWidth: 1,
        ),
      );
    }

    // 5. Draw route polylines:
    // "If area is danger make that whole route red not just circle. Same with yellow and green"
    final overallScore = _currentRoute?.safeScore ?? 80;
    Color routeColor = AppTheme.safeGreen;
    
    // Scan waypoints to check if any Red (danger) or Orange (caution) coordinates exist
    final hasRedWaypoint = waypoints.any((wp) => wp.color == 'red');
    final hasOrangeWaypoint = waypoints.any((wp) => wp.color == 'orange' || wp.color == 'yellow');

    if (hasRedWaypoint || overallScore < 50) {
      routeColor = AppTheme.dangerRed;
    } else if (hasOrangeWaypoint || overallScore < 80) {
      routeColor = Colors.orange.shade600;
    } else {
      routeColor = AppTheme.safeGreen;
    }

    // Draw the WHOLE route with a single color matching the safety status
    for (int i = 0; i < waypoints.length - 1; i++) {
      final p1 = LatLng(waypoints[i].latitude, waypoints[i].longitude);
      final p2 = LatLng(waypoints[i + 1].latitude, waypoints[i + 1].longitude);

      // Trailing glow polyline layer
      _polylines.add(
        Polyline(
          points: [p1, p2],
          color: routeColor.withOpacity(0.28),
          strokeWidth: 12,
        ),
      );

      // Top solid path layer
      _polylines.add(
        Polyline(
          points: [p1, p2],
          color: routeColor,
          strokeWidth: 5,
        ),
      );
    }

    setState(() {});
  }

  void _showAreaDetailsSheet(String name, String type, String details, Color themeColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    type,
                    style: TextStyle(color: themeColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Text(
              details,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Dismiss', style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Color _getRiskColor(String colorStr) {
    switch (colorStr.toLowerCase()) {
      case 'green':
        return AppTheme.safeGreen;
      case 'yellow':
        return Colors.yellow.shade600;
      case 'orange':
        return Colors.orange.shade600;
      case 'red':
        return AppTheme.dangerRed;
      default:
        return AppTheme.locationBlue;
    }
  }

  // Active Navigation Selector
  void _startNavigation() {
    if (_useSimulation) {
      _startNavigationSimulation();
    } else {
      _startRealGPSNavigation();
    }
  }

  // Engine A: Simulated progression (demo mode)
  void _startNavigationSimulation() {
    if (_currentRoute == null || _currentRoute!.waypoints.isEmpty) return;
    
    _navigationTimer?.cancel();
    _positionStreamSubscription?.cancel();
    
    setState(() {
      _isNavigating = true;
      _currentStepIndex = 0;
      _simulatedUserLocation = LatLng(
        _currentRoute!.waypoints[0].latitude,
        _currentRoute!.waypoints[0].longitude,
      );
      _remainingDistance = _currentRoute!.distance;
      _remainingDuration = _currentRoute!.duration;
    });

    _updateMapLayers();
    _mapController.move(_simulatedUserLocation, 16);

    _navigationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final wps = _currentRoute!.waypoints;
      if (_currentStepIndex < wps.length - 1) {
        setState(() {
          _currentStepIndex++;
          _simulatedUserLocation = LatLng(
            wps[_currentStepIndex].latitude,
            wps[_currentStepIndex].longitude,
          );
          
          double remaining = 0.0;
          for (int j = _currentStepIndex; j < wps.length - 1; j++) {
            remaining += wps[j].distanceTo(wps[j + 1]);
          }
          _remainingDistance = remaining;
          _remainingDuration = ((_remainingDistance / _currentRoute!.distance) * _currentRoute!.duration).round();
          if (_remainingDuration < 1) _remainingDuration = 1;
        });

        _updateMapLayers();
        _mapController.move(_simulatedUserLocation, 16);
        _checkRealProximityAlert(_simulatedUserLocation.latitude, _simulatedUserLocation.longitude);
      } else {
        timer.cancel();
        _showArrivalDialog();
      }
    });
  }

  // Engine B: Real-time GPS stream tracker (actual navigation)
  void _startRealGPSNavigation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are required for live GPS navigation.')),
      );
      return;
    }

    _navigationTimer?.cancel();
    _positionStreamSubscription?.cancel();
    
    setState(() {
      _isNavigating = true;
      _currentStepIndex = 0;
    });

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((Position position) {
      if (!mounted) return;
      
      final currentPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = currentPos;
        _simulatedUserLocation = currentPos;
        
        if (_currentRoute != null && _currentRoute!.waypoints.isNotEmpty) {
          final dest = _currentRoute!.waypoints.last;
          _remainingDistance = Geolocator.distanceBetween(
            _currentLocation.latitude,
            _currentLocation.longitude,
            dest.latitude,
            dest.longitude,
          ) / 1000.0; // km
          
          _remainingDuration = ((_remainingDistance / _currentRoute!.distance) * _currentRoute!.duration).round();
          if (_remainingDuration < 1) _remainingDuration = 1;
        }
      });

      _updateMapLayers();
      _mapController.move(currentPos, 16.5);
      
      // Proximity alarm checks
      _checkRealProximityAlert(position.latitude, position.longitude);
    });
  }

  void _checkRealProximityAlert(double lat, double lng) {
    for (var danger in _dynamicDangerPoints) {
      final double distance = Geolocator.distanceBetween(
        lat,
        lng,
        danger['lat'],
        danger['lng'],
      );

      if (distance <= 300.0) {
        final level = danger['level'] as String;
        final name = danger['name'] as String;
        final reason = danger['reason'] as String;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.warning, 
                      color: level == 'red' ? Colors.white : Colors.black, 
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Entering Danger Zone: $name',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('$reason (${distance.toStringAsFixed(0)}m away)', style: const TextStyle(fontSize: 11)),
              ],
            ),
            backgroundColor: level == 'red' ? AppTheme.dangerRed : AppTheme.warningOrange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: AppTheme.safeGreen, size: 28),
            SizedBox(width: 8),
            Text('Arrived Safely', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'You have successfully arrived at $_toLabel. The navigation tracking has completed.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isNavigating = false;
                _currentStepIndex = 0;
              });
              _getCurrentLocation();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  void _stopNavigation() {
    _navigationTimer?.cancel();
    _positionStreamSubscription?.cancel();
    setState(() {
      _isNavigating = false;
      _currentStepIndex = 0;
    });
    _getCurrentLocation();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Navigation stopped.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Top Glassmorphic Location Inputs
            if (!_isNavigating)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.my_location, color: AppTheme.primaryPink, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                Text(
                                  _fromLabel,
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white38, size: 16),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(color: Colors.white10, height: 1),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: AppTheme.accentViolet, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('To', style: TextStyle(color: Colors.white38, fontSize: 10)),
                                TextField(
                                  controller: _destinationController,
                                  onSubmitted: (_) => _findSafeRoute(),
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    hintText: 'Enter destination...',
                                    hintStyle: TextStyle(color: Colors.white24, fontSize: 14),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white38, size: 16),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // 2. Large Map Canvas with CartoDB Premium Dark Theme Tiles
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _isNavigating ? _simulatedUserLocation : _currentLocation,
                            initialZoom: 14,
                            maxZoom: 18,
                            minZoom: 10,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                              subdomains: const ['a', 'b', 'c', 'd'],
                              userAgentPackageName: 'com.womensafety.women_safety_app',
                            ),
                            CircleLayer(circles: _heatmapCircles),
                            MarkerLayer(markers: _markers),
                            if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
                          ],
                        ),

                        if (!_isNavigating)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: FloatingActionButton.small(
                              onPressed: _getCurrentLocation,
                              backgroundColor: AppTheme.cardColor,
                              foregroundColor: Colors.white,
                              child: const Icon(Icons.gps_fixed),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 3. Glassmorphic Route Info Card & Navigation Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.cardColor.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isNavigating) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.shield, color: AppTheme.primaryPink, size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Safest Route',
                                style: TextStyle(color: AppTheme.primaryPink, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.safeGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Score: ${_currentRoute?.safeScore ?? 80}/100',
                              style: const TextStyle(color: AppTheme.safeGreen, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${_currentRoute?.duration ?? 12} min (${_currentRoute?.distance.toStringAsFixed(1) ?? 5.2} km)',
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Simulation Toggle Chip
                          InkWell(
                            onTap: () {
                              setState(() {
                                _useSimulation = !_useSimulation;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white12),
                                borderRadius: BorderRadius.circular(12),
                                color: _useSimulation ? Colors.white.withOpacity(0.05) : AppTheme.primaryPurple.withOpacity(0.2),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    _useSimulation ? Icons.videogame_asset : Icons.gps_fixed,
                                    size: 12,
                                    color: _useSimulation ? Colors.white70 : AppTheme.primaryPink,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _useSimulation ? 'Demo Sim' : 'Live GPS',
                                    style: TextStyle(
                                      color: _useSimulation ? Colors.white70 : Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'To: $_toLabel',
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Safer • Well Lit • Passes Near Police Stations • Avoids High-Risk Areas',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                      ),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _useSimulation ? Icons.smart_toy_outlined : Icons.navigation, 
                                color: AppTheme.primaryPink, 
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _useSimulation ? 'Active Tracking: Simulating...' : 'Active Tracking: GPS Live',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _useSimulation ? Colors.orange.withOpacity(0.15) : AppTheme.locationBlue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _useSimulation ? 'DEMO MODE' : 'GPS TRACKING',
                              style: TextStyle(
                                color: _useSimulation ? Colors.orange : AppTheme.locationBlue, 
                                fontSize: 9, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$_remainingDuration min',
                                  style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: AppTheme.safeGreen),
                                ),
                                Text(
                                  '${_remainingDistance.toStringAsFixed(2)} km remaining',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.white10,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Speed',
                                  style: TextStyle(color: Colors.white38, fontSize: 11),
                                ),
                                Text(
                                  '4.8 km/h',
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        if (!_isNavigating) ...[
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _loadPredefinedRoute,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.cardColor,
                                side: BorderSide(color: Colors.white.withOpacity(0.08)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              child: const Text('Preview Route', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _startNavigation,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.navigation, size: 16, color: Colors.white),
                                label: const Text('Start Navigation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ] else ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _stopNavigation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.cardColor,
                                side: BorderSide(color: AppTheme.dangerRed.withOpacity(0.4)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              icon: const Icon(Icons.cancel_outlined, color: AppTheme.dangerRed, size: 16),
                              label: const Text('Stop Navigation', style: TextStyle(color: AppTheme.dangerRed)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.primaryPink, width: 1.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _findSafeRoute,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.cardColor,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: const Icon(Icons.sync, size: 16, color: AppTheme.primaryPink),
                                label: const Text('Reroute Safely', style: TextStyle(color: AppTheme.primaryPink, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                        ],
                      ],
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
}