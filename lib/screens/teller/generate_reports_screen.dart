import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({super.key});

  @override
  State<GenerateReportScreen> createState() =>
      _GenerateReportScreenState();
}

class _GenerateReportScreenState
    extends State<GenerateReportScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _isLoading = false;

  String _reportType = "Monthly";

  Map<String, dynamic>? _report;

  String? _statusMessage;

  // ============================================================
  // SELECTED MONTH
  // ============================================================

  int _selectedMonth = DateTime.now().month;

  // ============================================================
  // SELECTED YEAR
  // ============================================================

  int _selectedYear = DateTime.now().year;

  // ============================================================
  // MONTH NAMES
  // ============================================================

  final List<String> _monthNames = const [
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
  // AVAILABLE YEARS
  // ============================================================

  List<int> get _availableYears {
    final currentYear = DateTime.now().year;

    return List.generate(
      10,
      (index) => currentYear - index,
    );
  }

  // ============================================================
  // GET COMPLAINT DATE
  // ============================================================

  DateTime? _getComplaintDate(
    Map<String, dynamic> data,
  ) {
    final timestampValue =
        data['createdAt'] ??
        data['dateSubmitted'] ??
        data['submittedAt'];

    if (timestampValue is Timestamp) {
      return timestampValue.toDate();
    }

    if (timestampValue is DateTime) {
      return timestampValue;
    }

    if (timestampValue is String) {
      return DateTime.tryParse(timestampValue);
    }

    return null;
  }

  // ============================================================
  // FETCH COMPLAINTS IN PERIOD
  // ============================================================

  Future<List<Map<String, dynamic>>>
      _fetchComplaintsInPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot =
        await _firestore
            .collection('complaints')
            .get();

    final complaints =
        <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final complaintDate =
          _getComplaintDate(data);

      if (complaintDate == null) {
        continue;
      }

      final isAfterOrEqual =
          !complaintDate.isBefore(startDate);

      final isBefore =
          complaintDate.isBefore(endDate);

      if (isAfterOrEqual && isBefore) {
        complaints.add({
          ...data,
          'id': doc.id,
        });
      }
    }

    return complaints;
  }

  // ============================================================
  // GET SELECTED PERIOD
  // ============================================================

  Map<String, DateTime> _getSelectedPeriod() {
    late DateTime startDate;
    late DateTime endDate;

    if (_reportType == "Monthly") {
      startDate = DateTime(
        _selectedYear,
        _selectedMonth,
        1,
      );

      endDate = DateTime(
        _selectedYear,
        _selectedMonth + 1,
        1,
      );
    } else {
      startDate = DateTime(
        _selectedYear,
        1,
        1,
      );

      endDate = DateTime(
        _selectedYear + 1,
        1,
        1,
      );
    }

    return {
      'start': startDate,
      'end': endDate,
    };
  }

  // ============================================================
  // GET PERIOD DISPLAY
  // ============================================================

  String _getPeriodDisplay() {
    if (_reportType == "Monthly") {
      return '${_monthNames[_selectedMonth - 1]} $_selectedYear';
    }

    return '$_selectedYear';
  }

  // ============================================================
  // COMPACT FILTER PILL
  // ============================================================

  Widget _buildFilterPill({
    required IconData icon,
    required String value,
    required VoidCallback onTap,
    double? width,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width,
          height: 58,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE2E2E2),
            ),
          ),
          child: Row(
            mainAxisSize:
                width == null
                    ? MainAxisSize.min
                    : MainAxisSize.max,
            children: [
              Icon(
                icon,
                color: Colors.orange,
                size: 22,
              ),

              const SizedBox(width: 10),

              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.grey,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // REPORT TYPE MENU
  // ============================================================

  Future<void> _showReportTypeMenu() async {
    final result =
        await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 18),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Report Type',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                _buildSelectionTile(
                  title: 'Monthly Report',
                  icon: Icons.calendar_month_rounded,
                  selected:
                      _reportType == 'Monthly',
                  onTap: () {
                    Navigator.pop(
                      context,
                      'Monthly',
                    );
                  },
                ),

                _buildSelectionTile(
                  title: 'Yearly Report',
                  icon: Icons.date_range_rounded,
                  selected:
                      _reportType == 'Yearly',
                  onTap: () {
                    Navigator.pop(
                      context,
                      'Yearly',
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _reportType = result;
      _report = null;
      _statusMessage = null;
    });
  }

  // ============================================================
  // MONTH MENU
  // ============================================================

  Future<void> _showMonthMenu() async {
    final result =
        await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 18),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Month',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: 12,
                    itemBuilder:
                        (context, index) {
                      final monthNumber =
                          index + 1;

                      return _buildSelectionTile(
                        title:
                            _monthNames[index],
                        icon:
                            Icons.calendar_month_rounded,
                        selected:
                            _selectedMonth ==
                                monthNumber,
                        onTap: () {
                          Navigator.pop(
                            context,
                            monthNumber,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedMonth = result;
      _report = null;
      _statusMessage = null;
    });
  }

  // ============================================================
  // YEAR MENU
  // ============================================================

  Future<void> _showYearMenu() async {
    final result =
        await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              16,
              20,
              20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                ),

                const SizedBox(height: 18),

                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Select Year',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount:
                        _availableYears.length,
                    itemBuilder:
                        (context, index) {
                      final year =
                          _availableYears[index];

                      return _buildSelectionTile(
                        title: year.toString(),
                        icon:
                            Icons.date_range_rounded,
                        selected:
                            _selectedYear ==
                                year,
                        onTap: () {
                          Navigator.pop(
                            context,
                            year,
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) {
      return;
    }

    setState(() {
      _selectedYear = result;
      _report = null;
      _statusMessage = null;
    });
  }

  // ============================================================
  // SELECTION TILE
  // ============================================================

  Widget _buildSelectionTile({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Material(
        color:
            selected
                ? Colors.orange.withOpacity(0.08)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color:
                      selected
                          ? Colors.orange
                          : Colors.grey.shade600,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                    ),
                  ),
                ),

                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    color: Colors.orange,
                    size: 21,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GENERATE AND SAVE REPORT
  // ============================================================

  Future<void> _generateAndSaveReport() async {
    setState(() {
      _isLoading = true;
      _report = null;
      _statusMessage = null;
    });

    try {
      final selectedPeriod =
          _getSelectedPeriod();

      final DateTime startDate =
          selectedPeriod['start']!;

      final DateTime endDate =
          selectedPeriod['end']!;

      // ========================================================
      // FETCH BILLS
      // ========================================================

      final billsSnapshot =
          await _firestore
              .collection('bills')
              .where(
                'generatedAt',
                isGreaterThanOrEqualTo:
                    Timestamp.fromDate(
                  startDate,
                ),
              )
              .where(
                'generatedAt',
                isLessThan:
                    Timestamp.fromDate(
                  endDate,
                ),
              )
              .get();

      // ========================================================
      // BILL VARIABLES
      // ========================================================

      int totalBills = 0;
      int paidBills = 0;
      int unpaidBills = 0;

      double totalPaidAmount = 0;
      double totalBillAmount = 0;

      final Set<String> consumers = {};

      // ========================================================
      // COMPUTE BILLS
      // ========================================================

      for (final doc in billsSnapshot.docs) {
        final data = doc.data();

        totalBills++;

        final status =
            (data['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

        final amountValue =
            data['totalAmount'];

        final double amount =
            amountValue is num
                ? amountValue.toDouble()
                : 0.0;

        totalBillAmount += amount;

        if (data['consumerId'] != null) {
          final consumerId =
              data['consumerId']
                  .toString()
                  .trim();

          if (consumerId.isNotEmpty) {
            consumers.add(consumerId);
          }
        }

        if (status == 'paid') {
          paidBills++;
          totalPaidAmount += amount;
        } else {
          unpaidBills++;
        }
      }

      // ========================================================
      // TOTAL CONSUMERS
      // ========================================================

      final totalConsumers =
          consumers.length;

      // ========================================================
      // TOTAL REVENUE
      // ========================================================

      final totalRevenue =
          totalPaidAmount;

      // ========================================================
      // COLLECTION RATE
      // ========================================================

      final double collectionRate =
          totalBillAmount > 0
              ? (totalPaidAmount /
                      totalBillAmount) *
                  100
              : 0.0;

      // ========================================================
      // FETCH COMPLAINTS
      // ========================================================

      final complaintsInPeriod =
          await _fetchComplaintsInPeriod(
        startDate,
        endDate,
      );

      // ========================================================
      // COMPLAINT VARIABLES
      // ========================================================

      final totalComplaints =
          complaintsInPeriod.length;

      int pendingComplaints = 0;
      int inProgressComplaints = 0;
      int resolvedComplaints = 0;

      // ========================================================
      // COMPUTE COMPLAINTS
      // ========================================================

      for (final complaint
          in complaintsInPeriod) {
        final status =
            (complaint['status'] ??
                    'pending')
                .toString()
                .trim()
                .toLowerCase();

        if (status == 'resolved' ||
            status == 'closed' ||
            status == 'completed') {
          resolvedComplaints++;
        } else if (status == 'in progress' ||
            status == 'in_progress' ||
            status == 'inprogress') {
          inProgressComplaints++;
        } else {
          pendingComplaints++;
        }
      }

      // ========================================================
      // RESOLUTION RATE
      // ========================================================

      final double resolutionRate =
          totalComplaints > 0
              ? (resolvedComplaints /
                      totalComplaints) *
                  100
              : 0.0;

      // ========================================================
      // REPORT DATA
      // ========================================================

      final reportData = {
        'period': _getPeriodDisplay(),

        'reportType': _reportType,

        'selectedMonth':
            _reportType == "Monthly"
                ? _selectedMonth
                : null,

        'selectedYear': _selectedYear,

        'createdBy': 'teller',

        'generatedAt':
            FieldValue.serverTimestamp(),

        // ======================================================
        // BILLING SUMMARY
        // ======================================================

        'billingSummary': {
          'totalRevenue':
              totalRevenue,

          'totalPaidAmount':
              totalPaidAmount,

          'totalBillAmount':
              totalBillAmount,

          'totalBills':
              totalBills,

          'paidBills':
              paidBills,

          'unpaidBills':
              unpaidBills,

          'totalConsumers':
              totalConsumers,

          'collectionRate':
              collectionRate,
        },

        // ======================================================
        // COMPLAINT SUMMARY ONLY
        // ======================================================

        'complaintSummary': {
          'totalComplaints':
              totalComplaints,

          'pendingComplaints':
              pendingComplaints,

          'inProgressComplaints':
              inProgressComplaints,

          'resolvedComplaints':
              resolvedComplaints,

          'resolutionRate':
              resolutionRate,
        },
      };

      // ========================================================
      // SAVE REPORT
      // ========================================================

      await _firestore
          .collection('reports')
          .doc()
          .set(reportData);

      // ========================================================
      // DISPLAY REPORT
      // ========================================================

      setState(() {
        _report = reportData;

        _statusMessage =
            'Report saved successfully.';
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text(
            'Report generated and saved.',
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _statusMessage =
            'Failed to generate report: $e';
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            'Error: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // REPORT CARD
  // ============================================================

  Widget reportCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor:
                  color.withOpacity(0.15),
              child: Icon(
                icon,
                color: color,
                size: 30,
              ),
            ),

            const SizedBox(width: 18),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY ROW
  // ============================================================

  Widget _buildSummaryRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final billing =
        _report?['billingSummary']
            as Map<String, dynamic>?;

    final complaints =
        _report?['complaintSummary']
            as Map<String, dynamic>?;

    return Scaffold(
      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Generate Reports',
        ),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Padding(
        padding: const EdgeInsets.all(18),

        child: Column(
          children: [

            // ==================================================
            // COMPACT FILTER AREA
            // ==================================================

            Row(
              children: [
                // ----------------------------------------------
                // REPORT TYPE
                // ----------------------------------------------

                Expanded(
                  child: _buildFilterPill(
                    icon:
                        Icons.tune_rounded,
                    value:
                        _reportType,
                    onTap:
                        _showReportTypeMenu,
                  ),
                ),

                const SizedBox(width: 10),

                // ----------------------------------------------
                // MONTH
                // ----------------------------------------------

                if (_reportType ==
                    'Monthly')
                  Expanded(
                    child: _buildFilterPill(
                      icon:
                          Icons.calendar_month_rounded,
                      value:
                          _monthNames[
                              _selectedMonth - 1],
                      onTap:
                          _showMonthMenu,
                    ),
                  ),

                if (_reportType ==
                    'Monthly')
                  const SizedBox(
                    width: 10,
                  ),

                // ----------------------------------------------
                // YEAR
                // ----------------------------------------------

                Expanded(
                  child: _buildFilterPill(
                    icon:
                        Icons.date_range_rounded,
                    value:
                        _selectedYear.toString(),
                    onTap:
                        _showYearMenu,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ==================================================
            // SELECTED PERIOD
            // ==================================================

            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                _getPeriodDisplay(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ==================================================
            // GENERATE BUTTON
            // ==================================================

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed:
                    _isLoading
                        ? null
                        : _generateAndSaveReport,

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.orange,
                  foregroundColor:
                      Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),

                child:
                    _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor:
                                  AlwaysStoppedAnimation<
                                      Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'GENERATE REPORT',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),
              ),
            ),

            const SizedBox(height: 16),

            // ==================================================
            // STATUS MESSAGE
            // ==================================================

            if (_statusMessage != null)
              Card(
                color:
                    _statusMessage!
                            .toLowerCase()
                            .contains(
                              'success',
                            )
                        ? Colors.green.shade50
                        : Colors.red.shade50,

                child: Padding(
                  padding:
                      const EdgeInsets.all(12),

                  child: Row(
                    children: [
                      Icon(
                        _statusMessage!
                                .toLowerCase()
                                .contains(
                                  'success',
                                )
                            ? Icons
                                .check_circle
                            : Icons.error,

                        color:
                            _statusMessage!
                                    .toLowerCase()
                                    .contains(
                                      'success',
                                    )
                                ? Colors
                                    .green
                                    .shade700
                                : Colors
                                    .red
                                    .shade700,
                      ),

                      const SizedBox(
                        width: 10,
                      ),

                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: TextStyle(
                            color:
                                _statusMessage!
                                        .toLowerCase()
                                        .contains(
                                          'success',
                                        )
                                    ? Colors
                                        .green
                                        .shade700
                                    : Colors
                                        .red
                                        .shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ==================================================
            // REPORT RESULTS
            // ==================================================

            if (_report != null)
              Expanded(
                child: ListView(
                  children: [

                    // ==========================================
                    // REPORT PERIOD HEADER
                    // ==========================================

                    Card(
                      elevation: 2,
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.event_note,
                              color:
                                  Colors.orange,
                              size: 30,
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  const Text(
                                    'GENERATED REPORT',
                                    style:
                                        TextStyle(
                                      color:
                                          Colors.grey,
                                      fontSize:
                                          12,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 4,
                                  ),

                                  Text(
                                    _report?[
                                            'period'] ??
                                        _getPeriodDisplay(),
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                      fontSize:
                                          20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==========================================
                    // BILL REPORT CARDS
                    // ==========================================

                    reportCard(
                      'Total Revenue',
                      '₱${(billing?['totalRevenue'] as num? ?? 0).toStringAsFixed(2)}',
                      Icons.payments,
                      Colors.green,
                    ),

                    reportCard(
                      'Total Generated Bills',
                      '${billing?['totalBills'] ?? 0}',
                      Icons.receipt_long,
                      Colors.blue,
                    ),

                    reportCard(
                      'Paid Bills',
                      '${billing?['paidBills'] ?? 0}',
                      Icons.check_circle,
                      Colors.green,
                    ),

                    reportCard(
                      'Unpaid Bills',
                      '${billing?['unpaidBills'] ?? 0}',
                      Icons.pending_actions,
                      Colors.orange,
                    ),

                    reportCard(
                      'Total Consumers',
                      '${billing?['totalConsumers'] ?? 0}',
                      Icons.people,
                      Colors.purple,
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    // ==========================================
                    // COMPLAINT REPORT CARDS
                    // ==========================================

                    reportCard(
                      'Total Complaints',
                      '${complaints?['totalComplaints'] ?? 0}',
                      Icons.report_problem,
                      Colors.red,
                    ),

                    reportCard(
                      'Pending Complaints',
                      '${complaints?['pendingComplaints'] ?? 0}',
                      Icons.pending,
                      Colors.orange,
                    ),

                    reportCard(
                      'In Progress',
                      '${complaints?['inProgressComplaints'] ?? 0}',
                      Icons.autorenew,
                      Colors.blue,
                    ),

                    reportCard(
                      'Resolved Complaints',
                      '${complaints?['resolvedComplaints'] ?? 0}',
                      Icons.task_alt,
                      Colors.green,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==========================================
                    // BILLING SUMMARY
                    // ==========================================

                    Card(
                      elevation: 2,
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'BILLING SUMMARY',
                              style:
                                  TextStyle(
                                fontWeight:
                                    FontWeight
                                        .bold,
                                fontSize: 16,
                              ),
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            _buildSummaryRow(
                              'Total Revenue',
                              '₱${(billing?['totalRevenue'] as num? ?? 0).toStringAsFixed(2)}',
                            ),

                            _buildSummaryRow(
                              'Total Generated Bills',
                              '${billing?['totalBills'] ?? 0}',
                            ),

                            _buildSummaryRow(
                              'Paid Bills',
                              '${billing?['paidBills'] ?? 0}',
                            ),

                            _buildSummaryRow(
                              'Unpaid Bills',
                              '${billing?['unpaidBills'] ?? 0}',
                            ),

                            _buildSummaryRow(
                              'Total Paid Amount',
                              '₱${(billing?['totalPaidAmount'] as num? ?? 0).toStringAsFixed(2)}',
                            ),

                            _buildSummaryRow(
                              'Total Bill Amount',
                              '₱${(billing?['totalBillAmount'] as num? ?? 0).toStringAsFixed(2)}',
                            ),

                            _buildSummaryRow(
                              'Total Consumers',
                              '${billing?['totalConsumers'] ?? 0}',
                            ),

                            _buildSummaryRow(
                              'Collection Rate',
                              '${(billing?['collectionRate'] as num? ?? 0).toStringAsFixed(1)}%',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    // ==========================================
                    // COMPLAINT SUMMARY ONLY
                    // ==========================================

                    Card(
                      elevation: 2,
                      child: Padding(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons
                                      .report_problem,
                                  color:
                                      Colors.red,
                                ),

                                const SizedBox(
                                  width: 10,
                                ),

                                const Text(
                                  'COMPLAINT SUMMARY',
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                              height: 12,
                            ),

                            _buildSummaryRow(
                              'Total Complaints',
                              '${complaints?['totalComplaints'] ?? 0}',
                            ),

                            _buildSummaryRow(
                              'Pending Complaints',
                              '${complaints?['pendingComplaints'] ?? 0}',
                            ),

                            _buildSummaryRow(
                              'In Progress Complaints',
                              '${complaints?['inProgressComplaints'] ?? 0}',
                            ),

                            _buildSummaryRow(
                              'Resolved Complaints',
                              '${complaints?['resolvedComplaints'] ?? 0}',
                            ),

                            _buildSummaryRow(
                              'Resolution Rate',
                              '${(complaints?['resolutionRate'] as num? ?? 0).toStringAsFixed(1)}%',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),
                  ],
                ),
              )

            // ==================================================
            // NO REPORT
            // ==================================================

            else
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons
                            .assessment_outlined,
                        size: 70,
                        color:
                            Colors
                                .grey
                                .shade400,
                      ),

                      const SizedBox(
                        height: 16,
                      ),

                      Text(
                        'No report generated yet.',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.w500,
                          color:
                              Colors
                                  .grey
                                  .shade600,
                        ),
                      ),

                      const SizedBox(
                        height: 6,
                      ),

                      Text(
                        'Select a month and year, then press GENERATE REPORT.',
                        textAlign:
                            TextAlign.center,
                        style: TextStyle(
                          color:
                              Colors
                                  .grey
                                  .shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}