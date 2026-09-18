import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/screens/consumer/consumer_bill_screen.dart';
import 'package:soreconnect/screens/consumer/consumer_profile_screen.dart';
import 'package:soreconnect/screens/complaints/submit_complaint_screen.dart';
import 'package:soreconnect/screens/announcements/view_announcements_screen.dart';
import 'package:soreconnect/screens/auth/login_screen.dart';
import 'package:soreconnect/utils/pending_email_guard.dart';

class ConsumerDashboard extends StatefulWidget {
  const ConsumerDashboard({super.key});

  @override
  State<ConsumerDashboard> createState() => _ConsumerDashboardState();
}

class _ConsumerDashboardState extends State<ConsumerDashboard> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  int selectedMonth = DateTime.now().month;
  int selectedYear = DateTime.now().year;

  // ============================================================
  // THEME COLORS
  // ============================================================

  static const orange = Color(0xFFFFA000);
  static const background = Color(0xFFF5F7F5);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    // Safety net: finishes signing out if an email change was
    // confirmed while this screen wasn't the one watching for it
    // (e.g. backed out of the verify screen, or the app was
    // backgrounded when the confirmation link was tapped).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkPendingEmailConfirmed(context);
    });
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await _auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (_) => false,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _monthName(int month) {
    const months = [
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

    return months[month - 1];
  }

  double _getAmount(Map<String, dynamic> data) {
    final value = data['totalAmount'];

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  bool _isPaid(Map<String, dynamic> data) {
    return data['status']
            ?.toString()
            .toLowerCase()
            .trim() ==
        'paid';
  }

  bool _isCancelled(Map<String, dynamic> data) {
    final status = data['status']
        ?.toString()
        .toLowerCase()
        .trim();

    return status == 'cancelled' || status == 'canceled';
  }

  DateTime? _getDueDate(Map<String, dynamic> data) {
    final value = data['dueDate'];

    if (value is Timestamp) return value.toDate();

    return null;
  }

  DateTime? _getPaymentStartDate(Map<String, dynamic> data) {
    final value = data['paymentStartDate'];

    if (value is Timestamp) return value.toDate();

    return null;
  }

  // ============================================================
  // FIRESTORE STREAMS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _getBills(
    String consumerId,
  ) {
    return _firestore
        .collection('bills')
        .where(
          'consumerId',
          isEqualTo: consumerId,
        )
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getComplaints(
    String consumerId,
  ) {
    return _firestore
        .collection('complaints')
        .where(
          'consumerId',
          isEqualTo: consumerId,
        )
        .snapshots();
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: .05),
            blurRadius: 16,
            offset:
                const Offset(0, 6),
          ),
          BoxShadow(
            color:
                color.withValues(alpha: .10),
            blurRadius: 24,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(
              color:
                  color.withValues(alpha: .10),
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 27,
            ),
          ),
          const SizedBox(
            width: 14,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      TextStyle(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Colors.grey.shade600,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  subtitle,
                  style:
                      TextStyle(
                    fontSize: 11,
                    color:
                        Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MONTH SELECTOR
  // ============================================================

  Widget _monthSelector() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child:
          DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedMonth,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: orange,
          ),
          items: List.generate(
            12,
            (index) {
              final month = index + 1;

              return DropdownMenuItem(
                value: month,
                child: Text(
                  '${_monthName(month)} $selectedYear',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              );
            },
          ),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              selectedMonth = value;
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // SMALL AMOUNT
  // ============================================================

  Widget _smallAmount({
    required String title,
    required double amount,
    required Color color,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: .07),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight:
                  FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _openScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => screen,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Consumer Dashboard',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        backgroundColor: orange,
        foregroundColor:
            Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon:
                const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: SafeArea(
        child: StreamBuilder<
            QuerySnapshot<
                Map<String, dynamic>>>(
          stream: _getBills(
            user.uid,
          ),
          builder:
              (context, billSnapshot) {
            if (billSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding:
                      const EdgeInsets
                          .all(25),
                  child: Text(
                    'Unable to load bills.\n\n'
                    '${billSnapshot.error}',
                    textAlign:
                        TextAlign.center,
                    style:
                        const TextStyle(
                      color: Colors.red,
                    ),
                  ),
                ),
              );
            }

            if (billSnapshot
                    .connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child:
                    CircularProgressIndicator(
                  color: orange,
                ),
              );
            }

            final bills =
                billSnapshot.data?.docs
                        .map(
                          (doc) =>
                              doc.data(),
                        )
                        .toList() ??
                    [];

            // ==================================================
            // ACCOUNT TOTALS
            // ==================================================

            double totalPaid = 0;
            double totalUnpaid = 0;

            // ==================================================
            // MONTHLY TOTALS
            // ==================================================

            double monthlyPaid = 0;
            double monthlyUnpaid = 0;
            DateTime? monthlyDueDate;
            DateTime? monthlyPaymentStart;

            final selectedPeriod =
                '${_monthName(selectedMonth)} $selectedYear';

            for (final bill in bills) {
              // Cancelled bills are excluded from every total —
              // they are void and nothing is owed on them.
              if (_isCancelled(bill)) {
                continue;
              }

              final amount =
                  _getAmount(bill);

              final paid =
                  _isPaid(bill);

              if (paid) {
                totalPaid += amount;
              } else {
                totalUnpaid += amount;
              }

              final period =
                  bill['billingPeriod']
                          ?.toString()
                          .trim() ??
                      '';

              if (period ==
                  selectedPeriod) {
                if (paid) {
                  monthlyPaid +=
                      amount;
                } else {
                  monthlyUnpaid +=
                      amount;

                  final dueDate =
                      _getDueDate(bill);

                  if (dueDate != null &&
                      (monthlyDueDate == null ||
                          dueDate.isBefore(
                            monthlyDueDate,
                          ))) {
                    monthlyDueDate = dueDate;
                    monthlyPaymentStart =
                        _getPaymentStartDate(bill);
                  }
                }
              }
            }

            return StreamBuilder<
                QuerySnapshot<
                    Map<String,
                        dynamic>>>(
              stream:
                  _getComplaints(
                user.uid,
              ),
              builder: (
                context,
                complaintSnapshot,
              ) {
                final complaintCount =
                    complaintSnapshot
                            .data
                            ?.docs
                            .length ??
                        0;

                return SingleChildScrollView(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    20,
                    20,
                    20,
                    30,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      // ==================================================
                      // ACCOUNT SUMMARY
                      // ==================================================

                      const Text(
                        'Account Summary',
                        style:
                            TextStyle(
                          fontSize: 19,
                          fontWeight:
                              FontWeight
                                  .bold,
                          color:
                              Colors.black87,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        'Overview of your electricity account',
                        style:
                            TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w500,
                          color:
                              Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      _summaryCard(
                        title:
                            'Remaining Due',
                        value:
                            '₱${totalUnpaid.toStringAsFixed(2)}',
                        subtitle:
                            'Total unpaid balance',
                        icon: Icons
                            .account_balance_wallet,
                        color:
                            Colors.red,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      _summaryCard(
                        title:
                            'Total Paid',
                        value:
                            '₱${totalPaid.toStringAsFixed(2)}',
                        subtitle:
                            'Total payments made',
                        icon: Icons
                            .check_circle_outline,
                        color:
                            Colors.green,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      _summaryCard(
                        title:
                            'My Complaints',
                        value:
                            complaintCount
                                .toString(),
                        subtitle:
                            'Total complaints submitted',
                        icon: Icons
                            .report_problem_outlined,
                        color: orange,
                      ),

                      const SizedBox(
                        height: 28,
                      ),

                      // ==================================================
                      // MONTHLY SUMMARY
                      // ==================================================

                      const Text(
                        'Monthly Summary',
                        style:
                            TextStyle(
                          fontSize: 19,
                          fontWeight:
                              FontWeight
                                  .bold,
                          color:
                              Colors.black87,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        'View your billing summary for a selected month',
                        style:
                            TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w500,
                          color:
                              Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      _monthSelector(),

                      const SizedBox(
                        height: 15,
                      ),

                      // ==================================================
                      // MONTHLY CARD
                      // ==================================================

                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .all(18),
                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            24,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors
                                  .black
                                  .withValues(
                                alpha: .05,
                              ),
                              blurRadius:
                                  16,
                              offset:
                                  const Offset(
                                0,
                                6,
                              ),
                            ),
                            BoxShadow(
                              color: orange
                                  .withValues(
                                alpha: .08,
                              ),
                              blurRadius:
                                  24,
                              offset:
                                  const Offset(
                                0,
                                10,
                              ),
                            ),
                          ],
                        ),
                        child:
                            Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        orange.withValues(
                                      alpha: .12,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      16,
                                    ),
                                  ),
                                  child:
                                      const Icon(
                                    Icons
                                        .calendar_month_outlined,
                                    color:
                                        orange,
                                    size:
                                        23,
                                  ),
                                ),
                                const SizedBox(
                                  width: 12,
                                ),
                                Expanded(
                                  child:
                                      Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Text(
                                        'Billing Period',
                                        style:
                                            TextStyle(
                                          fontSize:
                                              11,
                                          color:
                                              Colors.grey.shade600,
                                          fontWeight:
                                              FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(
                                        height:
                                            3,
                                      ),
                                      Text(
                                        selectedPeriod,
                                        style:
                                            const TextStyle(
                                          fontSize:
                                              16,
                                          fontWeight:
                                              FontWeight.bold,
                                          color:
                                              orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 18,
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child:
                                      _smallAmount(
                                    title:
                                        'Paid This Month',
                                    amount:
                                        monthlyPaid,
                                    color:
                                        Colors.green,
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                Expanded(
                                  child:
                                      _smallAmount(
                                    title:
                                        'Unpaid This Month',
                                    amount:
                                        monthlyUnpaid,
                                    color:
                                        Colors.red,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 14,
                            ),

                            Container(
                              width:
                                  double.infinity,
                              padding:
                                  const EdgeInsets
                                      .all(
                                14,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    orange.withValues(
                                  alpha: .07,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  16,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons
                                        .account_balance_wallet_outlined,
                                    color:
                                        orange,
                                    size:
                                        22,
                                  ),
                                  const SizedBox(
                                    width: 10,
                                  ),
                                  Expanded(
                                    child:
                                        Text(
                                      'Monthly Total',
                                      style:
                                          TextStyle(
                                        fontSize:
                                            12,
                                        fontWeight:
                                            FontWeight.w600,
                                        color:
                                            Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '₱${(monthlyPaid + monthlyUnpaid).toStringAsFixed(2)}',
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          17,
                                      fontWeight:
                                          FontWeight.bold,
                                      color:
                                          orange,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            if (monthlyUnpaid >
                                0) ...[
                              const SizedBox(
                                height: 14,
                              ),

                              Container(
                                width:
                                    double.infinity,
                                padding:
                                    const EdgeInsets
                                        .all(
                                  14,
                                ),
                                decoration:
                                    BoxDecoration(
                                  color: Colors
                                      .red
                                      .withValues(
                                    alpha: .07,
                                  ),
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    16,
                                  ),
                                ),
                                child:
                                    Row(
                                  children: [
                                    const Icon(
                                      Icons
                                          .payments_outlined,
                                      color:
                                          Colors.red,
                                      size:
                                          22,
                                    ),
                                    const SizedBox(
                                      width: 10,
                                    ),
                                    Expanded(
                                      child:
                                          Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment
                                                .start,
                                        children: [
                                          Text(
                                            'Amount Due',
                                            style:
                                                TextStyle(
                                              fontSize:
                                                  12,
                                              fontWeight:
                                                  FontWeight.w600,
                                              color:
                                                  Colors.grey.shade600,
                                            ),
                                          ),
                                          if (monthlyPaymentStart !=
                                              null) ...[
                                            const SizedBox(
                                              height:
                                                  2,
                                            ),
                                            Text(
                                              'Payable from '
                                              '${DateFormat('MMM dd, yyyy').format(monthlyPaymentStart)}',
                                              style:
                                                  TextStyle(
                                                fontSize:
                                                    11,
                                                color:
                                                    Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                          if (monthlyDueDate !=
                                              null) ...[
                                            const SizedBox(
                                              height:
                                                  2,
                                            ),
                                            Text(
                                              'Due '
                                              '${DateFormat('MMM dd, yyyy').format(monthlyDueDate)}',
                                              style:
                                                  TextStyle(
                                                fontSize:
                                                    11,
                                                color:
                                                    Colors.grey.shade500,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '₱${monthlyUnpaid.toStringAsFixed(2)}',
                                      style:
                                          const TextStyle(
                                        fontSize:
                                            17,
                                        fontWeight:
                                            FontWeight.bold,
                                        color:
                                            Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (monthlyPaid ==
                                    0 &&
                                monthlyUnpaid ==
                                    0)
                              Padding(
                                padding:
                                    const EdgeInsets
                                        .only(
                                  top: 14,
                                ),
                                child:
                                    Container(
                                  width:
                                      double.infinity,
                                  padding:
                                      const EdgeInsets
                                          .all(
                                    13,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        const Color(
                                      0xFFF8F8F8,
                                    ),
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      16,
                                    ),
                                  ),
                                  child:
                                      Row(
                                    children: [
                                      Icon(
                                        Icons
                                            .info_outline,
                                        color:
                                            Colors.grey.shade500,
                                        size:
                                            20,
                                      ),
                                      const SizedBox(
                                        width:
                                            9,
                                      ),
                                      Expanded(
                                        child:
                                            Text(
                                          'No billing records found for this month.',
                                          style:
                                              TextStyle(
                                            fontSize:
                                                11,
                                            fontWeight:
                                                FontWeight.w500,
                                            color:
                                                Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),

      // ========================================================
      // BOTTOM NAVIGATION
      // ========================================================

      bottomNavigationBar:
          BottomNavigationBar(
        type:
            BottomNavigationBarType.fixed,
        currentIndex: 0,
        selectedItemColor:
            orange,
        unselectedItemColor:
            Colors.grey,
        onTap: (index) {
          if (index == 0) {
            return;
          }

          switch (index) {
            case 1:
              _openScreen(
                const ConsumerBillScreen(),
              );
              break;

            case 2:
              _openScreen(
                const SubmitComplaintScreen(),
              );
              break;

            case 3:
              _openScreen(
                const ViewAnnouncementsScreen(),
              );
              break;

            case 4:
              _openScreen(
                const ConsumerProfileScreen(),
              );
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon:
                Icon(Icons.home_outlined),
            activeIcon:
                Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.receipt_long_outlined,
            ),
            activeIcon: Icon(
              Icons.receipt_long,
            ),
            label: 'Bills',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.report_problem_outlined,
            ),
            activeIcon: Icon(
              Icons.report_problem,
            ),
            label: 'Complaints',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.campaign_outlined,
            ),
            activeIcon: Icon(
              Icons.campaign,
            ),
            label: 'News',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.person_outline,
            ),
            activeIcon: Icon(
              Icons.person,
            ),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}