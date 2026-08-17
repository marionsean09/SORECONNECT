import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soreconnect/screens/director/monitor_bills_screen.dart';
import 'package:soreconnect/screens/director/monitor_complaints_screen.dart';
import 'package:soreconnect/screens/director/monitor_reports_screen.dart';
import 'package:soreconnect/screens/director/rate_management_screen.dart';
import 'package:soreconnect/screens/announcements/post_announcement_screen.dart';
import 'package:soreconnect/screens/announcements/view_announcements_screen.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';

class DirectorDashboard extends StatefulWidget {
  const DirectorDashboard({super.key});

  @override
  State<DirectorDashboard> createState() => _DirectorDashboardState();
}

class _DirectorDashboardState extends State<DirectorDashboard> {
  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _accentGold = Color(0xFFDAA520);
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Director Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 6)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accentGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.admin_panel_settings, color: _accentGold, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome, ${user?.email ?? 'Director'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryGreen)),
                          const SizedBox(height: 4),
                          const Text('Role: DIRECTOR', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                          const SizedBox(height: 4),
                          const Text('Monitor operations and keep the cooperative running smoothly.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('MONITORING', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryGreen, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.receipt_long,
                iconColor: const Color(0xFF2E7D32),
                title: 'Monitor Bills',
                subtitle: 'Review billing transactions and payment records.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonitorBillsScreen())),
              ),
              _buildActionCard(
                icon: Icons.report_problem,
                iconColor: const Color(0xFFEF6C00),
                title: 'Monitor Complaints',
                subtitle: 'Track and follow up on consumer complaints.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonitorComplaintsScreen())),
              ),
              _buildActionCard(
                icon: Icons.bar_chart,
                iconColor: const Color(0xFF1976D2),
                title: 'Monitor Reports',
                subtitle: 'Review monthly and yearly summaries.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MonitorReportsScreen())),
              ),
              const SizedBox(height: 20),
              const Text('OPERATIONS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryGreen, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.electric_bolt,
                iconColor: const Color(0xFFDAA520),
                title: 'Rate Management',
                subtitle: 'Adjust the official electricity rate.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RateManagementScreen())),
              ),
              _buildActionCard(
                icon: Icons.campaign,
                iconColor: const Color(0xFF1565C0),
                title: 'Post Announcements',
                subtitle: 'Share updates with consumers.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostAnnouncementScreen())),
              ),
              _buildActionCard(
                icon: Icons.announcement,
                iconColor: _primaryGreen,
                title: 'View Announcements',
                subtitle: 'Read all published announcements.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewAnnouncementsScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}