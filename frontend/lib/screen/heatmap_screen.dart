import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  LatLng _currentLocation = const LatLng(19.0760, 72.8777);

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
          markerId: MarkerId('${lat}_$lng'),
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            risk == 'high'
                ? BitmapDescriptor.hueRed
                : BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: 'Unsafe Area', snippet: 'Risk: $risk'),
        ),
      );

      _circles.add(
        Circle(
          circleId: CircleId('circle_${lat}_$lng'),
          center: LatLng(lat, lng),
          radius: risk == 'high' ? 200 : 150,
          fillColor: risk == 'high'
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
          strokeColor: risk == 'high' ? Colors.red : Colors.orange,
          strokeWidth: 2,
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
      body: GoogleMap(
        onMapCreated: (controller) {
          _mapController = controller;
        },
        initialCameraPosition: CameraPosition(
          target: _currentLocation,
          zoom: 12,
        ),
        markers: _markers,
        circles: _circles,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
      ),
    );
  }

  void _centerOnCurrentLocation() {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(_currentLocation, 14),
    );
  }
}
