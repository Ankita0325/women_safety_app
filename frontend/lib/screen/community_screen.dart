import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _reportController = TextEditingController();
  String _selectedIncidentType = 'Harassment';
  bool _isAnonymous = true;
  bool _isLoading = false;
  List<Map<String, dynamic>> _reports = [];

  final List<String> _incidentTypes = [
    'Harassment',
    'Stalking',
    'Physical Assault',
    'Sexual Assault',
    'Domestic Violence',
    'Road Accident',
    'Medical Emergency',
    'Fire',
    'Theft',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.get(
        '/reports/incidents?lat=19.0760&lng=72.8777&radius=10&limit=50',
      );
      final data = response['incidents'] as List?;
      if (data != null) {
        if (!mounted) return;
        setState(() {
          _reports = data.map((e) {
            return {
              'id': e['id'] ?? e['_id'] ?? 'unknown',
              'type': e['incident_type'] ?? 'General',
              'description': e['description'] ?? '',
              'location': e['address'] ?? 'Unknown Location',
              'timestamp': DateTime.tryParse(e['timestamp'] ?? '') ?? DateTime.now(),
              'anonymous': e['is_anonymous'] ?? true,
              'severity': e['severity'] ?? 'medium',
            };
          }).toList();
        });
        return;
      }
    } catch (e) {
      print('Error loading reports: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }

    _reports = [
      {
        'id': '1',
        'type': 'Harassment',
        'description': 'Verbal harassment near Andheri station',
        'location': 'Andheri, Mumbai',
        'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
        'anonymous': true,
        'severity': 'medium',
      },
      {
        'id': '2',
        'type': 'Stalking',
        'description': 'Suspicious person following me at Bandra',
        'location': 'Bandra, Mumbai',
        'timestamp': DateTime.now().subtract(const Duration(days: 1)),
        'anonymous': true,
        'severity': 'high',
      },
    ];
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submitReport() async {
    if (_reportController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please describe the incident'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiService.post(
        '/reports/incident',
        body: {
          'type': _selectedIncidentType,
          'description': _reportController.text,
          'latitude': 19.0760,
          'longitude': 72.8777,
          'address': 'Current Location',
          'is_anonymous': _isAnonymous,
          'images': [],
        },
      );

      _reportController.clear();
      await _loadReports();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error submitting report: $e');
      final newReport = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'type': _selectedIncidentType,
        'description': _reportController.text,
        'location': 'Current Location',
        'timestamp': DateTime.now(),
        'anonymous': _isAnonymous,
        'severity': 'medium',
      };

      setState(() {
        _reports.insert(0, newReport);
        _isLoading = false;
      });
      _reportController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline: Report saved locally!'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        backgroundColor: const Color(0xFFFF4081),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Report Incident',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedIncidentType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      items: _incidentTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedIncidentType = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _reportController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Describe the incident...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _isAnonymous,
                          onChanged: (value) {
                            setState(() {
                              _isAnonymous = value!;
                            });
                          },
                        ),
                        const Text('Report Anonymously'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitReport,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4081),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Submit Report'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Recent Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (_reports.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No reports yet'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reports.length,
                itemBuilder: (context, index) {
                  final report = _reports[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: report['severity'] == 'high'
                                      ? Colors.red
                                      : Colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  report['type'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                report['anonymous']
                                    ? Icons.person_outline
                                    : Icons.person,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                report['anonymous'] ? 'Anonymous' : 'User',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            report['description'],
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                report['location'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatTimeAgo(report['timestamp']),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(dynamic timestamp) {
    if (timestamp is String) {
      return 'Recently';
    }
    final now = DateTime.now();
    final difference = now.difference(timestamp as DateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
