import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:soreconnect/screens/meter_reader/meter_reading_screen.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';

class MeterReaderDashboard extends StatefulWidget {
  const MeterReaderDashboard({super.key});

  @override
  State<MeterReaderDashboard> createState() => _MeterReaderDashboardState();
}

class _MeterReaderDashboardState extends State<MeterReaderDashboard> {
  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _accentGold = Color(0xFFDAA520);
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _logout() async {
    await _auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meter Reader Dashboard'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meter Reader Dashboard', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryGreen)),
                    const SizedBox(height: 6),
                    const Text('Submit meter readings and track assignments.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildActionCard(
                icon: Icons.edit,
                iconColor: const Color(0xFF1976D2),
                title: 'Record Reading',
                subtitle: 'Log meter readings for assigned consumers.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MeterReadingScreen())),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: _accentGold),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text('Meter readers record readings that are reviewed by the teller before the official bill is generated.', style: TextStyle(fontSize: 13, color: Color(0xFF2E7D32))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}