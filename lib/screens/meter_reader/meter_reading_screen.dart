import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:soreconnect/models/meter_reading_model.dart';
import 'package:soreconnect/services/rate_service.dart';

class MeterReadingScreen extends StatefulWidget {
  const MeterReadingScreen({super.key});

  @override
  State<MeterReadingScreen> createState() => _MeterReadingScreenState();
}

class _MeterReadingScreenState extends State<MeterReadingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final RateService _rateService = RateService();
  StreamSubscription<double>? _rateSub;

  final TextEditingController _accountNumberController = TextEditingController();
  final TextEditingController _currentReadingController = TextEditingController();

  bool _isLoading = false;
  double _currentRate = 12.0;
  Map<String, dynamic>? _consumer;

  double _previousReading = 0;
  double _consumption = 0;
  double _computedAmount = 0;

  static const Color _primaryRed = Color(0xFFD32F2F);

  @override
  void initState() {
    super.initState();
    _loadRate();
    // Subscribe to live rate updates so computation always uses latest rate
    _rateSub = _rateService.watchRate().listen((r) {
      if (!mounted) return;
      setState(() {
        _currentRate = r;
        // Recompute amount if current reading present
        _computeBill();
      });
    });
  }

  @override
  void dispose() {
    _accountNumberController.dispose();
    _currentReadingController.dispose();
    // Cancel rate subscription
    _rateSub?.cancel();
    super.dispose();
  }

  Future<void> _loadRate() async {
    final rate = await _rateService.getCurrentRate();
    if (!mounted) return;
    setState(() => _currentRate = rate);
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? null : Colors.green,
      ),
    );
  }

  Future<void> _searchConsumer() async {
    final account = _accountNumberController.text.trim();
    if (account.isEmpty) {
      _showSnackBar("Enter an account number.");
      return;
    }

    setState(() {
      _isLoading = true;
      _consumer = null;
      _previousReading = 0;
      _consumption = 0;
      _computedAmount = 0;
    });

    try {
      final consumerQuery = await _firestore
          .collection("users")
          .where("accountNumber", isEqualTo: account)
          .where("user_type", isEqualTo: "consumer")
          .limit(1)
          .get();

      if (consumerQuery.docs.isEmpty) {
        throw Exception("Consumer not found.");
      }

      final consumerDoc = consumerQuery.docs.first;
      final latestReading = await _firestore
          .collection("meter_readings")
          .where("consumerId", isEqualTo: consumerDoc.id)
          .orderBy("recordedAt", descending: true)
          .limit(1)
          .get();

      double previous = 0;
      if (latestReading.docs.isNotEmpty) {
        previous = (latestReading.docs.first.data()["currentReading"] ?? 0).toDouble();
      }

      if (!mounted) return;
      setState(() {
        _consumer = {"uid": consumerDoc.id, ...consumerDoc.data()};
        _previousReading = previous;
      });
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _computeBill() {
    final current = double.tryParse(_currentReadingController.text);
    if (current == null) return;

    if (current < _previousReading) {
      _showSnackBar("Current reading cannot be lower than previous reading.");
      return;
    }

    setState(() {
      _consumption = current - _previousReading;
      _computedAmount = _consumption * _currentRate;
    });
  }

  Future<void> _submitReading() async {
    if (_consumer == null) {
      _showSnackBar("Search a consumer first.");
      return;
    }

    final currentReading = double.tryParse(_currentReadingController.text.trim());
    if (currentReading == null) {
      _showSnackBar("Enter a valid meter reading.");
      return;
    }

    if (currentReading < _previousReading) {
      _showSnackBar("Current reading cannot be lower than previous reading.");
      return;
    }

    _computeBill();
    setState(() => _isLoading = true);

    try {
      final readingRef = _firestore.collection("meter_readings").doc();
      final billingPeriod = DateFormat("MMMM yyyy").format(DateTime.now());
      final meterReader = _auth.currentUser;

      final reading = MeterReadingModel(
        readingId: readingRef.id,
        consumerId: _consumer!["uid"],
        consumerName: _consumer!["full_name"],
        accountNumber: _consumer!["accountNumber"],
        previousReading: _previousReading,
        currentReading: currentReading,
        consumption: _consumption,
        ratePerKwh: _currentRate,
        computedAmount: _computedAmount,
        billingPeriod: billingPeriod,
        status: "Pending",
        recordedBy: meterReader?.email ?? "Meter Reader",
      );

      await readingRef.set(reading.toMap());

      _showSnackBar(
        "Meter reading submitted successfully.\nWaiting for Teller verification.",
        isError: false,
      );

      setState(() {
        _consumer = null;
        _previousReading = 0;
        _consumption = 0;
        _computedAmount = 0;
        _accountNumberController.clear();
        _currentReadingController.clear();
      });
    } catch (e) {
      _showSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Record Meter Reading"),
        backgroundColor: _primaryRed,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Consumer Account Number",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _accountNumberController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Enter account number",
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _searchConsumer,
                  child: const Text("Search"),
                ),
              ],
            ),
            const SizedBox(height: 25),
            if (_consumer == null) _buildEmptyState() else ..._buildReadingForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        children: [
          Icon(Icons.search, size: 50, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            "Search a consumer account to begin recording a meter reading.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReadingForm() {
    return [
      Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Consumer Information",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              Text("Name : ${_consumer!['full_name']}"),
              const SizedBox(height: 5),
              Text("Account No. : ${_consumer!['accountNumber']}"),
              const SizedBox(height: 5),
              Text("Previous Reading : ${_previousReading.toStringAsFixed(2)} kWh"),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        "Current Meter Reading",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: _currentReadingController,
        keyboardType: TextInputType.number,
        onChanged: (_) => _computeBill(),
        decoration: const InputDecoration(
          border: OutlineInputBorder(),
          hintText: "Enter current reading",
        ),
      ),
      const SizedBox(height: 25),
      Card(
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Bill Computation",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Divider(),
              _buildSummaryRow("Rate per kWh", "₱${_currentRate.toStringAsFixed(2)}"),
              const SizedBox(height: 10),
              _buildSummaryRow("Consumption", "${_consumption.toStringAsFixed(2)} kWh"),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Estimated Bill", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    "₱${_computedAmount.toStringAsFixed(2)}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: _primaryRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitReading,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryRed,
                    foregroundColor: Colors.white,
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isLoading ? "Submitting..." : "Submit Meter Reading"),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildSummaryRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(value),
      ],
    );
  }
}