import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/route_model.dart';
import '../services/location_service.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final TextEditingController _destinationController = TextEditingController();
  SafeRoute? _currentRoute;
  bool _isLoading = false;
  bool _isFindingRoute = false;
  final List<Marker> _markers = [];
  final List<Polyline> _polylines = [];
  final LatLng _currentLocation = const LatLng(19.0760, 72.8777);
  String _selectedTransportMode = 'walking';
  final List<String> _transportModes = ['walking', 'driving', 'transit'];

  @override
  void initState() {
    super.initState();
    _loadSampleRoute();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationService =
          Provider.of<LocationService>(context, listen: false);
      final position = await locationService.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _markers.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to get current location')),
        );
      }
    }
  }

  void _loadSampleRoute() {
    setState(() {
      _currentRoute = SafeRoute(
        waypoints: [
          RouteLatLng(_currentLocation.latitude, _currentLocation.longitude),
          RouteLatLng(19.0544, 72.8401),
          RouteLatLng(19.0330, 72.8343),
        ],
        distance: 5.2,
        duration: 15,
        safeScore: 85,
        transportMode: _selectedTransportMode,
      );
      _updateMarkers();
      _updatePolylines();
    });
  }

  void _updateMarkers() {
    _markers.clear();

    _markers.add(
      Marker(
        point: _currentLocation,
        child: const Icon(Icons.my_location, color: Color(0xFFFF4081)),
      ),
    );

    if (_currentRoute != null && _currentRoute!.waypoints.isNotEmpty) {
      final lastPoint = _currentRoute!.waypoints.last;
      _markers.add(
        Marker(
          point: LatLng(lastPoint.latitude, lastPoint.longitude),
          child: const Icon(Icons.location_on, color: Colors.red),
        ),
      );
    }
  }

  void _updatePolylines() {
    _polylines.clear();

    if (_currentRoute != null && _currentRoute!.waypoints.isNotEmpty) {
      final points = _currentRoute!.waypoints
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      _polylines.add(
        Polyline(
          points: points,
          color: _currentRoute!.safeScore > 80
              ? const Color(0xFF4CAF50)
              : _currentRoute!.safeScore > 60
                  ? const Color(0xFFFF4081)
                  : const Color(0xFFFF9800),
          strokeWidth: 6,
        ),
      );
    }
  }

  Future<void> _findSafeRoute() async {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      if (!mounted) return;
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
      await Future.delayed(const Duration(seconds: 1));

      final randomScore = 60 + (DateTime.now().millisecondsSinceEpoch % 40);
      final randomDistance = 2.0 + (DateTime.now().millisecondsSinceEpoch % 8);
      final randomDuration = 8 + (DateTime.now().millisecondsSinceEpoch % 20);

      final waypoints = [
        RouteLatLng(_currentLocation.latitude, _currentLocation.longitude),
        RouteLatLng(
          _currentLocation.latitude + 0.01,
          _currentLocation.longitude + 0.01,
        ),
        RouteLatLng(
          _currentLocation.latitude + 0.02,
          _currentLocation.longitude + 0.02,
        ),
      ];

      setState(() {
        _currentRoute = SafeRoute(
          waypoints: waypoints,
          distance: randomDistance,
          duration: randomDuration,
          safeScore: randomScore,
          transportMode: _selectedTransportMode,
        );
        _updateMarkers();
        _updatePolylines();
        _isLoading = false;
        _isFindingRoute = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Safe route found! $randomScore% safe')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isFindingRoute = false;
      });
    }
  }

  void _showRouteDetails() {
    if (_currentRoute == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Route Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              icon: Icons.route,
              label: 'Distance',
              value: '${_currentRoute!.distance.toStringAsFixed(1)} km',
            ),
            _buildDetailRow(
              icon: Icons.timer,
              label: 'Estimated Time',
              value: '${_currentRoute!.duration} min',
            ),
            _buildDetailRow(
              icon: Icons.security,
              label: 'Safety Score',
              value: '${_currentRoute!.safeScore}%',
              color: _currentRoute!.safeScore > 80
                  ? Colors.green
                  : _currentRoute!.safeScore > 60
                      ? Colors.orange
                      : Colors.red,
            ),
            _buildDetailRow(
              icon: Icons.directions_walk,
              label: 'Transport Mode',
              value: _currentRoute!.transportMode?.toUpperCase() ?? 'WALKING',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.map),
                label: const Text('Close'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4081),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFF4081)),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Route'),
        backgroundColor: const Color(0xFFFF4081),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'My Location',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _currentRoute != null ? _showRouteDetails : null,
            tooltip: 'Route Details',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _destinationController,
                        decoration: InputDecoration(
                          hintText: 'Enter destination...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          prefixIcon: const Icon(Icons.search,
                              color: Color(0xFFFF4081)),
                        ),
                        onSubmitted: (_) => _findSafeRoute(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isFindingRoute ? null : _findSafeRoute,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4081),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(70, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Go',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'Mode:',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ..._transportModes.map((mode) => Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: ChoiceChip(
                            label: Text(
                              mode.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                color: _selectedTransportMode == mode
                                    ? Colors.white
                                    : Colors.grey,
                              ),
                            ),
                            selected: _selectedTransportMode == mode,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedTransportMode = mode;
                                });
                                if (_currentRoute != null) {
                                  _findSafeRoute();
                                }
                              }
                            },
                            selectedColor: const Color(0xFFFF4081),
                            backgroundColor: Colors.grey.shade100,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                        )),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _currentLocation,
                    initialZoom: 13,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.womensafety.women_safety_app',
                    ),
                    MarkerLayer(markers: _markers),
                    if (_polylines.isNotEmpty) PolylineLayer(polylines: _polylines),
                  ],
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: const Center(
                      child: Card(
                        elevation: 4,
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Finding safe route...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_currentRoute != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildRouteInfo(
                    icon: Icons.timeline,
                    label: 'Distance',
                    value: '${_currentRoute!.distance.toStringAsFixed(1)} km',
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  _buildRouteInfo(
                    icon: Icons.timer,
                    label: 'Time',
                    value: '${_currentRoute!.duration} min',
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade300,
                  ),
                  _buildRouteInfo(
                    icon: Icons.security,
                    label: 'Safety',
                    value: '${_currentRoute!.safeScore}%',
                    color: _currentRoute!.safeScore > 80
                        ? Colors.green
                        : _currentRoute!.safeScore > 60
                            ? Colors.orange
                            : Colors.red,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFFFF4081), size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black,
          ),
        ),
      ],
    );
  }
}