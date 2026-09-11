import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MonitorReportsScreen extends StatefulWidget {
  const MonitorReportsScreen({super.key});

  @override
  State<MonitorReportsScreen> createState() => _MonitorReportsScreenState();
}

class _MonitorReportsScreenState extends State<MonitorReportsScreen> {
  String _selectedMonth = 'January';
  String _selectedYear = '2026';

  Map<String, dynamic>? _report;
  String? _statusMessage;
  bool _loading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  final List<String> _years = [
    '2024',
    '2025',
    '2026',
    '2027',
  ];

  // ============================================================
  // LOAD SAVED REPORT
  // ============================================================

  Future<void> _loadSavedReport() async {
    setState(() {
      _loading = true;
      _report = null;
      _statusMessage = null;
    });

    try {
      final String period = '$_selectedMonth $_selectedYear';

      debugPrint('Loading report for: $period');

      final QuerySnapshot<Map<String, dynamic>> reportSnapshot =
          await _firestore
              .collection('reports')
              .where('period', isEqualTo: period)
              .get();

      final filteredDocs = reportSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['reportType'] == 'Monthly' &&
            data['createdBy'] == 'teller';
      }).toList();

      filteredDocs.sort((a, b) {
        final aValue = a.data()['generatedAt'];
        final bValue = b.data()['generatedAt'];

        DateTime aDate;
        if (aValue is Timestamp) {
          aDate = aValue.toDate();
        } else if (aValue is DateTime) {
          aDate = aValue;
        } else {
          aDate = DateTime.fromMillisecondsSinceEpoch(0);
        }

        DateTime bDate;
        if (bValue is Timestamp) {
          bDate = bValue.toDate();
        } else if (bValue is DateTime) {
          bDate = bValue;
        } else {
          bDate = DateTime.fromMillisecondsSinceEpoch(0);
        }

        return bDate.compareTo(aDate);
      });

      if (filteredDocs.isEmpty) {
        setState(() {
          _statusMessage = 'No saved report found for $period.';
        });
        return;
      }

      final QueryDocumentSnapshot<Map<String, dynamic>> matchingDoc =
          filteredDocs.first;

      final Map<String, dynamic> reportData = matchingDoc.data();

      debugPrint('Selected report ID: ${matchingDoc.id}');
      debugPrint('Selected report data: $reportData');

      if (!mounted) return;

      setState(() {
        _report = reportData;
        _statusMessage = 'Report loaded successfully.';
      });
    } catch (e, stackTrace) {
      debugPrint('ERROR LOADING REPORT: $e');
      debugPrint('STACK TRACE: $stackTrace');

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Error loading report: $e';
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  // ============================================================
  // BUILD SCREEN
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitor Reports'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ====================================================
            // MONTH AND YEAR
            // ====================================================

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                    items: _months.map((month) {
                      return DropdownMenuItem<String>(
                        value: month,
                        child: Text(month),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedMonth = value;
                      });

                      _loadSavedReport();
                    },
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: _years.map((year) {
                      return DropdownMenuItem<String>(
                        value: year,
                        child: Text(year),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedYear = value;
                      });

                      _loadSavedReport();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ====================================================
            // LOAD REPORT BUTTON
            // ====================================================

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _loadSavedReport,

                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color.fromARGB(255, 221, 170, 4),
                  foregroundColor: Colors.white,
                ),

                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'LOAD SAVED REPORT',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 12),
            const Text(
              'Reports will also refresh automatically when you change month or year.',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: 20),

            // ====================================================
            // LOADING
            // ====================================================

            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )

            // ====================================================
            // ERROR / STATUS MESSAGE
            // ====================================================

            else if (_statusMessage != null &&
                _report == null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              )

            // ====================================================
            // REPORT
            // ====================================================

            else if (_report != null)
              Expanded(
                child: ListView(
                  children: [
                    _buildReportCard(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REPORT CARD
  // ============================================================

  Widget _buildReportCard() {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'REPORT FOR ${_report!['period'] ?? ''}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 10),

            const Divider(),

            const SizedBox(height: 10),

            // ==================================================
            // BILLING SUMMARY
            // ==================================================

            const Text(
              'BILLING SUMMARY',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 12),

            _buildRow(
              'Total Bills:',
              _reportValue(
                _report,
                'billingSummary',
                'totalBills',
              ),
            ),

            _buildRow(
              'Total Billed:',
              '₱${_reportNumber(
                _report,
                'billingSummary',
                'totalRevenue',
              )}',
            ),

            _buildRow(
              'Total Paid:',
              '₱${_reportNumber(
                _report,
                'billingSummary',
                'totalPaidAmount',
              )}',
            ),

            _buildRow(
              'Collection Rate:',
              '${_reportNumber(
                _report,
                'billingSummary',
                'collectionRate',
                decimals: 1,
              )}%',
            ),

            _buildRow(
              'Paid Bills:',
              _reportValue(
                _report,
                'billingSummary',
                'paidBills',
              ),
            ),

            _buildRow(
              'Unpaid Bills:',
              _reportValue(
                _report,
                'billingSummary',
                'unpaidBills',
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // CONSUMER COUNT
            // ==================================================

            _buildRow(
              'Consumers Billed:',
              _reportValue(
                _report,
                'billingSummary',
                'totalConsumers',
              ),
            ),

            const SizedBox(height: 20),

            // ==================================================
            // CONSUMER COUNT
            // ==================================================

            _buildRow(
              'Consumers Billed:',
              _reportValue(
                _report,
                'billingSummary',
                'totalConsumers',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REPORT ROW
  // ============================================================

  Widget _buildRow(
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 7,
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
                fontSize: 15,
              ),
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // GET STRING / INTEGER VALUE
  // ============================================================

  String _reportValue(
    Map<String, dynamic>? report,
    String section,
    String key,
  ) {
    if (report == null) {
      return '0';
    }

    final dynamic sectionData =
        report[section];

    if (sectionData is! Map) {
      return '0';
    }

    final dynamic value =
        sectionData[key];

    if (value == null) {
      return '0';
    }

    return value.toString();
  }

  // ============================================================
  // GET NUMBER VALUE
  // ============================================================

  String _reportNumber(
    Map<String, dynamic>? report,
    String section,
    String key, {
    int decimals = 2,
  }) {
    if (report == null) {
      return (0.0).toStringAsFixed(decimals);
    }

    final dynamic sectionData =
        report[section];

    if (sectionData is! Map) {
      return (0.0).toStringAsFixed(decimals);
    }

    final dynamic value =
        sectionData[key];

    if (value is num) {
      return value
          .toDouble()
          .toStringAsFixed(decimals);
    }

    final double? parsed =
        double.tryParse(
      value?.toString() ?? '',
    );

    return parsed?.toStringAsFixed(decimals) ??
        (0.0).toStringAsFixed(decimals);
  }
}