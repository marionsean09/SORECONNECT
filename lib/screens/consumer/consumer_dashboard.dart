import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soreconnect/screens/consumer/consumer_bill_screen.dart';
import 'package:soreconnect/screens/consumer/consumer_report_screen.dart';
import 'package:soreconnect/screens/complaints/submit_complaint_screen.dart';
import 'package:soreconnect/screens/announcements/view_announcements_screen.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';

class ConsumerDashboard extends StatelessWidget {
  const ConsumerDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consumer Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
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
                        color: const Color(0xFFDAA520).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.person_outline, color: Color(0xFFDAA520), size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Welcome, ${user?.email ?? 'Consumer'}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                          const SizedBox(height: 4),
                          const Text('Role: CONSUMER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('SERVICES', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20), letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _buildActionCard(
                context: context,
                icon: Icons.receipt_long,
                iconColor: const Color(0xFF2E7D32),
                title: 'View Bills',
                subtitle: 'Check your billing history and due dates.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsumerBillScreen())),
              ),
              _buildActionCard(
                context: context,
                icon: Icons.pie_chart,
                iconColor: const Color(0xFF6A1B9A),
                title: 'SORECO 1 Collections Report',
                subtitle: 'View monthly and yearly collected totals.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConsumerReportScreen())),
              ),
              _buildActionCard(
                context: context,
                icon: Icons.report_problem,
                iconColor: const Color(0xFFEF6C00),
                title: 'Submit Complaint & Track',
                subtitle: 'Report issues and track service concerns.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubmitComplaintScreen())),
              ),
              _buildActionCard(
                context: context,
                icon: Icons.campaign,
                iconColor: const Color(0xFF1565C0),
                title: 'Announcements',
                subtitle: 'Stay updated on notices and news.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewAnnouncementsScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
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
}
