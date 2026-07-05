import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support & Resources'),
        backgroundColor: const Color(0xFFFF4081),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency Helplines
            _buildSection(
              title: '🚨 Emergency Helplines',
              children: [
                _buildContactCard(
                  icon: Icons.local_police,
                  title: 'Police',
                  number: '100',
                  color: Colors.blue,
                ),
                _buildContactCard(
                  icon: Icons.health_and_safety,
                  title: 'Women Helpline',
                  number: '1091',
                  color: Colors.pink,
                ),
                _buildContactCard(
                  icon: Icons.medical_services,
                  title: 'Ambulance',
                  number: '102',
                  color: Colors.red,
                ),
                _buildContactCard(
                  icon: Icons.fire_extinguisher,
                  title: 'Fire Brigade',
                  number: '101',
                  color: Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Domestic Violence Support
            _buildSection(
              title: '⚖️ Domestic Violence Support',
              children: [
                _buildSupportCard(
                  title: 'Know Your Rights',
                  description:
                      'Learn about domestic violence laws and your legal rights.',
                  icon: Icons.gavel,
                  color: Colors.purple,
                  onTap: () {
                    _showLegalRights(context);
                  },
                ),
                _buildSupportCard(
                  title: 'Protection Orders',
                  description:
                      'Information about obtaining a protection order.',
                  icon: Icons.shield,
                  color: Colors.blue,
                  onTap: () {
                    _showProtectionOrders(context);
                  },
                ),
                _buildSupportCard(
                  title: 'Support Organizations',
                  description: 'Find nearby organizations that can help.',
                  icon: Icons.handshake,
                  color: Colors.green,
                  onTap: () {
                    _showOrganizations(context);
                  },
                ),
                _buildSupportCard(
                  title: 'Safety Planning',
                  description: 'Create a personalized safety plan.',
                  icon: Icons.assignment,
                  color: Colors.orange,
                  onTap: () {
                    _showSafetyPlanning(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Mental Health Support
            _buildSection(
              title: '🧠 Mental Health Support',
              children: [
                _buildSupportCard(
                  title: 'Crisis Helpline',
                  description: '24/7 mental health support',
                  icon: Icons.support_agent,
                  color: Colors.teal,
                  onTap: () {
                    _makePhoneCall('1098'); // Childline/Helpline
                  },
                ),
                _buildSupportCard(
                  title: 'Counseling Services',
                  description: 'Find professional counseling near you',
                  icon: Icons.psychology,
                  color: Colors.indigo,
                  onTap: () {
                    // Show counseling services
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String number,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(number),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.phone, color: Colors.green),
              onPressed: () => _makePhoneCall(number),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }

  Future<void> _makePhoneCall(String number) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      print('Cannot make phone call to $number');
    }
  }

  void _showLegalRights(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your Legal Rights'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Key Legal Rights:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Right to live with dignity and safety'),
              Text('• Right to protection from domestic violence'),
              Text('• Right to file a complaint at any police station'),
              Text('• Right to get a protection order'),
              Text('• Right to compensation under law'),
              SizedBox(height: 12),
              Text(
                'Laws Protecting Women:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Protection of Women from Domestic Violence Act, 2005'),
              Text('• Indian Penal Code, Section 498A'),
              Text('• Dowry Prohibition Act, 1961'),
              Text('• Sexual Harassment at Workplace Act, 2013'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showProtectionOrders(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Protection Orders'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Types of Protection Orders:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Protection Order - Prevents harassment'),
              Text('2. Residence Order - Right to stay in shared household'),
              Text('3. Monetary Relief - Financial compensation'),
              Text('4. Custody Order - Child custody rights'),
              SizedBox(height: 12),
              Text(
                'How to Get a Protection Order:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. File application at the nearest court'),
              Text('2. Present evidence and witnesses'),
              Text('3. Get temporary protection order'),
              Text('4. Get permanent protection order after hearing'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showOrganizations(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Support Organizations'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'National Helplines:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Women Helpline: 1091'),
              Text('• Police: 100'),
              Text('• Childline: 1098'),
              Text('• Ambulance: 102'),
              SizedBox(height: 12),
              Text(
                'Organizations:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• National Commission for Women'),
              Text('• Sakshi - Violence Intervention Center'),
              Text('• Women\'s Rights Initiative'),
              Text('• Snehi - Crisis Intervention Center'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSafetyPlanning(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Safety Planning'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Personal Safety Plan:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('1. Identify safe places to go'),
              Text('2. Prepare an emergency bag'),
              Text('3. Memorize important phone numbers'),
              Text('4. Create a code word with family'),
              Text('5. Keep important documents ready'),
              SizedBox(height: 12),
              Text(
                'During an Emergency:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Call emergency helpline immediately'),
              Text('• Stay in a public place if possible'),
              Text('• Use the SOS button on your phone'),
              Text('• Share your location with trusted contacts'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
