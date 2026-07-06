import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';
import '../services/location_service.dart';
import '../utils/theme.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  List<Marker> _markers = [];
  List<CircleMarker> _circles = [];
  LatLng _currentLocation = const LatLng(19.0760, 72.8777);
  bool _isLoading = false;

  // Filter States
  int _selectedDays = 30; // 1, 3, 7, 30
  String? _selectedCategory; // All, Harassment, Stalking, Theft, Poor Lighting, Unsafe Transport
  
  List<Map<String, dynamic>> _heatmapData = [];
  Map<String, dynamic> _aiAnalysis = {};

  final List<String> _categories = [
    'All',
    'Harassment',
    'Stalking',
    'Theft',
    'Poor Lighting',
    'Unsafe Transport',
    'Assault'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    final locationService = Provider.of<LocationService>(context, listen: false);
    final pos = locationService.currentPosition;
    if (pos != null) {
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
      _loadHeatmapData();
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);
    try {
      final locationService = Provider.of<LocationService>(context, listen: false);
      final position = await locationService.getCurrentPosition();
      if (position != null && mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_currentLocation, 13);
      }
    } catch (e) {
      debugPrint('Error fetching location: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      _loadHeatmapData();
    }
  }

  Future<void> _loadHeatmapData() async {
    setState(() => _isLoading = true);
    try {
      String endpoint = '/reports/heatmap-data?lat=${_currentLocation.latitude}&lng=${_currentLocation.longitude}&radius=15&days=$_selectedDays';
      if (_selectedCategory != null && _selectedCategory != 'All') {
        endpoint += '&category=$_selectedCategory';
      }

      final response = await _apiService.get(endpoint);
      final data = response['heatmap_data'] as List?;
      
      if (data != null) {
        _heatmapData = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _aiAnalysis = response['analysis'] ?? {};
        _buildMapLayers();
      }
    } catch (e) {
      debugPrint('Error loading heatmap data: $e');
      _loadOfflineFallback();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _loadOfflineFallback() {
    // Generate mockup data offline
    _heatmapData = [
      {
        'id': 'off_1',
        'latitude': 19.1179,
        'longitude': 72.8488,
        'weight': 1.0,
        'severity': 'high',
        'type': 'Harassment',
        'category': 'Harassment',
        'status': 'verified',
        'safety_score': 32,
        'risk_level': 'High Risk',
        'color': 'red',
        'upvotes': 8,
        'downvotes': 0,
        'description': 'Multiple harassment reports near Andheri West railway station.'
      },
      {
        'id': 'off_2',
        'latitude': 19.0544,
        'longitude': 72.8401,
        'weight': 0.75,
        'severity': 'medium',
        'type': 'Poor Lighting',
        'category': 'Poor Lighting',
        'status': 'pending',
        'safety_score': 54,
        'risk_level': 'Medium Risk',
        'color': 'orange',
        'upvotes': 3,
        'downvotes': 1,
        'description': 'Isolated dark street under Bandra flyover. Streetlights out.'
      },
      {
        'id': 'off_3',
        'latitude': 19.0760,
        'longitude': 72.8777,
        'weight': 0.4,
        'severity': 'low',
        'type': 'Theft',
        'category': 'Theft',
        'status': 'verified',
        'safety_score': 72,
        'risk_level': 'Low Risk',
        'color': 'yellow',
        'upvotes': 1,
        'downvotes': 0,
        'description': 'Phone snatching complaint reported recently.'
      }
    ];
    _aiAnalysis = {
      'recommendations': [
        'Avoid pedestrian tunnels near Andheri after 9 PM.',
        'Prefer main routes near Bandra West station.'
      ]
    };
    _buildMapLayers();
  }

  Color _getRiskColor(String colorStr, {double opacity = 1.0}) {
    switch (colorStr.toLowerCase()) {
      case 'green':
        return AppTheme.safeGreen.withOpacity(opacity);
      case 'yellow':
        return AppTheme.warningOrange.withOpacity(opacity); // Using yellow/orange blend
      case 'orange':
        return Colors.orange.withOpacity(opacity);
      case 'red':
        return AppTheme.dangerRed.withOpacity(opacity);
      default:
        return Colors.blue.withOpacity(opacity);
    }
  }

  void _buildMapLayers() {
    _markers.clear();
    _circles.clear();

    // Current User Location Marker
    _markers.add(
      Marker(
        point: _currentLocation,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.locationBlue.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: const BoxDecoration(
              color: AppTheme.locationBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.my_location, color: Colors.white, size: 16),
          ),
        ),
      ),
    );

    // Heatmap markers & circles
    for (var report in _heatmapData) {
      final lat = (report['latitude'] ?? 0.0).toDouble();
      final lng = (report['longitude'] ?? 0.0).toDouble();
      final colorStr = report['color'] ?? 'orange';
      final severity = report['severity'] ?? 'medium';
      
      final radius = severity == 'high' 
          ? 350.0 
          : severity == 'medium' 
              ? 250.0 
              : 150.0;

      // Clickable transparent markers
      _markers.add(
        Marker(
          point: LatLng(lat, lng),
          child: GestureDetector(
            onTap: () => _showLocationDetailsBottomSheet(report),
            child: Icon(
              severity == 'high' 
                  ? Icons.error 
                  : severity == 'medium' 
                      ? Icons.warning 
                      : Icons.info,
              color: _getRiskColor(colorStr),
              size: 28,
            ),
          ),
        ),
      );

      // Area safety circle mapping
      _circles.add(
        CircleMarker(
          point: LatLng(lat, lng),
          radius: radius,
          useRadiusInMeter: true,
          color: _getRiskColor(colorStr, opacity: 0.22),
          borderColor: _getRiskColor(colorStr, opacity: 0.8),
          borderStrokeWidth: 1.5,
        ),
      );
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _searchLocation() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    // Simulate search location database coordinates matching
    // In production we geocode using OpenStreetMap Nominatim / Mapbox
    final lowerQuery = query.toLowerCase();
    LatLng target = _currentLocation;
    
    if (lowerQuery.contains('andheri')) {
      target = const LatLng(19.1179, 72.8488);
    } else if (lowerQuery.contains('bandra')) {
      target = const LatLng(19.0544, 72.8401);
    } else if (lowerQuery.contains('juhu')) {
      target = const LatLng(19.0987, 72.8220);
    } else if (lowerQuery.contains('gateway')) {
      target = const LatLng(18.9220, 72.8347);
    } else {
      // Offsets coordinate search representation
      target = LatLng(_currentLocation.latitude + 0.015, _currentLocation.longitude + 0.015);
    }

    setState(() {
      _currentLocation = target;
    });
    _mapController.move(target, 14);
    _loadHeatmapData();
  }

  void _showLocationDetailsBottomSheet(Map<String, dynamic> report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final int score = report['safety_score'] ?? 75;
            final String riskLevel = report['risk_level'] ?? 'Low Risk';
            final String colorName = report['color'] ?? 'yellow';
            final String desc = report['description'] ?? 'No incident description';
            
            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Heading
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report['category'] ?? report['type'] ?? 'Safety Zone Area',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.location_on, color: AppTheme.accentViolet, size: 16),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Lat: ${report['latitude'].toStringAsFixed(4)}, Lng: ${report['longitude'].toStringAsFixed(4)}',
                                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Safety Score Gauge
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _getRiskColor(colorName, opacity: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _getRiskColor(colorName), width: 1.5),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  '$score',
                                  style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: _getRiskColor(colorName),
                                  ),
                                ),
                                const Text(
                                  'Safety Score',
                                  style: TextStyle(fontSize: 10, color: Colors.white70),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Details Banner
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildInfoColumn(Icons.security_update_warning, '${report['upvotes']} Upvotes', 'Authenticity'),
                            _buildInfoColumn(Icons.flag_outlined, riskLevel, 'Risk Status'),
                            _buildInfoColumn(Icons.info_outline, 'Verify Required', 'Verification'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Description
                      Text(
                        'Reported Details',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        desc,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 20),

                      // Voting Section for Authenticity
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Help verify this report. Is this incident real?',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.thumb_up_alt_outlined, color: Colors.green),
                            onPressed: () => _castVote(report['id'], 'upvote', setModalState),
                          ),
                          Text('${report['upvotes']}', style: const TextStyle(color: Colors.green)),
                          const SizedBox(width: 10),
                          IconButton(
                            icon: const Icon(Icons.thumb_down_alt_outlined, color: Colors.red),
                            onPressed: () => _castVote(report['id'], 'downvote', setModalState),
                          ),
                          Text('${report['downvotes']}', style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                      const Divider(color: Colors.white12, height: 30),

                      // AI-generated safety advice
                      Text(
                        'AI Safety Recommendations',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryPink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPurple.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.primaryPurple.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.psychology, color: AppTheme.accentViolet),
                                SizedBox(width: 8),
                                Text(
                                  'SafeSphere Advisor',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              score < 40
                                  ? 'High hazard zone. Avoid walking here, especially during night hours. If you must pass, request a SafeSphere Emergency Companion guard or contact bandra police station.'
                                  : score < 60
                                      ? 'Caution recommended. Keep your phone accessible and share your live track path link with family.'
                                      : 'Generally safe area. Maintain standard security awareness.',
                              style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Navigation Actions
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/route');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryPurple,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.navigation, size: 18),
                              label: const Text('Navigate Safely'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, '/community');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.cardColor,
                                side: const BorderSide(color: AppTheme.primaryPink),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.report, color: AppTheme.primaryPink, size: 18),
                              label: const Text(
                                'Report Incident',
                                style: TextStyle(color: AppTheme.primaryPink),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInfoColumn(IconData icon, String text, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primaryPink, size: 22),
        const SizedBox(height: 6),
        Text(
          text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Future<void> _castVote(String reportId, String voteType, StateSetter setModalState) async {
    try {
      final res = await _apiService.post(
        '/reports/$reportId/vote',
        body: {'vote_type': voteType},
      );
      
      setModalState(() {
        final index = _heatmapData.indexWhere((element) => element['id'] == reportId);
        if (index != -1) {
          _heatmapData[index]['upvotes'] = res['upvotes'];
          _heatmapData[index]['downvotes'] = res['downvotes'];
          _heatmapData[index]['status'] = res['report_status'];
          _heatmapData[index]['safety_score'] = res['safety_score'];
          
          if (res['report_status'] == 'rejected') {
            _heatmapData.removeAt(index);
          }
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Vote recorded!'),
          backgroundColor: Colors.green,
        ),
      );
      
      _buildMapLayers();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to vote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          'AI Safety Heatmap',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.cardColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHeatmapData,
          ),
        ],
      ),
      body: Stack(
        children: [
          // Map Background
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: 13,
              maxZoom: 18,
              minZoom: 10,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.womensafety.women_safety_app',
                tileBuilder: (context, child, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      -0.21, -0.21, -0.21, 0, 255, // Invert and shift for dark theme
                      -0.07, -0.07, -0.07, 0, 255,
                      0.07, 0.07, 0.07, 0, 255,
                      0, 0, 0, 1, 0,
                    ]),
                    child: child,
                  );
                },
              ),
              CircleLayer(circles: _circles),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Filters and Search Bar Top Layer Overlay
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                // Search Box
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _searchLocation(),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search dangerous zones or suburbs...',
                      hintStyle: const TextStyle(color: Colors.white30),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.primaryPink),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.my_location, color: AppTheme.accentViolet),
                        onPressed: _getCurrentLocation,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Category Horizonal Scroll list
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      final isSelected = _selectedCategory == cat || (_selectedCategory == null && cat == 'All');
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryPurple,
                          backgroundColor: AppTheme.cardColor,
                          checkmarkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = cat == 'All' ? null : cat;
                            });
                            _loadHeatmapData();
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Timeline Slider & Indicator Overlay Bottom Layer
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardColor.withOpacity(0.92),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Incident Recency Timeline',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPink.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Last $_selectedDays Days',
                          style: const TextStyle(
                            color: AppTheme.primaryPink,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: AppTheme.primaryPink,
                      inactiveTrackColor: Colors.white12,
                      thumbColor: AppTheme.primaryPink,
                      overlayColor: AppTheme.primaryPink.withOpacity(0.2),
                      valueIndicatorColor: AppTheme.primaryPink,
                    ),
                    child: Slider(
                      value: _selectedDays.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 4,
                      label: '$_selectedDays Days',
                      onChanged: (value) {
                        setState(() {
                          _selectedDays = value.round();
                        });
                      },
                      onChangeEnd: (_) {
                        _loadHeatmapData();
                      },
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('1 Day ago', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      Text('3 Days', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      Text('7 Days', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      Text('15 Days', style: TextStyle(color: Colors.white54, fontSize: 10)),
                      Text('30 Days', style: TextStyle(color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryPink),
              ),
            ),
        ],
      ),
    );
  }
}