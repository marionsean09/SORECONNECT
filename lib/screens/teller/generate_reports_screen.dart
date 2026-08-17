import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GenerateReportScreen extends StatefulWidget {
  const GenerateReportScreen({super.key});

  @override
 State<GenerateReportScreen> createState() => _GenerateReportScreenState();
}

class _GenerateReportScreenState extends State<GenerateReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = false;
  String _reportType = "Monthly";
  Map<String, dynamic>? _report;
  String? _statusMessage;

  Future<List<Map<String, dynamic>>> _fetchComplaintsInPeriod(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final snapshot = await _firestore.collection('complaints').get();
    final complaints = <Map<String, dynamic>>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final timestampValue = data['createdAt'] ?? data['dateSubmitted'] ?? data['submittedAt'];

      DateTime? complaintDate;
      if (timestampValue is Timestamp) {
        complaintDate = timestampValue.toDate();
      } else if (timestampValue is DateTime) {
        complaintDate = timestampValue;
      } else if (timestampValue is String) {
        complaintDate = DateTime.tryParse(timestampValue);
      }

      if (complaintDate == null) {
        continue;
      }

      if (!complaintDate.isBefore(startDate) && !complaintDate.isAfter(endDate)) {
        complaints.add({
          ...data,
          'id': doc.id,
        });
      }
    }

    return complaints;
  }

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

      if (_reportType == "Monthly") {
        final monthIndex = now.month;
        final year = now.year;
        startDate = DateTime(year, monthIndex, 1);
        endDate = DateTime(year, monthIndex + 1, 1).subtract(const Duration(microseconds: 1));
      } else {
        final year = now.year;
        startDate = DateTime(year, 1, 1);
        endDate = DateTime(year, 12, 31, 23, 59, 59, 999, 999);
      }

      final billsSnapshot = await _firestore
          .collection('bills')
          .where('generatedAt', isGreaterThanOrEqualTo: startDate)
          .where('generatedAt', isLessThanOrEqualTo: endDate)
          .get();

      double totalRevenue = 0;
      int totalBills = 0;
      int paidBills = 0;
      Set<String> consumers = {};

      for (var doc in billsSnapshot.docs) {
        final data = doc.data();
        final amount = ((data['totalAmount'] ?? 0) as num).toDouble();
        final status = (data['status'] ?? '').toString().toLowerCase();

        totalRevenue += amount;
        totalBills++;
        if (data['consumerId'] != null) {
          consumers.add(data['consumerId'].toString());
        }
        if (status == 'paid') {
          paidBills++;
        }
      }

      final int totalConsumers = consumers.length;
      final int unpaidBills = totalBills - paidBills;
      final double totalPaidAmount = billsSnapshot.docs.fold<double>(0, (previous, doc) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        final amount = (data['totalAmount'] ?? 0) is num
            ? (data['totalAmount'] as num).toDouble()
            : 0.0;
        return status == 'paid' ? previous + amount : previous;
      });
      final double collectionRate = totalRevenue > 0
          ? (totalPaidAmount / totalRevenue) * 100
          : 0;

      final complaintsInPeriod = await _fetchComplaintsInPeriod(startDate, endDate);

      final int totalComplaints = complaintsInPeriod.length;
      final List<Map<String, dynamic>> pendingComplaintsList = [];
      final List<Map<String, dynamic>> resolvedComplaintsList = [];

      for (final complaint in complaintsInPeriod) {
        final status = (complaint['status'] ?? '').toString().toLowerCase();
        final complaintEntry = {
          'complaintId': complaint['id'] ?? complaint['complaintId'] ?? '',
          'subject': complaint['subject'] ?? 'No subject',
          'consumerName': complaint['consumerName'] ?? 'Unknown',
          'complaintType': complaint['complaintType'] ?? 'Unknown',
          'status': complaint['status'] ?? 'Pending',
          'createdAt': complaint['createdAt'] ?? complaint['dateSubmitted'] ?? complaint['submittedAt'],
        };

        if (status == 'resolved') {
          resolvedComplaintsList.add(complaintEntry);
        } else {
          pendingComplaintsList.add(complaintEntry);
        }
      }

      final int resolvedComplaints = resolvedComplaintsList.length;
      final int pendingComplaints = pendingComplaintsList.length;
      final double resolutionRate = totalComplaints > 0
          ? (resolvedComplaints / totalComplaints) * 100
          : 100;

      final reportData = {
        'period': _reportType == 'Monthly'
            ? DateFormat('MMMM yyyy').format(now)
            : now.year.toString(),
        'reportType': _reportType,
        'createdBy': 'teller',
        'generatedAt': FieldValue.serverTimestamp(),
        'billingSummary': {
          'totalRevenue': totalRevenue,
          'totalBills': totalBills,
          'totalConsumers': totalConsumers,
          'paidBills': paidBills,
          'unpaidBills': unpaidBills,
          'collectionRate': collectionRate,
          'totalPaidAmount': totalPaidAmount,
        },
        'complaintSummary': {
          'totalComplaints': totalComplaints,
          'resolvedComplaints': resolvedComplaints,
          'pendingComplaints': pendingComplaints,
          'resolutionRate': resolutionRate,
          'pendingComplaintList': pendingComplaintsList,
          'resolvedComplaintList': resolvedComplaintsList,
        },
      };

      await _firestore.collection('reports').doc().set(reportData);

      setState(() {
        _report = reportData;
        _statusMessage = 'Report saved successfully.';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.green,
          content: Text('Report generated and saved.'),
        ),
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to generate report: $e';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text('Error: $e'),
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

  Widget reportCard(
      String title,
      String value,
      IconData icon,
      Color color,
      ) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withAlpha((.15 * 255).round()),
              child: Icon(
                icon,
                color: color,
                size: 30,
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildComplaintListSection(String title, List<dynamic>? complaints) {
    final items = complaints ?? const <dynamic>[];

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Text(
                'No complaints in this list.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else
              ...items.map((item) {
                final complaint = item as Map<String, dynamic>? ?? <String, dynamic>{};
                final subject = complaint['subject']?.toString() ?? 'No subject';
                final consumer = complaint['consumerName']?.toString() ?? 'Unknown';
                final complaintType = complaint['complaintType']?.toString() ?? 'Unknown';

                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Consumer: $consumer'),
                      Text('Type: $complaintType'),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentPeriod = _reportType == "Monthly"
        ? DateFormat("MMMM yyyy").format(DateTime.now())
        : DateTime.now().year.toString();

    final billing = _report?['billingSummary'] as Map<String, dynamic>?;
    final complaints = _report?['complaintSummary'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Generate Reports"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _reportType,
              decoration: const InputDecoration(
                labelText: "Report Type",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: "Monthly",
                  child: Text("Monthly Report"),
                ),
                DropdownMenuItem(
                  value: "Yearly",
                  child: Text("Yearly Report"),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _reportType = value!;
                  _report = null;
                  _statusMessage = null;
                });
              },
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                currentPeriod,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _generateAndSaveReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      )
                    : const Text('GENERATE REPORT'),
              ),
            ),
            const SizedBox(height: 16),
            if (_statusMessage != null)
              Card(
                color: _statusMessage!.contains('success')
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: _statusMessage!.contains('success')
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
                    reportCard(
                      'Total Revenue',
                      '₱${billing?['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}',
                      Icons.payments,
                      Colors.green,
                    ),
                    reportCard(
                      'Bills Generated',
                      '${billing?['totalBills'] ?? 0}',
                      Icons.receipt_long,
                      Colors.orange,
                    ),
                    reportCard(
                      'Consumers Billed',
                      '${billing?['totalConsumers'] ?? 0}',
                      Icons.people,
                      Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'BILLING SUMMARY',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow('Total Revenue',
                                '₱${billing?['totalRevenue']?.toStringAsFixed(2) ?? '0.00'}'),
                            _buildSummaryRow('Total Bills',
                                '${billing?['totalBills'] ?? 0}'),
                            _buildSummaryRow('Consumers Billed',
                                '${billing?['totalConsumers'] ?? 0}'),
                            _buildSummaryRow('Paid Bills',
                                '${billing?['paidBills'] ?? 0}'),
                            _buildSummaryRow('Unpaid Bills',
                                '${billing?['unpaidBills'] ?? 0}'),
                            _buildSummaryRow('Collection Rate',
                                '${billing?['collectionRate']?.toStringAsFixed(1) ?? '0.0'}%'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'COMPLAINT SUMMARY',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow('Total Complaints',
                                '${complaints?['totalComplaints'] ?? 0}'),
                            _buildSummaryRow('Resolved Complaints',
                                '${complaints?['resolvedComplaints'] ?? 0}'),
                            _buildSummaryRow('Pending Complaints',
                                '${complaints?['pendingComplaints'] ?? 0}'),
                            _buildSummaryRow('Resolution Rate',
                                '${complaints?['resolutionRate']?.toStringAsFixed(1) ?? '0.0'}%'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildComplaintListSection(
                      'PENDING COMPLAINTS',
                      complaints?['pendingComplaintList'] as List<dynamic>?,
                    ),
                    const SizedBox(height: 16),
                    _buildComplaintListSection(
                      'RESOLVED COMPLAINTS',
                      complaints?['resolvedComplaintList'] as List<dynamic>?,
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: Center(
                  child: Text(
                    'Press GENERATE REPORT to compute and save the latest report.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
