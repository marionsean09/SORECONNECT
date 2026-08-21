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
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) return;
          if (index == 4) {
            showModalBottomSheet<void>(
              context: context,
              builder: (context) => SafeArea(
                child: Wrap(
                  children: [
                    ListTile(leading: const Icon(Icons.electric_bolt), title: const Text('Rate Management'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const RateManagementScreen())); }),
                    ListTile(leading: const Icon(Icons.campaign), title: const Text('Post Announcements'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const PostAnnouncementScreen())); }),
                    ListTile(leading: const Icon(Icons.announcement), title: const Text('View Announcements'), onTap: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewAnnouncementsScreen())); }),
                  ],
                ),
              ),
            );
            return;
          }
          final destinations = [
            const DirectorDashboard(),
            const MonitorBillsScreen(),
            const MonitorComplaintsScreen(),
            const MonitorReportsScreen(),
          ];
          Navigator.push(context, MaterialPageRoute(builder: (_) => destinations[index]));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Bills'),
          BottomNavigationBarItem(icon: Icon(Icons.report_problem), label: 'Complaints'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Reports'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}