import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soreconnect/screens/teller/generate_reports_screen.dart';
import 'package:soreconnect/screens/teller/verify_meter_readings_screen.dart';
import 'package:soreconnect/screens/complaints/manage_complaints_screen.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';

class TellerDashboard extends StatefulWidget {
  const TellerDashboard({super.key});

  @override
  State<TellerDashboard> createState() => _TellerDashboardState();
}

class _TellerDashboardState extends State<TellerDashboard> {
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
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teller Dashboard'),
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
                      child: const Icon(Icons.account_balance, color: _accentGold, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome, ${user?.email ?? 'Teller'}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryGreen)),
                          const SizedBox(height: 4),
                          const Text('Role: TELLER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
                          const SizedBox(height: 4),
                          const Text('Verify readings, generate bills, and support service requests.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('TASKS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryGreen, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              _buildActionCard(
                icon: Icons.verified,
                iconColor: const Color(0xFF2E7D32),
                title: 'Verify Meter Readings',
                subtitle: 'Review pending readings and generate official bills.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const VerifyMeterReadingsScreen())),
              ),
              _buildActionCard(
                icon: Icons.assessment,
                iconColor: const Color(0xFF1976D2),
                title: 'Generate Reports',
                subtitle: 'Create monthly and yearly billing summaries.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GenerateReportScreen())),
              ),
              _buildActionCard(
                icon: Icons.manage_accounts,
                iconColor: const Color(0xFFDAA520),
                title: 'Manage Complaints',
                subtitle: 'Review and respond to consumer complaints.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ManageComplaintsScreen())),
              ),
            ],
          ),
        ),
      ),
    );
  }
}