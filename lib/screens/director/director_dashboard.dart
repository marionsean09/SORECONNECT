import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:soreconnect/screens/director/monitor_bills_screen.dart';
import 'package:soreconnect/screens/director/monitor_complaints_screen.dart';
import 'package:soreconnect/screens/director/monitor_reports_screen.dart';
import 'package:soreconnect/screens/director/rate_management_screen.dart';

import 'package:soreconnect/screens/announcements/post_announcement_screen.dart';
import 'package:soreconnect/screens/announcements/view_announcements_screen.dart';

import 'package:soreconnect/screens/shared/staff_profile_screen.dart';
import 'package:soreconnect/utils/pending_email_guard.dart';
import 'package:soreconnect/widgets/minimal_filter_bar.dart';

// ============================================================
// DIRECTOR DASHBOARD (TAB SHELL)
//
// Hosts Home/Bills/Complaints/Reports as sibling pages in one
// PageView — see consumer_dashboard.dart for the full rationale
// (no back arrow, swipeable, each tab keeps its state alive).
//
// "More" stays a bottom sheet rather than becoming a 5th page:
// it's a menu that launches other screens (Rate Management, Post/
// View Announcements, My Profile), not a destination of its own,
// so turning it into a swipeable page would change what it does
// rather than just how you get there.
// ============================================================

class DirectorDashboard extends StatefulWidget {
  const DirectorDashboard({super.key});

  @override
  State<DirectorDashboard> createState() => _DirectorDashboardState();
}

class _DirectorDashboardState extends State<DirectorDashboard> {
  static const Color _primaryGreen = Color(0xFF1B5E20);

  // Strong ease-out — starts fast so a tapped tab feels immediate
  // rather than a generic linear/ease-in-out glide.
  static const Curve _tabCurve = Cubic(0.23, 1, 0.32, 1);

  late final PageController _pageController;
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _DirectorHomeTab(),
    MonitorBillsScreen(),
    MonitorComplaintsScreen(),
    MonitorReportsScreen(),
  ];

  @override
  void initState() {
    super.initState();

    _pageController = PageController();

    // Safety net: finishes signing out if an email change was
    // confirmed while this screen wasn't the one watching for it
    // (e.g. backed out of the verify screen, or the app was
    // backgrounded when the confirmation link was tapped).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkPendingEmailConfirmed(context);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToTab(int index) {
    if (index == _currentIndex) return;

    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: _tabCurve,
    );
  }

  void _handleNavTap(int index) {
    if (index == 4) {
      _showMoreMenu();
      return;
    }

    _goToTab(index);
  }

  void _showMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              // RATE MANAGEMENT
              ListTile(
                leading: const Icon(Icons.electric_bolt),
                title: const Text('Rate Management'),
                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RateManagementScreen(),
                    ),
                  );
                },
              ),

              // POST ANNOUNCEMENT
              ListTile(
                leading: const Icon(Icons.campaign),
                title: const Text('Post Announcements'),
                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PostAnnouncementScreen(),
                    ),
                  );
                },
              ),

              // VIEW ANNOUNCEMENTS
              ListTile(
                leading: const Icon(Icons.announcement),
                title: const Text('View Announcements'),
                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ViewAnnouncementsScreen(),
                    ),
                  );
                },
              ),

              // MY PROFILE
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('My Profile'),
                onTap: () {
                  Navigator.pop(context);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StaffProfileScreen(
                        role: 'Director',
                        userTypeValue: 'director',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        children: _pages,
      ),

      // ========================================================
      // DIRECTOR BOTTOM NAVIGATION
      // ========================================================
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: _primaryGreen,
        onTap: _handleNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Bills',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.report_problem),
            label: 'Complaints',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),

          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

// ============================================================
// HOME TAB
//
// Unchanged from the dashboard's previous single-screen body —
// only relocated here so it can live as its own PageView page
// with its own keep-alive state, same as every other tab.
// ============================================================

class _DirectorHomeTab extends StatefulWidget {
  const _DirectorHomeTab();

  @override
  State<_DirectorHomeTab> createState() => _DirectorHomeTabState();
}

class _DirectorHomeTabState extends State<_DirectorHomeTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _accentGold = Color(0xFFDAA520);

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
  // BRANCH
  //
  // Bills/complaints summaries are scoped to this director's own
  // branch, the same one Monitor Bills/Complaints locks to —
  // listened live so changing it in Profile updates these totals
  // immediately instead of leaving stale numbers from the old
  // branch on screen.
  // ============================================================

  String? _branchMunicipality;
  bool _branchLoading = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _branchSub;

  // Resolves a complaint's municipality when it isn't stored
  // directly on the complaint — keyed by consumer uid, since a
  // complaint only records the location itself when the consumer
  // attached one at submission time.
  final Map<String, String> _consumerMunicipalityCache = {};

  @override
  void initState() {
    super.initState();
    _listenToBranch();
  }

  @override
  void dispose() {
    _branchSub?.cancel();
    super.dispose();
  }

  void _listenToBranch() {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      if (mounted) setState(() => _branchLoading = false);
      return;
    }

    _branchSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
          (doc) {
            if (!mounted) return;

            final municipality = doc.data()?['municipality']?.toString();

            setState(() {
              _branchMunicipality =
                  (municipality != null && municipality.isNotEmpty)
                  ? municipality
                  : null;
              _branchLoading = false;
            });
          },
          onError: (e) {
            if (!mounted) return;
            setState(() => _branchLoading = false);
          },
        );
  }

  String _getBillMunicipality(Map<String, dynamic> data) {
    final value = data['municipality'] ?? data['city'];
    return (value ?? '').toString().trim();
  }

  // Complaints don't store a location at submission time, so this
  // falls back to the consumer's own profile municipality — cached
  // per consumer so repeated complaints from the same consumer
  // don't re-fetch it.
  Future<String> _getComplaintMunicipality(Map<String, dynamic> data) async {
    final direct =
        (data['municipality'] ??
                data['municipalityName'] ??
                data['city'] ??
                data['cityName'] ??
                '')
            .toString()
            .trim();

    if (direct.isNotEmpty) return direct;

    final consumerId =
        (data['consumerId'] ??
                data['consumerID'] ??
                data['uid'] ??
                data['userId'] ??
                data['consumerUID'] ??
                data['consumerUid'] ??
                '')
            .toString()
            .trim();

    if (consumerId.isEmpty) return '';

    if (_consumerMunicipalityCache.containsKey(consumerId)) {
      return _consumerMunicipalityCache[consumerId]!;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(consumerId)
          .get();

      final municipality = (userDoc.data()?['municipality'] ?? '')
          .toString()
          .trim();

      _consumerMunicipalityCache[consumerId] = municipality;

      return municipality;
    } catch (_) {
      return '';
    }
  }

  Future<List<QueryDocumentSnapshot>> _filterComplaintsByBranch(
    List<QueryDocumentSnapshot> docs,
  ) async {
    if (_branchMunicipality == null) return const [];

    final result = <QueryDocumentSnapshot>[];

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;

      final municipality = await _getComplaintMunicipality(data);

      if (municipality.toLowerCase() == _branchMunicipality!.toLowerCase()) {
        result.add(doc);
      }
    }

    return result;
  }

  // ============================================================
  // DATE FILTER FIELD (label + minimal dropdown)
  // ============================================================

  Widget _dateFilterField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
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
      return date.year == _selectedYear && date.month == _selectedMonth;
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

  DateTime? _getComplaintDate(Map<String, dynamic> data) {
    final value =
        data['createdAt'] ?? data['dateSubmitted'] ?? data['submittedAt'];

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

  bool _isComplaintWithinSelectedPeriod(Map<String, dynamic> data) {
    final date = _getComplaintDate(data);

    if (date == null) {
      return false;
    }

    if (_reportType == 'Monthly') {
      return date.year == _selectedYear && date.month == _selectedMonth;
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
            Icon(icon, color: color, size: 26),

            const SizedBox(height: 8),

            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 4),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
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
    super.build(context);

    return Scaffold(
      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/soreco_logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'SORECONNECT',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WELCOME, DIRECTOR',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _primaryGreen,
                            ),
                          ),

                          const SizedBox(height: 4),

                          const Text(
                            'Monitor operations and keep the cooperative running smoothly.',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // DATE FILTER (View / Month / Year)
              // ==================================================
              Row(
                children: [
                  Expanded(
                    child: _dateFilterField(
                      label: 'View',
                      child: MinimalDropdown<String>(
                        value: _reportType,
                        items: const ['Monthly', 'Yearly'],
                        itemLabel: (value) => value,
                        fullWidth: true,
                        onChanged: (value) {
                          setState(() {
                            _reportType = value ?? 'Monthly';
                          });
                        },
                      ),
                    ),
                  ),

                  if (_reportType == 'Monthly') ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _dateFilterField(
                        label: 'Month',
                        child: MinimalDropdown<int>(
                          value: _selectedMonth,
                          items: List.generate(12, (i) => i + 1),
                          itemLabel: (value) => _months[value - 1],
                          fullWidth: true,
                          onChanged: (value) {
                            setState(() {
                              _selectedMonth = value ?? DateTime.now().month;
                            });
                          },
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(width: 10),

                  Expanded(
                    child: _dateFilterField(
                      label: 'Year',
                      child: MinimalDropdown<int>(
                        value: _selectedYear,
                        items: List.generate(
                          5,
                          (i) => DateTime.now().year - 2 + i,
                        ),
                        itemLabel: (value) => value.toString(),
                        fullWidth: true,
                        onChanged: (value) {
                          setState(() {
                            _selectedYear = value ?? DateTime.now().year;
                          });
                        },
                      ),
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

                builder: (context, billSnapshot) {
                  if (!billSnapshot.hasData || _branchLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final bills = billSnapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (_branchMunicipality == null) return false;

                    if (_getBillMunicipality(data).toLowerCase() !=
                        _branchMunicipality!.toLowerCase()) {
                      return false;
                    }

                    return _isBillWithinSelectedPeriod(
                      data['generatedAt'] as Timestamp?,
                    );
                  }).toList();

                  // TOTAL BILLS
                  final totalBills = bills.length;

                  // PAID BILLS
                  final paidBills = bills.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    final status = (data['status'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();

                    return status == 'paid';
                  }).length;

                  // UNPAID BILLS
                  final unpaidBills = bills.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    final status = (data['status'] ?? '')
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
                    final data = doc.data() as Map<String, dynamic>;

                    final status = (data['status'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();

                    if (status == 'paid') {
                      totalRevenue += (data['totalAmount'] as num? ?? 0)
                          .toDouble();
                    }
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bills Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        _branchMunicipality ??
                            'Branch not set — update your profile',
                        style: TextStyle(
                          fontSize: 12,
                          color: _branchMunicipality == null
                              ? Colors.red.shade600
                              : Colors.grey,
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
                            value: totalBills.toString(),
                            icon: Icons.receipt_long,
                            color: _primaryGreen,
                          ),

                          const SizedBox(width: 10),

                          _summaryCard(
                            title: 'Paid',
                            value: paidBills.toString(),
                            icon: Icons.check_circle,
                            color: Colors.green,
                          ),

                          const SizedBox(width: 10),

                          _summaryCard(
                            title: 'Unpaid',
                            value: unpaidBills.toString(),
                            icon: Icons.pending_actions,
                            color: Colors.orange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // ------------------------------------------
                      // TOTAL REVENUE
                      // ------------------------------------------
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                    fontWeight: FontWeight.bold,
                                    color: _primaryGreen,
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

                builder: (context, complaintSnapshot) {
                  if (!complaintSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // FILTER COMPLAINTS BY PERIOD
                  final complaints = complaintSnapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    return _isComplaintWithinSelectedPeriod(data);
                  }).toList();

                  // FILTER BY BRANCH (ASYNC — MAY NEED A CONSUMER
                  // LOOKUP PER COMPLAINT)
                  return FutureBuilder<List<QueryDocumentSnapshot>>(
                    future: _branchLoading
                        ? null
                        : _filterComplaintsByBranch(complaints),
                    builder: (context, branchSnapshot) {
                      if (_branchLoading ||
                          branchSnapshot.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final branchComplaints = branchSnapshot.data ?? const [];

                      // TOTAL
                      final totalComplaints = branchComplaints.length;

                      // PENDING
                      final pendingComplaints = branchComplaints.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final status = (data['status'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();

                        return status == 'pending';
                      }).length;

                      // IN PROGRESS
                      final inProgressComplaints = branchComplaints.where((
                        doc,
                      ) {
                        final data = doc.data() as Map<String, dynamic>;

                        final status = (data['status'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();

                        return status == 'in progress' ||
                            status == 'in_progress' ||
                            status == 'inprogress';
                      }).length;

                      // RESOLVED
                      final resolvedComplaints = branchComplaints.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final status = (data['status'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();

                        return status == 'resolved';
                      }).length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Complaints Summary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            _branchMunicipality ??
                                'Branch not set — update your profile',
                            style: TextStyle(
                              fontSize: 12,
                              color: _branchMunicipality == null
                                  ? Colors.red.shade600
                                  : Colors.grey,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // --------------------------------------
                          // TOTAL + PENDING
                          // --------------------------------------
                          Row(
                            children: [
                              _summaryCard(
                                title: 'Total Complaints',
                                value: totalComplaints.toString(),
                                icon: Icons.report_problem,
                                color: Colors.red,
                              ),

                              const SizedBox(width: 10),

                              _summaryCard(
                                title: 'Pending',
                                value: pendingComplaints.toString(),
                                icon: Icons.pending,
                                color: Colors.orange,
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // --------------------------------------
                          // IN PROGRESS + RESOLVED
                          // --------------------------------------
                          Row(
                            children: [
                              _summaryCard(
                                title: 'In Progress',
                                value: inProgressComplaints.toString(),
                                icon: Icons.autorenew,
                                color: Colors.blue,
                              ),

                              const SizedBox(width: 10),

                              _summaryCard(
                                title: 'Resolved',
                                value: resolvedComplaints.toString(),
                                icon: Icons.task_alt,
                                color: Colors.green,
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
