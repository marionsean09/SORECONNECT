import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:soreconnect/models/bill_model.dart';
import 'package:soreconnect/utils/bill_calculator.dart';
import 'package:soreconnect/widgets/bill_breakdown_view.dart';
import 'package:soreconnect/widgets/export_bill_sheet.dart';
import 'package:soreconnect/widgets/minimal_filter_bar.dart';
import 'package:soreconnect/widgets/ticket_badge.dart';

class ConsumerBillScreen extends StatefulWidget {
  const ConsumerBillScreen({super.key});

  @override
  State<ConsumerBillScreen> createState() => _ConsumerBillScreenState();
}

class _ConsumerBillScreenState extends State<ConsumerBillScreen>
    with SingleTickerProviderStateMixin {
  String _selectedFilter = 'All';
  String _selectedSort = 'Newest';

  final TextEditingController _searchController =
      TextEditingController();
  String _searchQuery = '';

  // Strong ease-out — starts fast so the entrance feels responsive
  // rather than a generic linear/ease-in-out fade.
  static const Curve _easeOut = Cubic(0.23, 1, 0.32, 1);

  // Created once (not inline in build()) so typing in the search
  // field doesn't make StreamBuilder see a "new" stream on every
  // keystroke, resubscribe, and briefly replace this whole subtree
  // — including the search field — with a loading spinner. That was
  // disposing the TextField's Element on every keystroke, dropping
  // focus/cursor/keyboard mid-word.
  late final Stream<QuerySnapshot>? _billsStream;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;

    _billsStream = user == null
        ? null
        : FirebaseFirestore.instance
            .collection("bills")
            .where("consumerId", isEqualTo: user.uid)
            .snapshots();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: _easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: _easeOut,
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Map<String, dynamic> bill) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return true;

    final searchable = [
      bill['billingPeriod'],
      bill['status'],
      bill['generatedBy'],
      bill['accountNumber'],
      bill['ratePerKwh'],
      bill['totalAmount'],
      bill['previousReading'],
      bill['currentReading'],
      bill['consumption'],
    ].map((v) => (v ?? '').toString().toLowerCase()).join(' ');

    return searchable.contains(query);
  }

  List<QueryDocumentSnapshot> _filterAndSortBills(
    List<QueryDocumentSnapshot> bills,
  ) {
    List<QueryDocumentSnapshot> result = List.from(bills);

    // FILTER
    if (_selectedFilter != 'All') {
      result = result.where((doc) {
        final bill = doc.data() as Map<String, dynamic>;

        return (bill['status'] ?? '')
                .toString()
                .toLowerCase() ==
            _selectedFilter.toLowerCase();
      }).toList();
    }

    // SEARCH
    result = result.where((doc) {
      return _matchesSearch(doc.data() as Map<String, dynamic>);
    }).toList();

    // SORT
    result.sort((a, b) {
      final billA = a.data() as Map<String, dynamic>;
      final billB = b.data() as Map<String, dynamic>;

      final dateA = billA['generatedAt'] as Timestamp?;
      final dateB = billB['generatedAt'] as Timestamp?;

      final amountA =
          ((billA['totalAmount'] as num?) ?? 0).toDouble();

      final amountB =
          ((billB['totalAmount'] as num?) ?? 0).toDouble();

      switch (_selectedSort) {
        case 'Oldest':
          if (dateA == null || dateB == null) return 0;
          return dateA.compareTo(dateB);

        case 'Highest':
          return amountB.compareTo(amountA);

        case 'Lowest':
          return amountA.compareTo(amountB);

        default:
          if (dateA == null || dateB == null) return 0;
          return dateB.compareTo(dateA);
      }
    });

    return result;
  }


  // ============================================================
  // BILL DETAIL ROW (label / value pair)
  // ============================================================

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade900,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATUS MESSAGE (loading / error / empty states)
  // ============================================================

  Widget _statusMessage({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_billsStream == null) {
      return const Scaffold(
        body: Center(
          child: Text("User not logged in."),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "My Bills",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _billsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            );
          }

          if (snapshot.hasError) {
            return _statusMessage(
              icon: Icons.error_outline,
              title: "Something went wrong",
              subtitle: snapshot.error.toString(),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return _statusMessage(
              icon: Icons.receipt_long_outlined,
              title: "No bills yet",
              subtitle:
                  "Your electric bills will show up here once "
                  "they're generated.",
            );
          }

          final bills =
              _filterAndSortBills(snapshot.data!.docs);

          return Column(
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Column(
                    children: [
                      // SEARCH
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          0,
                        ),
                        child: MinimalSearchField(
                          controller: _searchController,
                          hintText:
                              "Search billing period, status, rate...",
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),

                      // FILTER AND SORT
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: MinimalDropdown<String>(
                                value: _selectedFilter,
                                icon: Icons.filter_list,
                                items: const [
                                  'All',
                                  'Paid',
                                  'Unpaid',
                                  'Cancelled',
                                ],
                                itemLabel: (value) => value,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedFilter = value;
                                    });
                                  }
                                },
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: MinimalDropdown<String>(
                                value: _selectedSort,
                                icon: Icons.sort,
                                items: const [
                                  'Newest',
                                  'Oldest',
                                  'Highest',
                                  'Lowest',
                                ],
                                itemLabel: (value) => value,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedSort = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      // NUMBER OF BILLS
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "${bills.length} bill(s) found",
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // BILL LIST
              Expanded(
                child: bills.isEmpty
                    ? _statusMessage(
                        icon: _searchQuery.trim().isEmpty
                            ? Icons.receipt_long_outlined
                            : Icons.search_off_outlined,
                        title: _searchQuery.trim().isEmpty
                            ? "No bills found"
                            : "No matches",
                        subtitle: _searchQuery.trim().isEmpty
                            ? "Try a different filter."
                            : 'No bills match '
                                '"${_searchQuery.trim()}". '
                                'Try a different keyword.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        itemCount: bills.length,
                        itemBuilder: (context, index) {
                          final bill =
                              bills[index].data()
                                  as Map<String, dynamic>;

                          final ticketNumber = BillModel.ticketNumberFor(
                            bill,
                            bills[index].id,
                          );

                          final Timestamp? paymentStartTimestamp =
                              bill["paymentStartDate"] as Timestamp?;

                          final String paymentStartDate =
                              paymentStartTimestamp == null
                                  ? "-"
                                  : DateFormat(
                                      "MMM dd, yyyy",
                                    ).format(
                                      paymentStartTimestamp.toDate(),
                                    );

                          final Timestamp? dueTimestamp =
                              bill["dueDate"] as Timestamp?;

                          final String dueDate =
                              dueTimestamp == null
                                  ? "-"
                                  : DateFormat(
                                      "MMM dd, yyyy",
                                    ).format(
                                      dueTimestamp.toDate(),
                                    );

                          final String status =
                              (bill["status"] ?? "unpaid")
                                  .toString();

                          final bool isPaid =
                              status.toLowerCase() == "paid";
                          final bool isCancelled =
                              status.toLowerCase() == "cancelled" ||
                                  status.toLowerCase() == "canceled";

                          final Color statusColor = isPaid
                              ? Colors.green.shade700
                              : isCancelled
                                  ? Colors.grey.shade600
                                  : Colors.red.shade700;

                          final IconData statusIcon = isPaid
                              ? Icons.check_circle_outline
                              : isCancelled
                                  ? Icons.cancel_outlined
                                  : Icons.schedule_outlined;

                          final double totalAmount =
                              ((bill["totalAmount"] as num?) ?? 0)
                                  .toDouble();

                          final rawBreakdown = bill["breakdown"];
                          final BillBreakdown? breakdown =
                              rawBreakdown is Map
                                  ? BillBreakdown.fromMap(
                                      Map<String, dynamic>.from(
                                        rawBreakdown,
                                      ),
                                    )
                                  : null;

                          final double previousReading =
                              ((bill["previousReading"] as num?) ?? 0)
                                  .toDouble();
                          final double currentReading =
                              ((bill["currentReading"] as num?) ?? 0)
                                  .toDouble();
                          final double consumption =
                              ((bill["consumption"] as num?) ?? 0)
                                  .toDouble();

                          return Container(
                            margin: const EdgeInsets.only(
                              bottom: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.06),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withValues(alpha: 0.04),
                                  blurRadius: 28,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (ticketNumber.isNotEmpty) ...[
                                        TicketBadge(
                                          ticketNumber: ticketNumber,
                                          color: Theme.of(
                                            context,
                                          ).primaryColor,
                                        ),
                                        const SizedBox(width: 6),
                                      ],
                                      IconButton(
                                        icon: const Icon(Icons.ios_share),
                                        tooltip: "Export bill",
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => showExportBillOptions(
                                          context,
                                          bill: bill,
                                          breakdown: breakdown,
                                          ticketNumber: ticketNumber.isNotEmpty
                                              ? ticketNumber
                                              : bills[index].id,
                                          includeDisconnectionNotice:
                                              !isPaid && !isCancelled,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Electric Bill",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 17,
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize:
                                              MainAxisSize.min,
                                          children: [
                                            Icon(
                                              statusIcon,
                                              size: 14,
                                              color: statusColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              status.toUpperCase(),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight:
                                                    FontWeight.w700,
                                                fontSize: 11,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  Divider(
                                    height: 24,
                                    color: Colors.grey.shade200,
                                  ),

                                  _detailRow(
                                    "Billing Period",
                                    "${bill["billingPeriod"] ?? "-"}",
                                  ),

                                  const SizedBox(height: 8),

                                  _detailRow(
                                    "Payment Start",
                                    paymentStartDate,
                                  ),

                                  _detailRow(
                                    "Due Date",
                                    dueDate,
                                  ),

                                  const SizedBox(height: 8),

                                  _detailRow(
                                    "Generated By",
                                    "${bill["generatedBy"] ?? "-"}",
                                  ),

                                  Divider(
                                    height: 24,
                                    color: Colors.grey.shade200,
                                  ),

                                  if (breakdown != null)
                                    BillBreakdownView(
                                      breakdown: breakdown,
                                      previousReading: previousReading,
                                      currentReading: currentReading,
                                      consumption: consumption,
                                      municipality:
                                          bill["municipality"]?.toString(),
                                      dueDate: (!isPaid && !isCancelled)
                                          ? dueTimestamp?.toDate()
                                          : null,
                                    )
                                  else ...[
                                    _detailRow(
                                      "Previous Reading",
                                      "${bill["previousReading"] ?? 0} kWh",
                                    ),

                                    _detailRow(
                                      "Current Reading",
                                      "${bill["currentReading"] ?? 0} kWh",
                                    ),

                                    _detailRow(
                                      "Consumption",
                                      "${bill["consumption"] ?? 0} kWh",
                                    ),

                                    _detailRow(
                                      "Rate per kWh",
                                      "₱${bill["ratePerKwh"] ?? 0}",
                                    ),

                                    const SizedBox(height: 8),

                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "Total Amount",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        Text(
                                          "₱${totalAmount.toStringAsFixed(2)}",
                                          style: TextStyle(
                                            color: Colors.grey.shade900,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 22,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (dueTimestamp != null &&
                                        !isPaid &&
                                        !isCancelled) ...[
                                      const SizedBox(height: 12),
                                      DisconnectionNoticeCard(
                                        dueDate: dueTimestamp.toDate(),
                                      ),
                                    ],
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}