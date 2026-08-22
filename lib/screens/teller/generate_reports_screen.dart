import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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

  // =========================
  // GET COMPLAINT DATE
  // =========================

  DateTime? _getComplaintDate(
      Map<String, dynamic> data) {
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

  // =========================
  // FETCH COMPLAINTS
  // =========================

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

      final isBeforeOrEqual =
          !complaintDate.isAfter(endDate);

      if (isAfterOrEqual &&
          isBeforeOrEqual) {
        complaints.add({
          ...data,
          'id': doc.id,
        });
      }
    }

    return complaints;
  }

  // =========================
  // GENERATE REPORT
  // =========================

  Future<void> _generateAndSaveReport() async {
    setState(() {
      _isLoading = true;
      _report = null;
      _statusMessage = null;
    });

    try {
      final now = DateTime.now();

      late DateTime startDate;
      late DateTime endDate;

      // =========================
      // MONTHLY FILTER
      // =========================

      if (_reportType == "Monthly") {
        startDate = DateTime(
          now.year,
          now.month,
          1,
        );

        endDate = DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(
          const Duration(
            microseconds: 1,
          ),
        );
      }

      // =========================
      // YEARLY FILTER
      // =========================

      else {
        startDate = DateTime(
          now.year,
          1,
          1,
        );

        endDate = DateTime(
          now.year,
          12,
          31,
          23,
          59,
          59,
          999,
          999,
        );
      }

      // =========================
      // FETCH BILLS
      // =========================

      final billsSnapshot =
          await _firestore
              .collection('bills')
              .where(
                'generatedAt',
                isGreaterThanOrEqualTo:
                    startDate,
              )
              .where(
                'generatedAt',
                isLessThanOrEqualTo:
                    endDate,
              )
              .get();

      // =========================
      // BILL VARIABLES
      // =========================

      int totalBills = 0;
      int paidBills = 0;
      int unpaidBills = 0;

      double totalPaidAmount = 0;

      Set<String> consumers = {};

      // =========================
      // COMPUTE BILLS
      // =========================

      for (final doc
          in billsSnapshot.docs) {
        final data = doc.data();

        totalBills++;

        final status =
            (data['status'] ?? '')
                .toString()
                .toLowerCase();

        final amountValue =
            data['totalAmount'];

        final double amount =
            amountValue is num
                ? amountValue.toDouble()
                : 0.0;

        if (data['consumerId'] != null) {
          consumers.add(
            data['consumerId']
                .toString(),
          );
        }

        // PAID BILL

        if (status == 'paid') {
          paidBills++;

          totalPaidAmount += amount;
        }

        // UNPAID BILL

        else {
          unpaidBills++;
        }
      }

      final totalConsumers =
          consumers.length;

      // =========================
      // TOTAL REVENUE
      // ONLY PAID BILLS
      // =========================

      final totalRevenue =
          totalPaidAmount;

      // =========================
      // TOTAL BILL AMOUNT
      // =========================

      double totalBillAmount = 0;

      for (final doc
          in billsSnapshot.docs) {
        final data = doc.data();

        final amountValue =
            data['totalAmount'];

        if (amountValue is num) {
          totalBillAmount +=
              amountValue.toDouble();
        }
      }

      // =========================
      // COLLECTION RATE
      // =========================

      final collectionRate =
          totalBillAmount > 0
              ? (totalPaidAmount /
                      totalBillAmount) *
                  100
              : 0.0;

      // =========================
      // FETCH COMPLAINTS
      // =========================

      final complaintsInPeriod =
          await _fetchComplaintsInPeriod(
        startDate,
        endDate,
      );

      final totalComplaints =
          complaintsInPeriod.length;

      int pendingComplaints = 0;

      int inProgressComplaints = 0;

      int resolvedComplaints = 0;

      // =========================
      // COMPLAINT LISTS
      // =========================

      final pendingComplaintsList =
          <Map<String, dynamic>>[];

      final inProgressComplaintsList =
          <Map<String, dynamic>>[];

      final resolvedComplaintsList =
          <Map<String, dynamic>>[];

      // =========================
      // COMPUTE COMPLAINTS
      // =========================

      for (final complaint
          in complaintsInPeriod) {
        final status =
            (complaint['status'] ??
                    'pending')
                .toString()
                .toLowerCase();

        final complaintEntry = {
          'complaintId':
              complaint['id'] ??
                  complaint['complaintId'] ??
                  '',

          'subject':
              complaint['subject'] ??
                  'No subject',

          'consumerName':
              complaint['consumerName'] ??
                  'Unknown',

          'complaintType':
              complaint['complaintType'] ??
                  'Unknown',

          'status':
              complaint['status'] ??
                  'Pending',

          'createdAt':
              complaint['createdAt'] ??
                  complaint['dateSubmitted'] ??
                  complaint['submittedAt'],
        };

        // =========================
        // RESOLVED
        // =========================

        if (status == 'resolved' ||
            status == 'closed' ||
            status == 'completed') {
          resolvedComplaints++;

          resolvedComplaintsList
              .add(complaintEntry);
        }

        // =========================
        // IN PROGRESS
        // =========================

        else if (status == 'in progress' ||
            status == 'in_progress' ||
            status == 'inprogress') {
          inProgressComplaints++;

          inProgressComplaintsList
              .add(complaintEntry);
        }

        // =========================
        // PENDING
        // =========================

        else {
          pendingComplaints++;

          pendingComplaintsList
              .add(complaintEntry);
        }
      }

      // =========================
      // RESOLUTION RATE
      // =========================

      final resolutionRate =
          totalComplaints > 0
              ? (resolvedComplaints /
                      totalComplaints) *
                  100
              : 0.0;

      // =========================
      // REPORT DATA
      // =========================

      final reportData = {
        'period':
            _reportType == 'Monthly'
                ? DateFormat(
                    'MMMM yyyy',
                  ).format(now)
                : now.year.toString(),

        'reportType': _reportType,

        'createdBy': 'teller',

        'generatedAt':
            FieldValue.serverTimestamp(),

        // =========================
        // BILLING SUMMARY
        // =========================

        'billingSummary': {
          'totalRevenue':
              totalRevenue,

          'totalPaidAmount':
              totalPaidAmount,

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

        // =========================
        // COMPLAINT SUMMARY
        // =========================

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

          'pendingComplaintList':
              pendingComplaintsList,

          'inProgressComplaintList':
              inProgressComplaintsList,

          'resolvedComplaintList':
              resolvedComplaintsList,
        },
      };

      // =========================
      // SAVE REPORT
      // =========================

      await _firestore
          .collection('reports')
          .doc()
          .set(reportData);

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

  // =========================
  // REPORT CARD
  // =========================

  Widget reportCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding:
            const EdgeInsets.all(18),
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

  // =========================
  // SUMMARY ROW
  // =========================

  Widget _buildSummaryRow(
    String label,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment
                .spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // =========================
  // COMPLAINT LIST
  // =========================

  Widget _buildComplaintListSection(
    String title,
    List<dynamic>? complaints,
  ) {
    final items =
        complaints ??
            const <dynamic>[];

    return Card(
      elevation: 2,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight:
                    FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            if (items.isEmpty)
              Text(
                'No complaints in this list.',
                style: TextStyle(
                  color:
                      Colors.grey.shade600,
                ),
              )
            else
              ...items.map(
                (item) {
                  final complaint =
                      item as Map<
                              String,
                              dynamic>? ??
                          <String, dynamic>{};

                  final subject =
                      complaint['subject']
                              ?.toString() ??
                          'No subject';

                  final consumer =
                      complaint['consumerName']
                              ?.toString() ??
                          'Unknown';

                  final complaintType =
                      complaint['complaintType']
                              ?.toString() ??
                          'Unknown';

                  return Container(
                    margin:
                        const EdgeInsets.only(
                      top: 8,
                    ),
                    padding:
                        const EdgeInsets.all(10),
                    decoration:
                        BoxDecoration(
                      border: Border.all(
                        color: Colors
                            .grey
                            .shade300,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          subject,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Consumer: $consumer',
                        ),
                        Text(
                          'Type: $complaintType',
                        ),
                        Text(
                          'Status: ${complaint['status'] ?? ''}',
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final currentPeriod =
        _reportType == "Monthly"
            ? DateFormat(
                "MMMM yyyy",
              ).format(
                DateTime.now(),
              )
            : DateTime.now()
                .year
                .toString();

    final billing =
        _report?['billingSummary']
            as Map<String, dynamic>?;

    final complaints =
        _report?['complaintSummary']
            as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          "Generate Reports",
        ),
        backgroundColor:
            Colors.orange,
        foregroundColor:
            Colors.white,
      ),

      body: Padding(
        padding:
            const EdgeInsets.all(18),
        child: Column(
          children: [

            // =========================
            // REPORT TYPE
            // =========================

            DropdownButtonFormField<String>(
              value: _reportType,

              decoration:
                  const InputDecoration(
                labelText:
                    "Report Type",
                border:
                    OutlineInputBorder(),
              ),

              items: const [
                DropdownMenuItem(
                  value: "Monthly",
                  child: Text(
                    "Monthly Report",
                  ),
                ),

                DropdownMenuItem(
                  value: "Yearly",
                  child: Text(
                    "Yearly Report",
                  ),
                ),
              ],

              onChanged: (value) {
                setState(() {
                  _reportType =
                      value!;

                  _report = null;

                  _statusMessage =
                      null;
                });
              },
            ),

            const SizedBox(height: 20),

            Align(
              alignment:
                  Alignment.centerLeft,
              child: Text(
                currentPeriod,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              width:
                  double.infinity,
              height: 50,

              child:
                  ElevatedButton(
                onPressed:
                    _isLoading
                        ? null
                        : _generateAndSaveReport,

                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.orange,
                ),

                child:
                    _isLoading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<
                                    Color>(
                              Colors.white,
                            ),
                          )
                        : const Text(
                            'GENERATE REPORT',
                          ),
              ),
            ),

            const SizedBox(height: 16),

            if (_statusMessage != null)
              Card(
                color: _statusMessage!
                        .contains('success')
                    ? Colors.green.shade50
                    : Colors.red.shade50,

                child: Padding(
                  padding:
                      const EdgeInsets.all(12),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color:
                          _statusMessage!
                                  .contains(
                            'success',
                          )
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            if (_report != null)
              Expanded(
                child: ListView(
                  children: [

                    // =========================
                    // BILL REPORT CARDS
                    // =========================

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

                    const SizedBox(height: 16),

                    // =========================
                    // COMPLAINT REPORT CARDS
                    // =========================

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

                    const SizedBox(height: 16),

                    // =========================
                    // BILLING SUMMARY
                    // =========================

                    Card(
                      elevation: 2,

                      child: Padding(
                        padding:
                            const EdgeInsets.all(16),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [

                            const Text(
                              'BILLING SUMMARY',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 12),

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
                              'Collection Rate',
                              '${(billing?['collectionRate'] as num? ?? 0).toStringAsFixed(1)}%',
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =========================
                    // COMPLAINT SUMMARY
                    // =========================

                    Card(
                      elevation: 2,

                      child: Padding(
                        padding:
                            const EdgeInsets.all(16),

                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [

                            const Text(
                              'COMPLAINT SUMMARY',
                              style: TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 12),

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

                    const SizedBox(height: 16),

                    // =========================
                    // PENDING LIST
                    // =========================

                    _buildComplaintListSection(
                      'PENDING COMPLAINTS',
                      complaints?[
                              'pendingComplaintList']
                          as List<dynamic>?,
                    ),

                    const SizedBox(height: 16),

                    // =========================
                    // IN PROGRESS LIST
                    // =========================

                    _buildComplaintListSection(
                      'IN PROGRESS COMPLAINTS',
                      complaints?[
                              'inProgressComplaintList']
                          as List<dynamic>?,
                    ),

                    const SizedBox(height: 16),

                    // =========================
                    // RESOLVED LIST
                    // =========================

                    _buildComplaintListSection(
                      'RESOLVED COMPLAINTS',
                      complaints?[
                              'resolvedComplaintList']
                          as List<dynamic>?,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              )

            else
              Expanded(
                child: Center(
                  child: Text(
                    'Press GENERATE REPORT to compute and save the latest report.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color:
                          Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}