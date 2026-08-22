import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // Uses generatedAt
  // ============================================================

  bool _isBillWithinSelectedPeriod(Timestamp? timestamp) {
    if (timestamp == null) return false;

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
              color: Colors.black.withOpacity(0.06),
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),

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
              // HEADER
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
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
                        color: _accentGold.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),

                      child: const Icon(
                        Icons.person,
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
                            'Welcome, ${user?.email ?? 'Teller'}',

                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryGreen,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Role: TELLER',

                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Verify readings, generate bills, and support service requests.',

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

                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _reportType,

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

                  if (_reportType == 'Monthly')
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedMonth,

                        decoration: const InputDecoration(
                          labelText: 'Month',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),

                        items: List.generate(
                          12,
                          (index) {
                            return DropdownMenuItem(
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

                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _selectedYear,

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

                          return DropdownMenuItem(
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
              // BILLS STREAM
              //
              // TOTAL REVENUE:
              // ONLY PAID BILLS ARE INCLUDED
              // ==================================================

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('bills')
                    .snapshots(),

                builder: (context, billSnapshot) {

                  if (!billSnapshot.hasData) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
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

                  final totalBills = bills.length;

                  // PAID BILLS

                  final paidBills =
                      bills.where((doc) {

                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final status =
                        (data['status'] ?? '')
                            .toString()
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
                            .toLowerCase();

                    return status != 'paid';

                  }).length;

                  // ============================================
                  // TOTAL REVENUE
                  //
                  // KEEPING YOUR ORIGINAL CORRECT COMPUTATION
                  // ONLY PAID BILLS ARE INCLUDED
                  // ============================================

                  double totalRevenue = 0;

                  for (final doc in bills) {
                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    final status =
                        (data['status'] ?? '')
                            .toString()
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
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [

                          _summaryCard(
                            title: 'Total Bills',
                            value:
                                totalBills.toString(),
                            icon:
                                Icons.receipt_long,
                            color: _primaryGreen,
                          ),

                          const SizedBox(width: 10),

                          _summaryCard(
                            title: 'Paid',
                            value:
                                paidBills.toString(),
                            icon:
                                Icons.check_circle,
                            color: Colors.green,
                          ),

                          const SizedBox(width: 10),

                          _summaryCard(
                            title: 'Unpaid',
                            value:
                                unpaidBills.toString(),
                            icon:
                                Icons.pending_actions,
                            color: Colors.orange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(18),

                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFE8F5E9),
                          borderRadius:
                              BorderRadius.circular(
                                  14),
                        ),

                        child: Row(
                          children: [

                            const Icon(
                              Icons.payments,
                              color: _primaryGreen,
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
                                    color: Colors.grey,
                                  ),
                                ),

                                Text(
                                  '₱${totalRevenue.toStringAsFixed(2)}',

                                  style: const TextStyle(
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
              // COMPLAINTS STREAM
              //
              // PENDING
              // IN PROGRESS
              // RESOLVED
              // ==================================================

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('complaints')
                    .snapshots(),

                builder:
                    (context, complaintSnapshot) {

                  if (!complaintSnapshot.hasData) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  // FILTER COMPLAINTS BY SELECTED
                  // MONTH / YEAR

                  final complaints =
                      complaintSnapshot.data!.docs
                          .where((doc) {

                    final data =
                        doc.data()
                            as Map<String, dynamic>;

                    return _isComplaintWithinSelectedPeriod(
                      data,
                    );

                  }).toList();

                  final totalComplaints =
                      complaints.length;

                  // ============================================
                  // PENDING COMPLAINTS
                  // ============================================

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

                  // ============================================
                  // IN PROGRESS COMPLAINTS
                  //
                  // Supports different formats:
                  // "In Progress"
                  // "in progress"
                  // "in_progress"
                  // "inprogress"
                  // ============================================

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

                  // ============================================
                  // RESOLVED COMPLAINTS
                  // ============================================

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
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ========================================
                      // FIRST ROW
                      // TOTAL + PENDING
                      // ========================================

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
                            color: Colors.red,
                          ),

                          const SizedBox(width: 10),

                          _summaryCard(
                            title: 'Pending',
                            value:
                                pendingComplaints
                                    .toString(),
                            icon:
                                Icons.pending,
                            color: Colors.orange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // ========================================
                      // SECOND ROW
                      // IN PROGRESS + RESOLVED
                      // ========================================

                      Row(
                        children: [

                          _summaryCard(
                            title: 'In Progress',
                            value:
                                inProgressComplaints
                                    .toString(),
                            icon:
                                Icons.autorenew,
                            color: Colors.blue,
                          ),

                          const SizedBox(width: 10),

                          _summaryCard(
                            title: 'Resolved',
                            value:
                                resolvedComplaints
                                    .toString(),
                            icon:
                                Icons.task_alt,
                            color: Colors.green,
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
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: 0,

        onTap: (index) {
          final destinations = [
            const TellerDashboard(),
            const VerifyMeterReadingsScreen(),
            const GenerateReportScreen(),
            ManageComplaintsScreen(),
          ];

          if (index != 0) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    destinations[index],
              ),
            );
          }
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.verified),
            label: 'Verify',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.assessment),
            label: 'Reports',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts),
            label: 'Complaints',
          ),
        ],
      ),
    );
  }
}