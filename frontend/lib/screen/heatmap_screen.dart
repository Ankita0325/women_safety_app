import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final List<Marker> _markers = [];
  final List<CircleMarker> _circles = [];
  final LatLng _currentLocation = const LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    _loadHeatmapData();
  }

  void _loadHeatmapData() {
    final unsafeAreas = [
      {'lat': 19.1179, 'lng': 72.8488, 'risk': 'high'},
      {'lat': 19.0544, 'lng': 72.8401, 'risk': 'medium'},
      {'lat': 18.9604, 'lng': 72.8350, 'risk': 'high'},
      {'lat': 19.0330, 'lng': 72.8343, 'risk': 'medium'},
    ];

    for (var area in unsafeAreas) {
      final lat = area['lat'] as double;
      final lng = area['lng'] as double;
      final risk = area['risk'] as String;

      _markers.add(
        Marker(
          point: LatLng(lat, lng),
          child: const Icon(Icons.warning, color: Colors.red),
        ),
      );

      _circles.add(
        CircleMarker(
          point: LatLng(lat, lng),
          radius: risk == 'high' ? 200 : 150,
          color: risk == 'high'
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
          borderColor: risk == 'high' ? Colors.red : Colors.orange,
          borderStrokeWidth: 2,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Heatmap'),
        backgroundColor: const Color(0xFFFF4081),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnCurrentLocation,
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _currentLocation,
          initialZoom: 12,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.womensafety.women_safety_app',
          ),
          MarkerLayer(markers: _markers),
          CircleLayer(circles: _circles),
        ],
      ),
    );
  }

  void _centerOnCurrentLocation() {
    // Map automatically centers on initialCenter
  }
}