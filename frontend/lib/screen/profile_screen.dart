import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  bool _showHistory = false;
  String _selectedFilter = 'All';

  // Color palette
  static const Color primaryDark = Color(0xFF0A0915);
  static const Color appBackgroundStart = Color(0xFF121026);
  static const Color appBackgroundEnd = Color(0xFF161330);
  static const Color cardBackground = Color(0xFF1E1B4B);
  static const Color vibrantPink = Color(0xFFD92662);
  static const Color vibrantPinkLight = Color(0xFFE11D48);
  static const Color purpleAccent = Color(0xFF7C3AED);
  static const Color purpleAccentLight = Color(0xFF6366F1);
  static const Color highRiskRed = Color(0xFFEF4444);
  static const Color mediumRiskOrange = Color(0xFFF59E0B);
  static const Color lowRiskGreen = Color(0xFF10B981);
  static const Color primaryText = Color(0xFFFFFFFF);
  static const Color secondaryText = Color(0xFF9CA3AF);
  static const Color mutedBlue = Color(0xFFA5B4FC);

  // User data
  final Map<String, dynamic> _userData = {
    'name': 'Riya Sharma',
    'email': 'riya.sharma@email.com',
    'phone': '+91 98765 43210',
    'safetyScore': 82,
    'joinDate': 'January 2024',
    'location': 'Mumbai, India',
    'trustedContacts': 5,
    'reports': 12,
    'sosActive': 0,
    'safeRoutes': 47,
    'aiDetections': 23,
    'communityHelp': 8,
  };

  // History data with more entries
  final List<Map<String, dynamic>> _historyData = [
    {
      'type': 'SOS Alert',
      'location': 'Andheri East, Mumbai',
      'time': 'Today, 2:30 PM',
      'status': 'Resolved',
      'icon': Icons.sos,
      'color': highRiskRed,
      'details': 'Emergency alert triggered • Police dispatched',
    },
    {
      'type': 'Safe Route Navigation',
      'location': 'Bandra to Andheri',
      'time': 'Today, 10:15 AM',
      'status': 'Completed',
      'icon': Icons.route,
      'color': lowRiskGreen,
      'details': 'AI recommended safe route • 15 min saved',
    },
    {
      'type': 'Community Report',
      'location': 'Juhu Beach Area',
      'time': 'Yesterday, 6:45 PM',
      'status': 'Pending Review',
      'icon': Icons.flag,
      'color': mediumRiskOrange,
      'details': 'Unsafe area reported • 5 community members confirmed',
    },
    {
      'type': 'AI Voice Detection',
      'location': 'Home',
      'time': 'Yesterday, 9:20 AM',
      'status': 'Active',
      'icon': Icons.mic,
      'color': purpleAccent,
      'details': 'Suspicious voice detected • Recording saved',
    },
    {
      'type': 'Location Shared',
      'location': 'Andheri Station',
      'time': 'Jan 15, 8:00 PM',
      'status': 'Delivered',
      'icon': Icons.location_on,
      'color': mutedBlue,
      'details': 'Live location shared with 5 trusted contacts',
    },
    {
      'type': 'Emergency Contact Added',
      'location': 'Mother',
      'time': 'Jan 14, 3:15 PM',
      'status': 'Active',
      'icon': Icons.contact_emergency,
      'color': lowRiskGreen,
      'details': 'New emergency contact added to network',
    },
    {
      'type': 'Safety Tip Viewed',
      'location': 'App',
      'time': 'Jan 13, 11:00 AM',
      'status': 'Viewed',
      'icon': Icons.lightbulb,
      'color': mediumRiskOrange,
      'details': 'Read: "Self-defense techniques for women"',
    },
    {
      'type': 'Heatmap Check',
      'location': 'South Mumbai',
      'time': 'Jan 12, 7:30 PM',
      'status': 'Safe',
      'icon': Icons.heat_pump,
      'color': lowRiskGreen,
      'details': 'Area marked safe • 90% safety rating',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return Scaffold(
      backgroundColor: appBackgroundStart,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              appBackgroundStart,
              appBackgroundEnd,
              primaryDark,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _showHistory 
                    ? _buildHistoryView() 
                    : _buildProfileView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.arrow_back_ios, color: primaryText),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Text(
            _showHistory ? 'Safety History' : 'My Profile',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          const Spacer(),
          if (!_showHistory)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: lowRiskGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: lowRiskGreen.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: lowRiskGreen,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: lowRiskGreen.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Protected',
                    style: TextStyle(
                      color: lowRiskGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildSafetyScoreCard(),
          const SizedBox(height: 20),
          _buildQuickStatsGrid(),
          const SizedBox(height: 20),
          _buildProfileDetails(),
          const SizedBox(height: 20),
          _buildQuickActions(),
          const SizedBox(height: 20),
          _buildCommunityStats(),
          const SizedBox(height: 20),
          _buildLogoutButton(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1 + (0.03 * sin(_pulseController.value * 2 * pi)),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [vibrantPink, vibrantPinkLight, purpleAccent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: vibrantPink.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: cardBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: vibrantPink, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: vibrantPink,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _userData['name']!,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryText,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified, color: lowRiskGreen, size: 16),
              const SizedBox(width: 4),
              Text(
                'Verified User',
                style: TextStyle(
                  color: lowRiskGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: secondaryText.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today, color: mutedBlue, size: 14),
                const SizedBox(width: 6),
                Text(
                  'Member since ${_userData['joinDate']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyScoreCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardBackground.withOpacity(0.8),
            purpleAccent.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: purpleAccent.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: vibrantPink.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Safety Score',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: lowRiskGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.trending_up, color: lowRiskGreen, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Good',
                      style: TextStyle(
                        color: lowRiskGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_userData['safetyScore']}',
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '/ 100',
                            style: TextStyle(
                              fontSize: 16,
                              color: secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: lowRiskGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Higher than average',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildScoreIndicator('AI Detection', 90, lowRiskGreen),
                    const SizedBox(height: 8),
                    _buildScoreIndicator('SOS Response', 75, mediumRiskOrange),
                    const SizedBox(height: 8),
                    _buildScoreIndicator('Community Trust', 85, lowRiskGreen),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _userData['safetyScore'] / 100,
              backgroundColor: cardBackground,
              valueColor: AlwaysStoppedAnimation(vibrantPink),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreIndicator(String label, int score, Color color) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: secondaryText,
          ),
        ),
        const Spacer(),
        Text(
          '$score%',
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildStatCard(
          icon: Icons.contacts,
          label: 'Trusted\nContacts',
          value: '${_userData['trustedContacts']}',
          color: purpleAccent,
          subtitle: 'Active',
        ),
        _buildStatCard(
          icon: Icons.flag,
          label: 'Reports',
          value: '${_userData['reports']}',
          color: mediumRiskOrange,
          subtitle: 'Pending: 3',
        ),
        _buildStatCard(
          icon: Icons.route,
          label: 'Safe\nRoutes',
          value: '${_userData['safeRoutes']}',
          color: lowRiskGreen,
          subtitle: 'Today: 2',
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 9,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ FIXED: removed 'const' from Divider widgets that use .withOpacity()
  Widget _buildProfileDetails() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryText.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildDetailRow(Icons.phone, 'Phone', _userData['phone'], Icons.copy),
          Divider(color: secondaryText.withOpacity(0.1), height: 1), // ✅ const removed
          _buildDetailRow(Icons.email, 'Email', _userData['email'], null),
          Divider(color: secondaryText.withOpacity(0.1), height: 1), // ✅ const removed
          _buildDetailRow(Icons.location_city, 'Location', _userData['location'], null),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, IconData? actionIcon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: purpleAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: purpleAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryText,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: primaryText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (actionIcon != null)
            IconButton(
              onPressed: () {
                // Copy to clipboard
              },
              icon: Icon(actionIcon, color: secondaryText, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Widget _buildCommunityStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cardBackground.withOpacity(0.8),
            vibrantPink.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: vibrantPink.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.people, color: vibrantPink, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Community Impact',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildImpactItem('AI Detections', '${_userData['aiDetections']}', purpleAccent),
              ),
              Expanded(
                child: _buildImpactItem('Community Help', '${_userData['communityHelp']}', lowRiskGreen),
              ),
              Expanded(
                child: _buildImpactItem('SOS Active', '${_userData['sosActive']}', highRiskRed),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpactItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _buildActionButton(
          icon: Icons.history,
          label: 'History',
          color: purpleAccent,
          onTap: () {
            setState(() {
              _showHistory = true;
            });
          },
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          icon: Icons.edit,
          label: 'Edit',
          color: vibrantPink,
          onTap: () {
            // Navigate to edit profile
          },
        ),
        const SizedBox(width: 12),
        _buildActionButton(
          icon: Icons.settings,
          label: 'Settings',
          color: mutedBlue,
          onTap: () {
            // Navigate to settings
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          _showLogoutDialog();
        },
        icon: const Icon(Icons.logout, color: highRiskRed),
        label: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 16,
            color: highRiskRed,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: highRiskRed.withOpacity(0.3)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: cardBackground,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: secondaryText.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedFilter,
                      style: const TextStyle(color: primaryText),
                      dropdownColor: cardBackground,
                      isExpanded: true,
                      items: ['All', 'SOS Alerts', 'Safe Routes', 'Reports', 'Voice Detection', 'Location']
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedFilter = value!;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showHistory = false;
                  });
                },
                icon: const Icon(Icons.close, color: secondaryText),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _historyData.length,
            itemBuilder: (context, index) {
              final item = _historyData[index];
              return _buildHistoryItem(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: secondaryText.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: (item['color'] as Color).withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (item['color'] as Color).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item['icon'] as IconData,
              color: item['color'] as Color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['type']!,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.location_on, color: secondaryText, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      item['location']!,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item['details']!,
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryText.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item['status']!,
                  style: TextStyle(
                    fontSize: 10,
                    color: item['color'] as Color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item['time']!,
                style: TextStyle(
                  fontSize: 10,
                  color: secondaryText.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.logout, color: highRiskRed),
            const SizedBox(width: 8),
            const Text(
              'Logout',
              style: TextStyle(color: primaryText),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to logout?\nYour safety data will remain secure.',
          style: TextStyle(color: secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: secondaryText,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: highRiskRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }
}