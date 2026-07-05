import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/route_model.dart';

class RouteScreen extends StatefulWidget {
  const RouteScreen({super.key});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  final TextEditingController _destinationController = TextEditingController();
  GoogleMapController? _mapController;
  SafeRoute? _currentRoute;
  bool _isLoading = false;
  final Set<Marker> _markers = {};
  LatLng _currentLocation = const LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    _loadSampleRoute();
  }

  void _loadSampleRoute() {
    setState(() {
      _currentRoute = SafeRoute(
        waypoints: [
          RouteLatLng(19.0760, 72.8777),
          RouteLatLng(19.0544, 72.8401),
          RouteLatLng(19.0330, 72.8343),
        ],
        distance: 5.2,
        duration: 15,
        safeScore: 85,
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: LatLng(19.0760, 72.8777),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Start'),
        ),
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: LatLng(19.0330, 72.8343),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    });
  }

  Future<void> _findSafeRoute() async {
    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      _isLoading = false;
      _currentRoute = SafeRoute(
        waypoints: [
          RouteLatLng(_currentLocation.latitude, _currentLocation.longitude),
          RouteLatLng(19.0330, 72.8343),
        ],
        distance: 4.5,
        duration: 12,
        safeScore: 90,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Route'),
        backgroundColor: const Color(0xFFFF4081),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _destinationController,
                    decoration: InputDecoration(
                      hintText: 'Enter destination',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _findSafeRoute(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : _findSafeRoute,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4081),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 56),
                  ),
                  child: const Text('Go'),
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              onMapCreated: (controller) {
                _mapController = controller;
              },
              initialCameraPosition: CameraPosition(
                target: _currentLocation,
                zoom: 13,
              ),
              markers: _markers,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              polylines: _currentRoute != null
                  ? {
                      Polyline(
                        polylineId: const PolylineId('route'),
                        color: const Color(0xFFFF4081),
                        width: 5,
                        points: _currentRoute!.waypoints
                            .map((point) => LatLng(point.latitude, point.longitude))
                            .toList(),
                      ),
                    }
                  : {},
            ),
          ),
          if (_currentRoute != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
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
                  _buildRouteInfo(
                    icon: Icons.timer,
                    label: 'Time',
                    value: '${_currentRoute!.duration} min',
                  ),
                  _buildRouteInfo(
                    icon: Icons.security,
                    label: 'Safety',
                    value: '${_currentRoute!.safeScore}%',
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
    }) {
      return Column(
        children: [
          Icon(icon, color: const Color(0xFFFF4081)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }
  }
