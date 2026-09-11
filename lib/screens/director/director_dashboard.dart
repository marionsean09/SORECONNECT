import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // ============================================================
  // REPORT FILTER
  // ============================================================

  String _reportType = 'Monthly';

  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  final List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await _auth.signOut();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        ),
      );
    }
  }

  // ============================================================
  // BILL PERIOD FILTER
  //
  // Uses generatedAt
  // ============================================================

  bool _isBillWithinSelectedPeriod(Timestamp? timestamp) {
    if (timestamp == null) {
      return false;
    }

    final date = timestamp.toDate();

    if (_reportType == 'Monthly') {
      return date.year == _selectedYear &&
          date.month == _selectedMonth;
    }

    return date.year == _selectedYear;
  }

  // ============================================================
  // GET COMPLAINT DATE
  //
  // Supports:
  // createdAt
  // dateSubmitted
  // submittedAt
  // ============================================================

  DateTime? _getComplaintDate(
    Map<String, dynamic> data,
  ) {
    final value =
        data['createdAt'] ??
        data['dateSubmitted'] ??
        data['submittedAt'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // COMPLAINT PERIOD FILTER
  // ============================================================

  bool _isComplaintWithinSelectedPeriod(
    Map<String, dynamic> data,
  ) {
    final date = _getComplaintDate(data);

    if (date == null) {
      return false;
    }

    if (_reportType == 'Monthly') {
      return date.year == _selectedYear &&
          date.month == _selectedMonth;
    }

    return date.year == _selectedYear;
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: color,
              size: 26,
            ),

            const SizedBox(height: 8),

            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text('Director Dashboard'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ==================================================
              // WELCOME CARD
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accentGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: _accentGold,
                        size: 30,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [

                          Text(
                            'Welcome, ${user?.email ?? 'Director'}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryGreen,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Role: DIRECTOR',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Monitor operations and keep the cooperative running smoothly.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // MONTHLY / YEARLY FILTER
              // ==================================================

              Row(
                children: [

                  // VIEW
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _reportType,
                      decoration: const InputDecoration(
                        labelText: 'View',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: 'Yearly',
                          child: Text('Yearly'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _reportType =
                              value ?? 'Monthly';
                        });
                      },
                    ),
                  ),

                  const SizedBox(width: 10),

                  // MONTH
                  if (_reportType == 'Monthly')
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedMonth,
                        decoration: const InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: List.generate(
                          12,
                          (index) {
                            return DropdownMenuItem<int>(
                              value: index + 1,
                              child: Text(
                                _months[index],
                              ),
                            );
                          },
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedMonth =
                                value ??
                                DateTime.now().month;
                          });
                        },
                      ),
                    ),

                  if (_reportType == 'Monthly')
                    const SizedBox(width: 10),

                  // YEAR
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedYear,
                      decoration: const InputDecoration(
                        labelText: 'Year',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: List.generate(
                        5,
                        (index) {
                          final year =
                              DateTime.now().year -
                              2 +
                              index;

                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text(
                              year.toString(),
                            ),
                          );
                        },
                      ),
                      onChanged: (value) {
                        setState(() {
                          _selectedYear =
                              value ??
                              DateTime.now().year;
                        });
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ==================================================
              // BILLS SUMMARY
              // ==================================================

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bills')
                    .snapshots(),

                builder: (
                  context,
                  billSnapshot,
                ) {
                  if (!billSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final bills =
                      billSnapshot.data!.docs.where(
                    (doc) {
                      final data =
                          doc.data()
                              as Map<String, dynamic>;

                      return _isBillWithinSelectedPeriod(
                        data['generatedAt']
                            as Timestamp?,
                      );
                    },
                  ).toList();

                  // TOTAL BILLS
                  final totalBills =
                      bills.length;

                  // PAID BILLS
                  final paidBills =
                      bills.where((doc) {
                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final status =
                        (data['status'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();

                    return status == 'paid';
                  }).length;

                  // UNPAID BILLS
                  final unpaidBills =
                      bills.where((doc) {
                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final status =
                        (data['status'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();

                    return status != 'paid';
                  }).length;

                  // TOTAL REVENUE
                  //
                  // ONLY PAID BILLS
                  // ARE INCLUDED
                  //

                  double totalRevenue = 0;

                  for (final doc in bills) {
                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final status =
                        (data['status'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();

                    if (status == 'paid') {
                      totalRevenue +=
                          (data['totalAmount']
                                      as num? ??
                                  0)
                              .toDouble();
                    }
                  }

                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      const Text(
                        'Bills Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ------------------------------------------
                      // TOTAL / PAID / UNPAID
                      // ------------------------------------------

                      Row(
                        children: [

                          _summaryCard(
                            title: 'Total Bills',
                            value:
                                totalBills.toString(),
                            icon:
                                Icons.receipt_long,
                            color:
                                _primaryGreen,
                          ),

                          const SizedBox(width: 10),

                          _summaryCard(
                            title: 'Paid',
                            value:
                                paidBills.toString(),
                            icon:
                                Icons.check_circle,
                            color:
                                Colors.green,
                          ),

                          const SizedBox(width: 10),

                          _summaryCard(
                            title: 'Unpaid',
                            value:
                                unpaidBills.toString(),
                            icon:
                                Icons.pending_actions,
                            color:
                                Colors.orange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ------------------------------------------
                      // TOTAL REVENUE
                      // ------------------------------------------

                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFE8F5E9),
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [

                            const Icon(
                              Icons.payments,
                              color:
                                  _primaryGreen,
                              size: 30,
                            ),

                            const SizedBox(width: 12),

                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [

                                const Text(
                                  'Total Revenue',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color:
                                        Colors.grey,
                                  ),
                                ),

                                Text(
                                  '₱${totalRevenue.toStringAsFixed(2)}',
                                  style:
                                      const TextStyle(
                                    fontSize: 24,
                                    fontWeight:
                                        FontWeight.bold,
                                    color:
                                        _primaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // ==================================================
              // COMPLAINTS SUMMARY
              // ==================================================

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaints')
                    .snapshots(),

                builder: (
                  context,
                  complaintSnapshot,
                ) {
                  if (!complaintSnapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  // FILTER COMPLAINTS
                  final complaints =
                      complaintSnapshot
                          .data!
                          .docs
                          .where((doc) {
                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    return _isComplaintWithinSelectedPeriod(
                      data,
                    );
                  }).toList();

                  // TOTAL
                  final totalComplaints =
                      complaints.length;

                  // PENDING
                  final pendingComplaints =
                      complaints.where((doc) {
                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final status =
                        (data['status'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();

                    return status == 'pending';
                  }).length;

                  // IN PROGRESS
                  final inProgressComplaints =
                      complaints.where((doc) {
                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final status =
                        (data['status'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();

                    return status == 'in progress' ||
                        status == 'in_progress' ||
                        status == 'inprogress';
                  }).length;

                  // RESOLVED
                  final resolvedComplaints =
                      complaints.where((doc) {
                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final status =
                        (data['status'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();

                    return status == 'resolved';
                  }).length;

                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      const Text(
                        'Complaints Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ------------------------------------------
                      // TOTAL + PENDING
                      // ------------------------------------------

                      Row(
                        children: [

                          _summaryCard(
                            title:
                                'Total Complaints',
                            value:
                                totalComplaints
                                    .toString(),
                            icon:
                                Icons.report_problem,
                            color:
                                Colors.red,
                          ),

                          const SizedBox(width: 10),

                          _summaryCard(
                            title: 'Pending',
                            value:
                                pendingComplaints
                                    .toString(),
                            icon:
                                Icons.pending,
                            color:
                                Colors.orange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ------------------------------------------
                      // IN PROGRESS + RESOLVED
                      // ------------------------------------------

                      Row(
                        children: [

                          _summaryCard(
                            title: 'In Progress',
                            value:
                                inProgressComplaints
                                    .toString(),
                            icon:
                                Icons.autorenew,
                            color:
                                Colors.blue,
                          ),

                          const SizedBox(width: 10),

                          _summaryCard(
                            title: 'Resolved',
                            value:
                                resolvedComplaints
                                    .toString(),
                            icon:
                                Icons.task_alt,
                            color:
                                Colors.green,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),

      // ========================================================
      // DIRECTOR BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar:
          BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,

        onTap: (index) {

          // HOME
          if (index == 0) {
            return;
          }

          // MORE
          if (index == 4) {
            showModalBottomSheet<void>(
              context: context,
              builder: (context) {
                return SafeArea(
                  child: Wrap(
                    children: [

                      // RATE MANAGEMENT
                      ListTile(
                        leading: const Icon(
                          Icons.electric_bolt,
                        ),
                        title: const Text(
                          'Rate Management',
                        ),
                        onTap: () {
                          Navigator.pop(context);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const RateManagementScreen(),
                            ),
                          );
                        },
                      ),

                      // POST ANNOUNCEMENT
                      ListTile(
                        leading: const Icon(
                          Icons.campaign,
                        ),
                        title: const Text(
                          'Post Announcements',
                        ),
                        onTap: () {
                          Navigator.pop(context);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const PostAnnouncementScreen(),
                            ),
                          );
                        },
                      ),

                      // VIEW ANNOUNCEMENTS
                      ListTile(
                        leading: const Icon(
                          Icons.announcement,
                        ),
                        title: const Text(
                          'View Announcements',
                        ),
                        onTap: () {
                          Navigator.pop(context);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ViewAnnouncementsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );

            return;
          }

          // DIRECTOR DESTINATIONS
          final destinations = [
            const DirectorDashboard(),
            const MonitorBillsScreen(),
            const MonitorComplaintsScreen(),
            const MonitorReportsScreen(),
          ];

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => destinations[index],
            ),
          );
        },

        items: const [

          BottomNavigationBarItem(
            icon: Icon(
              Icons.home_outlined,
            ),
            label: 'Home',
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.receipt_long,
            ),
            label: 'Bills',
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.report_problem,
            ),
            label: 'Complaints',
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.bar_chart,
            ),
            label: 'Reports',
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.more_horiz,
            ),
            label: 'More',
          ),
        ],
      ),
    );
  }
}