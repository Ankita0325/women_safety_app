import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: const Color(0xFFFF4081),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF4081), Color(0xFFC2185B)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Color(0xFFFF4081),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Demo User',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    'demo@women-safety.app',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '+91 9876543210',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Profile Menu
            Card(
              elevation: 2,
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.people,
                    title: 'Emergency Contacts',
                    onTap: () {
                      // Navigate to emergency contacts
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.history,
                    title: 'Emergency History',
                    onTap: () {
                      // Navigate to history
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.notifications,
                    title: 'Notifications',
                    onTap: () {
                      // Navigate to notifications
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.settings,
                    title: 'Settings',
                    onTap: () {
                      // Navigate to settings
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.help,
                    title: 'Help & Support',
                    onTap: () {
                      // Navigate to help
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.privacy_tip,
                    title: 'Privacy Policy',
                    onTap: () {
                      // Show privacy policy
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/home');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Back to Home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4081),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFFFF4081)),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
