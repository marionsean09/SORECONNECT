import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:soreconnect/screens/teller/generate_reports_screen.dart';
import 'package:soreconnect/screens/teller/manage_bills_screen.dart';
import 'package:soreconnect/screens/complaints/manage_complaints_screen.dart';
import 'package:soreconnect/screens/shared/staff_profile_screen.dart';
import 'package:soreconnect/utils/page_transitions.dart';
import 'package:soreconnect/utils/pending_email_guard.dart';
import 'package:soreconnect/widgets/minimal_filter_bar.dart';

// ============================================================
// TELLER DASHBOARD (TAB SHELL)
//
// Hosts the bottom nav's 5 destinations as sibling pages in one
// PageView instead of pushing each as a separate route — see
// consumer_dashboard.dart for the full rationale (no back arrow,
// swipeable, each tab keeps its state alive).
// ============================================================

class TellerDashboard extends StatefulWidget {
  const TellerDashboard({super.key});

  @override
  State<TellerDashboard> createState() => _TellerDashboardState();
}

class _TellerDashboardState extends State<TellerDashboard> {
  static const Color _primaryGreen = Color(0xFF1B5E20);

  // Strong ease-out — starts fast so a tapped tab feels immediate
  // rather than a generic linear/ease-in-out glide.
  static const Curve _tabCurve = Cubic(0.23, 1, 0.32, 1);

  late final PageController _pageController;
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    _TellerHomeTab(),
    ManageBillsScreen(),
    GenerateReportScreen(),
    ManageComplaintsScreen(),
    StaffProfileScreen(role: 'Teller', userTypeValue: 'teller'),
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
      // BOTTOM NAVIGATION
      // ========================================================
      bottomNavigationBar: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          selectedItemColor: _primaryGreen,
          elevation: 12,
          onTap: _goToTab,
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
              icon: Icon(Icons.assessment),
              label: 'Reports',
            ),

            BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts),
              label: 'Complaints',
            ),

            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Profile',
            ),
          ],
        ),
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

class _TellerHomeTab extends StatefulWidget {
  const _TellerHomeTab();

  @override
  State<_TellerHomeTab> createState() => _TellerHomeTabState();
}

class _TellerHomeTabState extends State<_TellerHomeTab>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const Color _primaryGreen = Color(0xFF1B5E20);
  static const Color _accentGold = Color(0xFFDAA520);

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

  // ------------------------------------------------------------
  // BRANCH
  //
  // Bills/complaints summaries are scoped to this teller's own
  // branch, the same one Manage Bills/Complaints locks to — listened
  // live so changing it in Profile updates these totals immediately
  // instead of leaving stale numbers from the old branch on screen.
  // ------------------------------------------------------------

  String? _branchMunicipality;
  bool _branchLoading = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _branchSub;

  // Resolves a complaint's municipality when it isn't stored
  // directly on the complaint — keyed by consumer uid, since a
  // complaint only records the location itself when the consumer
  // attached one at submission time.
  final Map<String, String> _consumerMunicipalityCache = {};

  // ------------------------------------------------------------
  // ENTRANCE ANIMATION
  // ------------------------------------------------------------

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _listenToBranch();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: pageTransitionCurve,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(_fadeAnimation);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _branchSub?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LISTEN TO BRANCH
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // BILL MUNICIPALITY
  // ------------------------------------------------------------

  String _getBillMunicipality(Map<String, dynamic> data) {
    final value = data['municipality'] ?? data['city'];
    return (value ?? '').toString().trim();
  }

  // ------------------------------------------------------------
  // COMPLAINT MUNICIPALITY (WITH CONSUMER LOOKUP FALLBACK)
  //
  // Complaints don't store a location at submission time, so this
  // falls back to the consumer's own profile municipality — cached
  // per consumer so repeated complaints from the same consumer don't
  // re-fetch it.
  // ------------------------------------------------------------

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

  // ------------------------------------------------------------
  // FILTER COMPLAINTS BY BRANCH
  // ------------------------------------------------------------

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
  // ============================================================

  bool _isBillWithinSelectedPeriod(Timestamp? timestamp) {
    if (timestamp == null) return false;

    final date = timestamp.toDate();

    if (_reportType == 'Monthly') {
      return date.year == _selectedYear && date.month == _selectedMonth;
    }

    return date.year == _selectedYear;
  }

  // ============================================================
  // COMPLAINT DATE
  //
  // Supports all known date fields.
  // ============================================================

  DateTime? _getComplaintDate(Map<String, dynamic> data) {
    final possibleValues = [
      data['createdAt'],
      data['dateSubmitted'],
      data['submittedAt'],
      data['timestamp'],
      data['dateCreated'],
      data['created_at'],
      data['submitted_at'],
    ];

    for (final value in possibleValues) {
      if (value == null) continue;

      if (value is Timestamp) {
        return value.toDate();
      }

      if (value is DateTime) {
        return value;
      }

      if (value is String) {
        final parsed = DateTime.tryParse(value);

        if (parsed != null) {
          return parsed;
        }
      }
    }

    return null;
  }

  // ============================================================
  // COMPLAINT PERIOD FILTER
  //
  // IMPORTANT:
  // A complaint with a missing date is NOT discarded.
  //
  // This prevents old complaints with incomplete fields
  // from disappearing from the dashboard.
  // ============================================================

  bool _isComplaintWithinSelectedPeriod(Map<String, dynamic> data) {
    final date = _getComplaintDate(data);

    // ------------------------------------------------------------
    // NO DATE
    //
    // Still include the complaint.
    // ------------------------------------------------------------

    if (date == null) {
      return true;
    }

    // ------------------------------------------------------------
    // MONTHLY
    // ------------------------------------------------------------

    if (_reportType == 'Monthly') {
      return date.year == _selectedYear && date.month == _selectedMonth;
    }

    // ------------------------------------------------------------
    // YEARLY
    // ------------------------------------------------------------

    return date.year == _selectedYear;
  }

  // ============================================================
  // NORMALIZE COMPLAINT STATUS
  //
  // This is important because old complaints may contain:
  //
  // Pending
  // pending
  // PENDING
  // In Progress
  // in_progress
  // in-progress
  // inprogress
  // Resolved
  // resolved
  // Closed
  // Completed
  //
  // Missing status = Pending
  // ============================================================

  String _normalizeComplaintStatus(dynamic value) {
    final status = (value ?? '').toString().trim().toLowerCase();

    // ------------------------------------------------------------
    // MISSING STATUS
    // ------------------------------------------------------------

    if (status.isEmpty) {
      return 'Pending';
    }

    // ------------------------------------------------------------
    // PENDING
    // ------------------------------------------------------------

    if (status == 'pending') {
      return 'Pending';
    }

    // ------------------------------------------------------------
    // IN PROGRESS
    // ------------------------------------------------------------

    if (status == 'in progress' ||
        status == 'in_progress' ||
        status == 'in-progress' ||
        status == 'inprogress' ||
        status == 'ongoing') {
      return 'In Progress';
    }

    // ------------------------------------------------------------
    // RESOLVED
    // ------------------------------------------------------------

    if (status == 'resolved' ||
        status == 'closed' ||
        status == 'completed' ||
        status == 'complete') {
      return 'Resolved';
    }

    // ------------------------------------------------------------
    // UNKNOWN STATUS
    //
    // Treat unknown/old statuses as Pending so they are not
    // lost from the classification totals.
    // ------------------------------------------------------------

    return 'Pending';
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
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
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

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
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

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
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
                          color: _primaryGreen.withValues(alpha: 0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
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
                            Icons.person,
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
                                'WELCOME, TELLER',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryGreen,
                                ),
                              ),

                              const SizedBox(height: 4),

                              const Text(
                                'Manage bill status, generate reports, and support service requests.',
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
                                  _selectedMonth =
                                      value ?? DateTime.now().month;
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
                  // BILLS STREAM
                  //
                  // Scoped to this teller's own branch — matches
                  // Manage Bills, so the summary never shows another
                  // branch's totals.
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

                      final totalBills = bills.length;

                      final paidBills = bills.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final status = (data['status'] ?? '')
                            .toString()
                            .toLowerCase();

                        return status == 'paid';
                      }).length;

                      final unpaidBills = bills.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final status = (data['status'] ?? '')
                            .toString()
                            .toLowerCase();

                        return status != 'paid';
                      }).length;

                      double totalRevenue = 0;

                      for (final doc in bills) {
                        final data = doc.data() as Map<String, dynamic>;

                        final status = (data['status'] ?? '')
                            .toString()
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

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: _primaryGreen.withValues(alpha: 0.10),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
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
                                        fontSize: 25,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.4,
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
                  //
                  // FIXED:
                  //
                  // 1. ALL COMPLAINT DOCUMENTS ARE FETCHED.
                  // 2. MISSING DATE DOES NOT REMOVE THE COMPLAINT.
                  // 3. MISSING STATUS = PENDING.
                  // 4. STATUS FORMATS ARE NORMALIZED.
                  // 5. UNKNOWN STATUS = PENDING.
                  // ==================================================
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('complaints')
                        .snapshots(),
                    builder: (context, complaintSnapshot) {
                      // ------------------------------------------------
                      // LOADING
                      // ------------------------------------------------

                      if (complaintSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // ------------------------------------------------
                      // ERROR
                      // ------------------------------------------------

                      if (complaintSnapshot.hasError) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Error loading complaints:\n'
                            '${complaintSnapshot.error}',
                            style: TextStyle(color: Colors.red.shade800),
                          ),
                        );
                      }

                      // ------------------------------------------------
                      // NO SNAPSHOT
                      // ------------------------------------------------

                      if (!complaintSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      // ------------------------------------------------
                      // FETCH EVERY COMPLAINT
                      //
                      // IMPORTANT:
                      // NO Firestore WHERE CLAUSE.
                      //
                      // This means documents with missing fields
                      // are still retrieved.
                      // ------------------------------------------------

                      final allComplaints = complaintSnapshot.data!.docs;

                      // ------------------------------------------------
                      // PERIOD FILTER
                      // ------------------------------------------------

                      final complaints = allComplaints.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        return _isComplaintWithinSelectedPeriod(data);
                      }).toList();

                      // ------------------------------------------------
                      // CLASSIFICATION COUNTERS
                      // ------------------------------------------------

                      // ------------------------------------------------
                      // BRANCH FILTER (ASYNC — MAY NEED A CONSUMER
                      // LOOKUP PER COMPLAINT)
                      // ------------------------------------------------

                      return FutureBuilder<List<QueryDocumentSnapshot>>(
                        future: _branchLoading
                            ? null
                            : _filterComplaintsByBranch(complaints),
                        builder: (context, branchSnapshot) {
                          if (_branchLoading ||
                              branchSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final branchComplaints =
                              branchSnapshot.data ?? const [];

                          int pendingComplaints = 0;
                          int inProgressComplaints = 0;
                          int resolvedComplaints = 0;

                          // --------------------------------------------
                          // CLASSIFY EVERY COMPLAINT
                          // --------------------------------------------

                          for (final doc in branchComplaints) {
                            final data = doc.data() as Map<String, dynamic>;

                            final normalizedStatus = _normalizeComplaintStatus(
                              data['status'],
                            );

                            switch (normalizedStatus) {
                              case 'Pending':
                                pendingComplaints++;
                                break;

                              case 'In Progress':
                                inProgressComplaints++;
                                break;

                              case 'Resolved':
                                resolvedComplaints++;
                                break;
                            }
                          }

                          // --------------------------------------------
                          // TOTAL
                          //
                          // This is based directly on every complaint
                          // that passed the period and branch checks.
                          // --------------------------------------------

                          final totalComplaints = branchComplaints.length;

                          // --------------------------------------------
                          // RETURN SUMMARY
                          // --------------------------------------------

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
                                _reportType == 'Monthly'
                                    ? '${_branchMunicipality ?? 'No branch'} · ${_months[_selectedMonth - 1]} $_selectedYear'
                                    : '${_branchMunicipality ?? 'No branch'} · Year $_selectedYear',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),

                              const SizedBox(height: 12),

                              // ==========================================
                              // TOTAL + PENDING
                              // ==========================================
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

                              // ==========================================
                              // IN PROGRESS + RESOLVED
                              // ==========================================
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
        ),
      ),
    );
  }
}
