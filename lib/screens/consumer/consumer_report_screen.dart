import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ConsumerReportScreen extends StatefulWidget {
  const ConsumerReportScreen({super.key});

  @override
  State<ConsumerReportScreen> createState() => _ConsumerReportScreenState();
}

class _ConsumerReportScreenState extends State<ConsumerReportScreen> {
  String _selectedMonth = DateFormat.MMMM().format(DateTime.now());
  String _selectedYear = DateTime.now().year.toString();

  bool _loading = false;
  String? _statusMessage;

  double _monthlyCollected = 0.0;
  double _yearlyCollected = 0.0;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final List<String> _months = const [
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
    for (int y = DateTime.now().year - 3; y <= DateTime.now().year + 1; y++) y.toString(),
  ];

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  Future<void> _loadTotals() async {
    setState(() {
      _loading = true;
      _statusMessage = null;
      _monthlyCollected = 0.0;
      _yearlyCollected = 0.0;
    });

    try {
      final String monthPeriod = '$_selectedMonth $_selectedYear';
      final String yearPeriod = _selectedYear;

      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore.collection('reports').get();

      final docs = snapshot.docs.where((d) {
        final data = d.data();
        return data['createdBy'] == 'teller';
      }).toList();

      // Monthly: find latest Monthly report for the exact period
      final monthlyMatches = docs.where((d) {
        final data = d.data();
        return (data['reportType'] == 'Monthly' || (data['reportType'] as String?)?.toLowerCase() == 'monthly') &&
            (data['period'] == monthPeriod);
      }).toList();

      monthlyMatches.sort((a, b) {
        final aGen = a.data()['generatedAt'];
        final bGen = b.data()['generatedAt'];

        DateTime aDate = _toDateTime(aGen);
        DateTime bDate = _toDateTime(bGen);
        return bDate.compareTo(aDate);
      });

      if (monthlyMatches.isNotEmpty) {
        final billing = monthlyMatches.first.data()['billingSummary'];
        _monthlyCollected = _toDouble(billing?['totalPaidAmount']);
      } else {
        _monthlyCollected = 0.0;
      }

      // Yearly: try to find a Yearly report first, otherwise sum Monthly reports for the year
      final yearlyMatches = docs.where((d) {
        final data = d.data();
        return (data['reportType'] == 'Yearly' || (data['reportType'] as String?)?.toLowerCase() == 'yearly') &&
            (data['period'] == yearPeriod);
      }).toList();

      if (yearlyMatches.isNotEmpty) {
        final billing = yearlyMatches.first.data()['billingSummary'];
        _yearlyCollected = _toDouble(billing?['totalPaidAmount']);
      } else {
        // sum monthly reports that end with the selected year
        final monthlyForYear = docs.where((d) {
          final data = d.data();
          final rp = data['period']?.toString() ?? '';
          return (data['reportType'] == 'Monthly' || (data['reportType'] as String?)?.toLowerCase() == 'monthly') &&
              rp.endsWith(_selectedYear);
        }).toList();

        double sum = 0.0;
        for (final d in monthlyForYear) {
          final billing = d.data()['billingSummary'];
          sum += _toDouble(billing?['totalPaidAmount']);
        }
        _yearlyCollected = sum;
      }

      if (!mounted) return;
      setState(() {
        _statusMessage = 'Totals loaded.';
      });
    } catch (e, st) {
      debugPrint('Error loading consumer report totals: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Error loading totals: $e';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String _formatCurrency(double val) {
    return NumberFormat.currency(locale: 'en_PH', symbol: '₱').format(val);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SORECO 1 Consumer Report'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                    items: _months.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedMonth = v;
                      });
                      _loadTotals();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        _selectedYear = v;
                      });
                      _loadTotals();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _loadTotals,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                child: _loading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('REFRESH'),
              ),
            ),

            const SizedBox(height: 18),

            if (_statusMessage != null) Text(_statusMessage!),

            const SizedBox(height: 12),

            _buildStatCard('Monthly Collected', _formatCurrency(_monthlyCollected)),
            const SizedBox(height: 12),
            _buildStatCard('Yearly Collected', _formatCurrency(_yearlyCollected)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String amount) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              amount,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFD32F2F)),
            ),
          ],
        ),
      ),
    );
  }
}
