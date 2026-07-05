import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final TextEditingController _reportController = TextEditingController();
  String _selectedIncidentType = 'Harassment';
  bool _isAnonymous = true;
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

  void _loadReports() {
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
    setState(() {});
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
    });

    _reportController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report submitted successfully!'),
        backgroundColor: Colors.green,
      ),
    );
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
